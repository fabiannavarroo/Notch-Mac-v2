//
//  AirPodsManager.swift
//  NotchMac
//
//  Detects AirPods connect/disconnect and polls per-bud + case battery
//  levels via `system_profiler SPBluetoothDataType -json`. Public-API only,
//  so it is resilient to macOS updates (no private IOBluetooth keys).
//
//  Polling cadence:
//    - Idle (no AirPods): 60 s
//    - Connected, battery > 30%: 30 s
//    - Connected, battery ≤ 30%: 15 s
//  Plus an immediate refresh on Bluetooth route change (CoreAudio device list
//  changes) so the user sees the connect animation instantly.
//
//  Threshold notifications fire at 50 %, 20 % and 10 % of the lowest pod
//  reading. Each threshold fires at most once per discharge cycle; we reset
//  them when the level climbs back above 60 % (i.e. user reseated in case).
//

import AppKit
import Combine
import CoreAudio
import Defaults
import Foundation
import UserNotifications

struct AirPodsState: Equatable {
    var name: String
    var variant: AirPodsModelVariant
    /// 0...100, nil if not reported.
    var left: Int?
    var right: Int?
    var case_: Int?
    /// For single-pod / Max devices that report a unified battery.
    var single: Int?

    /// Lowest of the two pods (used for notification thresholds). Falls back
    /// to `single` if pods aren't reported separately.
    var lowestPodLevel: Int? {
        let pods = [left, right].compactMap { $0 }
        if !pods.isEmpty { return pods.min() }
        return single
    }
}

@MainActor
final class AirPodsManager: ObservableObject {
    static let shared = AirPodsManager()

    @Published private(set) var state: AirPodsState?
    /// True once the user has seen the connect live activity at least once
    /// this session. Used to suppress repeated sneak peeks on transient
    /// route changes.
    @Published private(set) var didShowConnectActivity: Bool = false

    private var pollTask: Task<Void, Never>?
    private var routeChangeListener: AudioObjectPropertyListenerBlock?
    private var firedThresholds: Set<Int> = []
    private var lastVariantPrefetched: AirPodsModelVariant?

    private init() {}

    func start() {
        guard pollTask == nil else { return }
        requestNotificationAuthorization()
        attachRouteChangeListener()
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        detachRouteChangeListener()
    }

    func forceRefresh() {
        Task { await self.refreshOnce() }
    }

    // MARK: - Polling

    private func pollLoop() async {
        while !Task.isCancelled {
            await refreshOnce()
            let interval: UInt64
            if let level = state?.lowestPodLevel {
                interval = level <= 30 ? 15 : 30
            } else {
                interval = 60
            }
            try? await Task.sleep(nanoseconds: interval * 1_000_000_000)
        }
    }

    private func refreshOnce() async {
        let scanResult = await Self.scanBluetooth()
        await MainActor.run { self.apply(scanResult) }
    }

    private func apply(_ newState: AirPodsState?) {
        let previous = state
        state = newState

        if let s = newState {
            // Prefetch the matching USDZ once per variant change.
            if lastVariantPrefetched != s.variant {
                AirPodsAssetLoader.shared.prefetch(s.variant)
                lastVariantPrefetched = s.variant
            }

            // First time we see this connection in this session → ping sneak.
            if previous == nil {
                didShowConnectActivity = true
                NotificationCenter.default.post(name: .airPodsConnected, object: nil)
            }

            evaluateThresholds(s)
        } else if previous != nil {
            // Disconnected.
            didShowConnectActivity = false
            firedThresholds.removeAll()
            NotificationCenter.default.post(name: .airPodsDisconnected, object: nil)
        }
    }

    // MARK: - Notifications

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func evaluateThresholds(_ s: AirPodsState) {
        guard Defaults[.airPodsBatteryNotifications] else { return }
        guard let level = s.lowestPodLevel else { return }

        // Reset thresholds when battery recovers (e.g. case-charged) past 60%.
        if level >= 60 { firedThresholds.removeAll() }

        let thresholds = [
            Defaults[.airPodsThresholdHigh],
            Defaults[.airPodsThresholdLow],
            Defaults[.airPodsThresholdCritical]
        ].sorted(by: >)

        for t in thresholds where level <= t && !firedThresholds.contains(t) {
            firedThresholds.insert(t)
            postBatteryNotification(state: s, threshold: t)
        }
    }

