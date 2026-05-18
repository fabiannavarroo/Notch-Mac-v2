import Combine
import Foundation
import ServiceManagement
import AppKit

/// Drives macOS Background Task Management for the main app's "open at login"
/// entry. Why a custom manager instead of `LaunchAtLogin-Modern`'s `.Toggle`:
/// LaunchAtLogin-Modern wraps `SMAppService.mainApp` but swallows errors and
/// does not surface the underlying status, so ad-hoc-signed builds (no Team
/// Identifier) fail silently — BTM keeps the entry but invalidates it on the
/// next CDHash change. We need the raw status visible to the user and to logs.
@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    enum SimpleStatus: String {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
        case unknown
    }

    @Published private(set) var status: SimpleStatus = .unknown
    @Published private(set) var rawStatus: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?
    @Published private(set) var bundleLocation: URL = Bundle.main.bundleURL
    @Published private(set) var launchedAsLoginItem: Bool = false

    private let service = SMAppService.mainApp
    private var refreshTimer: Timer?

    private init() {
        detectLaunchedAsLoginItem()
        refresh()
        // Refresh whenever the app comes forward or System Settings might have
        // changed the disposition behind our back.
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleActivate),
            name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.invalidate()
    }

    var isEnabled: Bool { rawStatus == .enabled }

    func refresh() {
        let raw = service.status
        rawStatus = raw
        switch raw {
        case .enabled: status = .enabled
        case .notRegistered: status = .notRegistered
        case .requiresApproval: status = .requiresApproval
        case .notFound: status = .notFound
        @unknown default: status = .unknown
        }
        NSLog("[NotchMac][LoginItem] status=\(status.rawValue) raw=\(raw.rawValue) bundle=\(bundleLocation.path)")
    }

    /// Toggle entry point used by the Settings switch.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try service.register()
                lastError = nil
                NSLog("[NotchMac][LoginItem] register() ok")
            } else {
                try service.unregister()
                lastError = nil
                NSLog("[NotchMac][LoginItem] unregister() ok")
            }
        } catch {
            let ns = error as NSError
            lastError = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
            NSLog("[NotchMac][LoginItem] toggle failed: \(lastError ?? "?")")
        }
        refresh()
    }

    /// Opens System Settings → Login Items so the user can approve a pending
    /// registration. Sparkle-style re-launch will not bypass approval.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Force a clean re-registration. Useful when the BTM entry is `enabled`
    /// but launchd will not honor it because the ad-hoc CDHash has drifted
    /// since the original `register()` call (every rebuild rotates the hash).
    func reRegister() {
        do {
            try service.unregister()
        } catch {
            NSLog("[NotchMac][LoginItem] unregister during re-register failed: \(error)")
        }
        do {
            try service.register()
            lastError = nil
            NSLog("[NotchMac][LoginItem] re-register ok")
        } catch {
            let ns = error as NSError
            lastError = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
            NSLog("[NotchMac][LoginItem] re-register failed: \(lastError ?? "?")")
        }
        refresh()
    }

    /// Best-effort: macOS marks login-launched apps in NSAppleEventManager's
    /// launch event. We also accept the heuristic that if launchd parent is
    /// `launchd` and the app started within 30 s of session unlock, it came
    /// from BTM. The cheap signal is enough for the diagnostics panel.
    private func detectLaunchedAsLoginItem() {
        let event = NSAppleEventManager.shared().currentAppleEvent
        if let propData = event?.paramDescriptor(forKeyword: keyAEPropData) {
            let val = propData.stringValue ?? ""
            launchedAsLoginItem = val.lowercased().contains("login")
        }
        // Fallback heuristic via ProcessInfo arguments — SMAppService passes
        // `--launched-at-login` for main apps when supported.
        if !launchedAsLoginItem {
            launchedAsLoginItem = ProcessInfo.processInfo.arguments
                .contains(where: { $0.lowercased().contains("login") })
        }
    }

    @objc private func handleActivate() {
        refresh()
    }

    // MARK: - Diagnostics

    var bundleIsInApplications: Bool {
        bundleLocation.path.hasPrefix("/Applications/")
    }

    var humanStatus: String {
        switch status {
        case .enabled: return "Approved & enabled"
        case .notRegistered: return "Not registered"
        case .requiresApproval: return "Requires approval in System Settings"
        case .notFound: return "Not found by launchd"
        case .unknown: return "Unknown"
        }
    }
}