    private func postBatteryNotification(state s: AirPodsState, threshold: Int) {
        let content = UNMutableNotificationContent()
        content.title = s.name
        let levelText = s.lowestPodLevel.map { "\($0) %" } ?? "—"
        if threshold <= 10 {
            content.subtitle = "Batería crítica"
            content.body = "Solo queda \(levelText). Cárgalos pronto."
        } else if threshold <= 20 {
            content.subtitle = "Batería baja"
            content.body = "Quedan \(levelText) en tus AirPods."
        } else {
            content.subtitle = "Batería al \(threshold) %"
            content.body = "Nivel actual: \(levelText)."
        }
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: "nm.airpods.battery.\(threshold)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: - CoreAudio route listener (fast wake on connect)

    private func attachRouteChangeListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.forceRefresh() }
        }
        routeChangeListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
    }

    private func detachRouteChangeListener() {
        guard let block = routeChangeListener else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
        routeChangeListener = nil
    }

    // MARK: - Bluetooth scan (off main actor)

    private nonisolated static func scanBluetooth() async -> AirPodsState? {
        await Task.detached(priority: .utility) { () -> AirPodsState? in
            guard let json = runSystemProfiler() else { return nil }
            return parseAirPods(from: json)
        }.value
    }

    private nonisolated static func runSystemProfiler() -> [String: Any]? {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPBluetoothDataType", "-json", "-detailLevel", "basic"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            NSLog("[AirPodsManager] system_profiler failed: \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj
    }

    private nonisolated static func parseAirPods(from root: [String: Any]) -> AirPodsState? {
        guard let arr = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        for controller in arr {
            let connected = controller["device_connected"] as? [[String: Any]] ?? []
            for wrapper in connected {
                for (name, value) in wrapper {
                    guard let dict = value as? [String: Any] else { continue }
                    if let parsed = candidateAirPods(name: name, dict: dict) {
                        return parsed
                    }
                }
            }
        }
        return nil
    }

    /// Returns an AirPodsState only if this device looks like AirPods (Apple
    /// vendor + Headphones minor type). Other Apple-branded headphones (e.g.
    /// Beats) fall through.
    private nonisolated static func candidateAirPods(name: String, dict: [String: Any]) -> AirPodsState? {
        let vendor = (dict["device_vendorID"] as? String ?? "").lowercased()
        let minor = (dict["device_minorType"] as? String ?? "").lowercased()
        let nameLower = name.lowercased()
        let looksApple = vendor.contains("0x004c") || vendor.contains("(apple)") || nameLower.contains("airpod")
        guard looksApple, minor.contains("headphone") || nameLower.contains("airpod") else { return nil }

        let productID = (dict["device_productID"] as? String ?? "").lowercased()
        let variant = mapVariant(productID: productID, name: nameLower)

        return AirPodsState(
            name: name,
            variant: variant,
            left:   parsePercent(dict["device_batteryLevelLeft"]),
            right:  parsePercent(dict["device_batteryLevelRight"]),
            case_:  parsePercent(dict["device_batteryLevelCase"]),
            single: parsePercent(dict["device_batteryLevelMain"])
        )
    }

    private nonisolated static func mapVariant(productID: String, name: String) -> AirPodsModelVariant {
        // Known Apple AirPods product IDs (subset). Falls back to name heuristics.
        switch productID {
        case "0x200a":            return .airPodsMax
        case "0x2024",            // AirPods 3
             "0x2002",            // AirPods 1
             "0x200f",            // AirPods 2
             "0x2032":            // AirPods 4 (entry)
            return .airPods
        case "0x2033":            return .airPodsANC  // AirPods 4 con ANC
        case "0x200e",            // AirPods Pro
             "0x2014",            // AirPods Pro 2 (Lightning)
             "0x2026",            // AirPods Pro 2
             "0x2027",            // AirPods Pro 2 (USB-C)
             "0x2035":            // AirPods Pro 3 (placeholder)
            return .airPodsPro
        default: break
        }
        if name.contains("max") { return .airPodsMax }
        if name.contains("pro") { return .airPodsPro }
        return .airPods
    }

    private nonisolated static func parsePercent(_ raw: Any?) -> Int? {
        guard let s = raw as? String else { return nil }
        // Values look like "98 %" or "98%".
        let digits = s.filter(\.isNumber)
        return Int(digits)
    }
}

extension Notification.Name {
    static let airPodsConnected = Notification.Name("nm.airpods.connected")
    static let airPodsDisconnected = Notification.Name("nm.airpods.disconnected")
}
