//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import Combine
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI
import SwiftUIIntrospect
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var accentColorUpdateTrigger = UUID()

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    var body: some View {
        NotchUtilitySettingsView(updaterController: updaterController)
            .id(accentColorUpdateTrigger)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccentColorChanged"))) { _ in
                accentColorUpdateTrigger = UUID()
            }
    }

}

struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var coordinator = BoringViewCoordinator.shared

    @Default(.mirrorShape) var mirrorShape
    @Default(.showEmojis) var showEmojis
    @Default(.gestureSensitivity) var gestureSensitivity
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.enableGestures) var enableGestures
    @Default(.openNotchOnHover) var openNotchOnHover
    

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.menubarIcon] },
                    set: { Defaults[.menubarIcon] = $0 }
                )) {
                    Text("Show menu bar icon")
                }
                .tint(.effectiveAccent)
                LaunchAtLogin.Toggle("Launch at login")
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                
                Defaults.Toggle(key: .showCaffeinateButton) {
                    Text("Show caffeinate button in notch")
                }
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Automatically switch displays")
                }
                    .onChange(of: automaticallySwitchDisplay) {
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker(
                    selection: $notchHeightMode,
                    label:
                        Text("Notch height on notch displays")
                ) {
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match menu bar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize:
                        notchHeight = 38
                    case .matchMenuBar:
                        notchHeight = 44
                    case .custom:
                        notchHeight = 38
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Notch height on non-notch displays", selection: $nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .matchRealNotchSize:
                        nonNotchHeight = 32
                    case .custom:
                        nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Custom notch size - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
            } header: {
                Text("Notch sizing")
            }

            NotchBehaviour()

            gestureControls()
        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("General")
        .onChange(of: openNotchOnHover) {
            if !openNotchOnHover {
                enableGestures = true
            }
        }
    }

    @ViewBuilder
    func gestureControls() -> some View {
        Section {
            Defaults.Toggle(key: .enableGestures) {
                Text("Enable gestures")
            }
                .disabled(!openNotchOnHover)
            if enableGestures {
                Defaults.Toggle(key: .enableHorizontalMediaGestures) {
                    Text("Change media with horizontal gestures")
                }
                Defaults.Toggle(key: .closeGestureEnabled) {
                    Text("Close gesture")
                }
                Slider(value: $gestureSensitivity, in: 100...300, step: 100) {
                    HStack {
                        Text("Gesture sensitivity")
                        Spacer()
                        Text(
                            Defaults[.gestureSensitivity] == 100
                                ? "High" : Defaults[.gestureSensitivity] == 200 ? "Medium" : "Low"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            HStack {
                Text("Gesture control")
                customBadge(text: "Beta")
            }
        } footer: {
            Text(
                "Two-finger swipe up on notch to close, two-finger swipe down on notch to open when **Open notch on hover** option is disabled"
            )
            .multilineTextAlignment(.trailing)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        Section {
            Defaults.Toggle(key: .openNotchOnHover) {
                Text("Open notch on hover")
            }
            Defaults.Toggle(key: .enableHaptics) {
                    Text("Enable haptic feedback")
            }
            Toggle("Remember last tab", isOn: $coordinator.openLastTabByDefault)
            if openNotchOnHover {
                Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: minimumHoverDuration) {
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
            }
        } header: {
            Text("Notch behavior")
        }

        AutoHideAppsSection()
    }
}

struct AutoHideAppsSection: View {
    @Default(.nmAutoHideAppBundleIDs) private var bundleIDs

    var body: some View {
        Section {
            ForEach(bundleIDs, id: \.self) { bid in
                HStack {
                    if let icon = appIcon(bid) {
                        Image(nsImage: icon)
                            .resizable().frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "app.dashed").frame(width: 18, height: 18)
                    }
                    Text(appDisplayName(bid))
                    Spacer()
                    Text(bid).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button(action: { remove(bid) }) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }
            }
            if bundleIDs.isEmpty {
                Text("Ninguna app configurada. La isla se oculta automáticamente cuando una de las apps de esta lista está activa.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Añadir aplicación…") { addApp() }
                Spacer()
            }
        } header: {
            HStack {
                Text("Ocultar isla automáticamente")
                Spacer()
                Text("⌥X para alternar manualmente")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Añadir"
        if panel.runModal() == .OK, let url = panel.url,
           let bundle = Bundle(url: url),
           let bid = bundle.bundleIdentifier,
           !bundleIDs.contains(bid) {
            bundleIDs.append(bid)
        }
    }

    private func remove(_ bid: String) {
        bundleIDs.removeAll { $0 == bid }
    }

    private func appURL(_ bid: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)
    }

    private func appDisplayName(_ bid: String) -> String {
        guard let url = appURL(bid) else { return bid }
        return (FileManager.default.displayName(atPath: url.path) as NSString).deletingPathExtension
    }

    private func appIcon(_ bid: String) -> NSImage? {
        guard let url = appURL(bid) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}

// Legacy Form-based battery settings; superseded by NMBatterySettingsView.
// Kept as a thin alias so any stray reference still compiles.
struct Charge: View {
    var body: some View { NMBatterySettingsView() }
}

// MARK: - Battery settings (premium dark redesign)

struct NMBatterySettingsView: View {
    @Default(.showBatteryIndicator) private var showBatteryIndicator
    @Default(.showPowerStatusNotifications) private var showPowerStatusNotifications
    @Default(.showBatteryPercentage) private var showBatteryPercentage
    @Default(.showPowerStatusIcons) private var showPowerStatusIcons

    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    var body: some View {
        VStack(spacing: 16) {
            NMBatteryGeneralCard(
                showBatteryIndicator: $showBatteryIndicator,
                showPowerStatusNotifications: $showPowerStatusNotifications
            )
            NMBatteryInformationCard(
                showBatteryPercentage: $showBatteryPercentage,
                showPowerStatusIcons: $showPowerStatusIcons,
                indicatorEnabled: showBatteryIndicator
            )
            NMBatteryPreviewCard()
            NMPowerEventsCard(notificationsEnabled: showPowerStatusNotifications)
        }
    }
}

private struct NMBatteryGeneralCard: View {
    @Binding var showBatteryIndicator: Bool
    @Binding var showPowerStatusNotifications: Bool

    var body: some View {
        NMSettingsCard(title: "General") {
            NMPreferenceRow(
                title: "Show battery indicator",
                subtitle: "Display the battery plate inside the open notch."
            ) {
                Toggle("", isOn: $showBatteryIndicator)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
            NMDivider()
            NMPreferenceRow(
                title: "Show power status notifications",
                subtitle: "Surface plug, unplug, low battery, and full charge in the closed notch."
            ) {
                Toggle("", isOn: $showPowerStatusNotifications)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
        }
    }
}

private struct NMBatteryInformationCard: View {
    @Binding var showBatteryPercentage: Bool
    @Binding var showPowerStatusIcons: Bool
    let indicatorEnabled: Bool

    var body: some View {
        NMSettingsCard(title: "Battery Information") {
            NMPreferenceRow(
                title: "Show battery percentage",
                subtitle: "Render the numeric level next to the battery glyph.",
                badge: indicatorEnabled ? nil : "Requires Indicator",
                isEnabled: indicatorEnabled
            ) {
                Toggle("", isOn: $showBatteryPercentage)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(!indicatorEnabled)
            }
            NMDivider()
            NMPreferenceRow(
                title: "Show power status icons",
                subtitle: "Overlay bolt or plug glyphs while charging or plugged in.",
                badge: indicatorEnabled ? nil : "Requires Indicator",
                isEnabled: indicatorEnabled
            ) {
                Toggle("", isOn: $showPowerStatusIcons)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(!indicatorEnabled)
            }
        }
    }
}

private struct NMBatteryPreviewCard: View {
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared
    @Default(.showBatteryIndicator) private var showBatteryIndicator
    @Default(.showBatteryPercentage) private var showBatteryPercentage
    @Default(.showPowerStatusIcons) private var showPowerStatusIcons

    var body: some View {
        NMSettingsCard(title: "Preview") {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.08), lineWidth: 0.8)
                        )
                    if showBatteryIndicator {
                        HStack(spacing: 6) {
                            if showBatteryPercentage {
                                Text("\(Int(batteryModel.levelBattery))%")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                            }
                            Image(systemName: glyphName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(plateTint)
                                .overlay(alignment: .center) {
                                    if showPowerStatusIcons, let overlay = overlayGlyph {
                                        Image(systemName: overlay)
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .offset(y: -1)
                                    }
                                }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    } else {
                        Text("Indicator off")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .frame(width: 200, height: 48)
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)

                VStack(alignment: .leading, spacing: 10) {
                    NMBatteryStatusRow(label: "Level", value: "\(Int(batteryModel.levelBattery))%", tint: plateTint)
                    NMBatteryStatusRow(
                        label: "Charging",
                        value: batteryModel.isCharging ? "Yes" : "No",
                        tint: batteryModel.isCharging ? .green : .white.opacity(0.6)
                    )
                    NMBatteryStatusRow(
                        label: "Power adapter",
                        value: batteryModel.isPluggedIn ? "Connected" : "On battery",
                        tint: batteryModel.isPluggedIn ? .green : .yellow
                    )
                    if batteryModel.isInLowPowerMode {
                        NMBatteryStatusRow(label: "Mode", value: "Low Power", tint: .yellow)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
        }
    }

    private var glyphName: String {
        if batteryModel.isCharging { return "battery.100.bolt" }
        let level = batteryModel.levelBattery
        switch level {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default: return "battery.100"
        }
    }

    private var overlayGlyph: String? {
        if batteryModel.isCharging { return "bolt.fill" }
        if batteryModel.isPluggedIn { return "powerplug.fill" }
        return nil
    }

    private var plateTint: Color {
        if batteryModel.isInLowPowerMode { return .yellow }
        if batteryModel.levelBattery <= 20 && !batteryModel.isCharging && !batteryModel.isPluggedIn { return .red }
        if batteryModel.isCharging || batteryModel.isPluggedIn || batteryModel.levelBattery >= 100 { return .green }
        return .white.opacity(0.85)
    }
}

private struct NMBatteryStatusRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Spacer(minLength: 0)
        }
    }
}

private struct NMPowerEventsCard: View {
    let notificationsEnabled: Bool

    private let events: [NMPowerEvent] = [
        NMPowerEvent(title: "Plugged In", subtitle: "Triggered when AC adapter connects.", icon: "powerplug.fill", tint: .green),
        NMPowerEvent(title: "Unplugged", subtitle: "Triggered when AC adapter disconnects.", icon: "powerplug", tint: .white.opacity(0.7)),
        NMPowerEvent(title: "Low Battery", subtitle: "Triggered at ~20% on battery.", icon: "battery.25", tint: .red),
        NMPowerEvent(title: "Fully Charged", subtitle: "Triggered when level reaches 100%.", icon: "battery.100.bolt", tint: .green)
    ]

    var body: some View {
        NMSettingsCard(title: "Power Events") {
            ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                if idx > 0 { NMDivider() }
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: event.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(event.tint)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.white.opacity(0.05))
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Text(event.subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                    }
                    Spacer(minLength: 12)
                    NMPowerEventStatus(enabled: notificationsEnabled)
                }
                .padding(.vertical, 9)
            }
        }
    }
}

private struct NMPowerEvent {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
}

private struct NMPowerEventStatus: View {
    let enabled: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(enabled ? Color.green : Color.white.opacity(0.25))
                .frame(width: 6, height: 6)
            Text(enabled ? "Notifies" : "Silent")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(enabled ? Color.green.opacity(0.92) : Color.white.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill((enabled ? Color.green : Color.white).opacity(enabled ? 0.12 : 0.06))
                .overlay(
                    Capsule().stroke((enabled ? Color.green : Color.white).opacity(enabled ? 0.22 : 0.08), lineWidth: 0.5)
                )
        )
    }
}

struct HUD: View {
    var body: some View { NMHUDPanel() }
}

// MARK: - HUD panel (sidebar route)

struct NMHUDPanel: View {
    @Default(.hudReplacement) private var hudReplacement
    @Default(.optionKeyAction) private var optionKeyAction
    @Default(.enableGradient) private var enableGradient
    @Default(.systemEventIndicatorShadow) private var glow
    @Default(.systemEventIndicatorUseAccent) private var useAccent
    @Default(.showOpenNotchHUD) private var showOpenHUD
    @Default(.showOpenNotchHUDPercentage) private var openPct
    @Default(.inlineHUD) private var inlineHUD
    @Default(.showClosedNotchHUDPercentage) private var closedPct
    @Default(.showCapsLockHUD) private var capsHUD

    @State private var accessibilityAuthorized = false

    private var twoCol: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMHUDReplacementCard(authorized: accessibilityAuthorized)

            LazyVGrid(columns: twoCol, spacing: 16) {
                NMHUDBehaviorCard()
                NMHUDAppearanceCard()
                NMHUDOpenNotchCard()
                NMHUDClosedNotchCard()
            }
            .disabled(!hudReplacement)
            .opacity(hudReplacement ? 1 : 0.45)

            NMHUDCapsLockCard()
        }
        .accentColor(.effectiveAccent)
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { note in
            if let granted = note.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
                if !granted { hudReplacement = false }
            }
        }
        .onChange(of: inlineHUD) { _, newValue in
            if newValue {
                withAnimation {
                    glow = false
                    enableGradient = false
                }
            }
        }
    }
}

// MARK: - HUD cards

private struct NMHUDReplacementCard: View {
    let authorized: Bool
    @Default(.hudReplacement) private var hudReplacement

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "System HUD Replacement",
                         subtitle: "Take over the macOS volume, brightness, and keyboard HUDs.")

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Replace system HUD")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        NMBadge(authorized ? "Granted" : "Required",
                                color: authorized ? .green : .orange)
                    }
                    Text(authorized
                         ? "NotchMac intercepts the system HUD and draws inside the notch."
                         : "Accessibility access is required before NotchMac can intercept HUDs.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                Toggle("", isOn: $hudReplacement)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(!authorized)
            }

            if !authorized {
                Button {
                    XPCHelperClient.shared.requestAccessibilityAuthorization()
                } label: {
                    Label("Request Accessibility", systemImage: "lock.shield")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.accentColor)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMHUDBehaviorCard: View {
    @Default(.optionKeyAction) private var optionKeyAction

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Behavior",
                         subtitle: "Action triggered when ⌥ is held on a media key.")

            VStack(alignment: .leading, spacing: 6) {
                Text("Option key behaviour")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Picker("", selection: $optionKeyAction) {
                    Text("Open System Settings").tag(OptionKeyAction.openSettings)
                    Text("Show HUD").tag(OptionKeyAction.showHUD)
                    Text("No Action").tag(OptionKeyAction.none)
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMHUDAppearanceCard: View {
    @Default(.enableGradient) private var enableGradient
    @Default(.systemEventIndicatorShadow) private var glow
    @Default(.systemEventIndicatorUseAccent) private var useAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Appearance",
                         subtitle: "Progress bar style and accent treatment.")

            VStack(alignment: .leading, spacing: 6) {
                Text("Progress bar style")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Picker("", selection: $enableGradient) {
                    Text("Hierarchical").tag(false)
                    Text("Gradient").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            NMSwitchRow(title: "Enable glowing effect",
                        subtitle: "Adds a soft glow around the active progress bar.",
                        isOn: $glow)

            NMSwitchRow(title: "Tint progress bar with accent color",
                        subtitle: "Use the system accent color on the HUD progress fill.",
                        isOn: $useAccent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMHUDOpenNotchCard: View {
    @Default(.showOpenNotchHUD) private var showOpenHUD
    @Default(.showOpenNotchHUDPercentage) private var openPct

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                NMCardHeader(title: "Open Notch HUD",
                             subtitle: "Volume, brightness, and keyboard inside the expanded notch.")
                Spacer()
                NMBadge("Beta", color: .purple)
            }

            NMSwitchRow(title: "Show HUD in open notch",
                        subtitle: "Render volume / brightness / keyboard in the expanded notch.",
                        isOn: $showOpenHUD)

            NMSwitchRow(title: "Show percentage",
                        subtitle: "Append the current value next to the progress bar.",
                        isOn: $openPct)
                .disabled(!showOpenHUD)
                .opacity(showOpenHUD ? 1 : 0.45)

            NMHUDPreview(style: .open, showPercentage: openPct)
                .opacity(showOpenHUD ? 1 : 0.45)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMHUDClosedNotchCard: View {
    @Default(.inlineHUD) private var inlineHUD
    @Default(.showClosedNotchHUDPercentage) private var closedPct

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Closed Notch HUD",
                         subtitle: "Compact indicator drawn beside the closed notch.")

            VStack(alignment: .leading, spacing: 6) {
                Text("HUD style")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Picker("", selection: $inlineHUD) {
                    Text("Default").tag(false)
                    Text("Inline").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }

            NMSwitchRow(title: "Show percentage",
                        subtitle: "Append the current value next to the bar.",
                        isOn: $closedPct)

            NMHUDPreview(style: inlineHUD ? .closedInline : .closedDefault,
                         showPercentage: closedPct)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMHUDCapsLockCard: View {
    @Default(.showCapsLockHUD) private var capsHUD

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Caps Lock",
                         subtitle: "Pulse a Caps Lock indicator in the notch on state change.")

            NMSwitchRow(title: "Show Caps Lock indicator in notch",
                        subtitle: "Animate a Caps Lock chip on the closed notch.",
                        isOn: $capsHUD)

            NMCapsLockPreview(isOn: capsHUD)
                .opacity(capsHUD ? 1 : 0.45)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

// MARK: - HUD previews

private enum NMHUDPreviewStyle {
    case open
    case closedDefault
    case closedInline
}

private struct NMHUDPreview: View {
    let style: NMHUDPreviewStyle
    let showPercentage: Bool
    @Default(.enableGradient) private var enableGradient
    @Default(.systemEventIndicatorShadow) private var glow
    @Default(.systemEventIndicatorUseAccent) private var useAccent

    var body: some View {
        HStack(spacing: 10) {
            previewPill(icon: "speaker.wave.2.fill", value: 0.65, label: "65%")
            previewPill(icon: "sun.max.fill", value: 0.82, label: "82%")
            previewPill(icon: "keyboard.fill", value: 0.40, label: "40%")
        }
    }

    private func previewPill(icon: String, value: CGFloat, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 14)
            barShape(value: value)
                .frame(height: style == .closedInline ? 4 : 6)
            if showPercentage {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, style == .closedInline ? 8 : 10)
        .padding(.vertical, style == .closedInline ? 6 : 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: style == .closedInline ? 10 : 14, style: .continuous)
                .fill(.black)
                .overlay(
                    RoundedRectangle(cornerRadius: style == .closedInline ? 10 : 14, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.7)
                )
        )
    }

    @ViewBuilder
    private func barShape(value: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(fillStyle)
                    .frame(width: max(0, geo.size.width * value))
                    .shadow(color: glow ? glowColor : .clear, radius: 6, x: 0, y: 0)
            }
        }
    }

    private var fillStyle: AnyShapeStyle {
        if enableGradient {
            let colors: [Color] = useAccent
                ? [Color.effectiveAccent, Color.effectiveAccent.ensureMinimumBrightness(factor: 0.2)]
                : [Color.white, Color.white.opacity(0.25)]
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .trailing, endPoint: .leading))
        }
        return AnyShapeStyle(useAccent ? Color.effectiveAccent : Color.white)
    }

    private var glowColor: Color {
        useAccent ? Color.effectiveAccent.ensureMinimumBrightness(factor: 0.7) : .white
    }
}

private struct NMCapsLockPreview: View {
    let isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image(systemName: "capslock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isOn ? .green : .white.opacity(0.6))
                Text(isOn ? "Caps Lock indicator active" : "Caps Lock indicator off")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.black)
                    .overlay(Capsule().stroke(.white.opacity(0.1), lineWidth: 0.7))
            )
            Spacer(minLength: 0)
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles
    @Default(.albumArtDisplayMode) var albumArtDisplayMode
    @Default(.liveActivityAlbumArtSize) var liveActivityAlbumArtSize
    @Default(.liveActivityAlbumArtCornerRadius) var liveActivityAlbumArtCornerRadius
    @Default(.liveActivityAlbumArtShadow) var liveActivityAlbumArtShadow

    @Default(.enableLyrics) var enableLyrics
    @Default(.enableParallaxAlbumArt) private var enableParallaxAlbumArt
    @Default(.enableAlbumArtFlip) private var enableAlbumArtFlip
    @Default(.enableWavyProgressBar) private var enableWavyProgressBar

    private var realtimeAudioWaveformSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: twoColumnGrid, spacing: 16) {
                albumArtCard
                liveActivityCard
                mediaSourceCard
                playerControlsCard
                effectsCard
                visualizerCard
            }
        }
        .accentColor(.effectiveAccent)
    }

    private var twoColumnGrid: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }

    private var mediaSourceCard: some View {
        musicSettingsCard(title: "Media Source", subtitle: "Choose the controller that drives playback state.") {
            VStack(alignment: .leading, spacing: 12) {
                labeledPicker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(name: .mediaControllerChanged, object: nil)
                }

                HStack(alignment: .top, spacing: 8) {
                    NMBadge("Requires Permission", color: .orange)
                    Text("YouTube Music requires the pear-desktop helper app to expose playback state.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var liveActivityCard: some View {
        musicSettingsCard(title: "Live Activity", subtitle: "Closed and open notch playback presence.") {
            VStack(alignment: .leading, spacing: 14) {
                NMSwitchRow(title: "Show music live activity", subtitle: "Show or hide the music plate in the notch.", isOn: $coordinator.musicLiveActivityEnabled.animation())
                NMSwitchRow(title: "Show sneak peek on playback changes", subtitle: "Expand briefly when the active track changes.", isOn: $enableSneakPeek)

                labeledPicker("Sneak Peek Style", selection: $sneakPeekStyles) {
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .disabled(!enableSneakPeek)
                .opacity(enableSneakPeek ? 1 : 0.45)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Media inactivity timeout")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Seconds before playback UI is treated as idle.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        Text("\(Int(waitInterval)) s")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .frame(width: 42, alignment: .trailing)
                    }
                    .controlSize(.small)
                    .frame(width: 118)
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    labeledPicker("Full screen behavior", selection: $hideNotchOption) {
                        Text("Hide for all apps").tag(HideNotchOption.always)
                        Text("Hide for media app only").tag(HideNotchOption.nowPlayingOnly)
                        Text("Never hide").tag(HideNotchOption.never)
                    }
                    NMBadge("Beta", color: .purple)
                }
            }
        }
    }

    private var albumArtCard: some View {
        musicSettingsCard(title: "Album Art", subtitle: "Artwork treatment for the compact music plate.") {
            VStack(alignment: .leading, spacing: 14) {
                albumArtPreview

                labeledPicker("Album art display", selection: $albumArtDisplayMode) {
                    ForEach(AlbumArtDisplayMode.allCases) { mode in
                        Text(mode.localizedString).tag(mode)
                    }
                }

                NMSliderRow(
                    title: "Album art size",
                    subtitle: "Scales the closed-notch artwork live.",
                    value: $liveActivityAlbumArtSize,
                    range: 0.5...1.5,
                    step: 0.05,
                    format: "%.2fx"
                )
                NMSliderRow(
                    title: "Album art corner radius",
                    subtitle: "Rounds the artwork corners in the live plate.",
                    value: $liveActivityAlbumArtCornerRadius,
                    range: 0.0...2.0,
                    step: 0.05,
                    format: "%.2fx"
                )
                NMSwitchRow(title: "Drop shadow on album art", subtitle: "Adds depth to the compact artwork.", isOn: $liveActivityAlbumArtShadow)
            }
        }
    }

    private var playerControlsCard: some View {
        musicSettingsCard(title: "Player Controls", subtitle: "Five live slots used by the notch player.") {
            VStack(alignment: .leading, spacing: 14) {
                MusicSlotConfigurationView()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    NMSwitchRow(title: "Show lyrics below artist name", subtitle: "Display available lyrics in the open notch.", isOn: $enableLyrics)
                    NMBadge("Beta", color: .purple)
                }
            }
        }
        .gridCellColumns(2)
    }

    private var effectsCard: some View {
        musicSettingsCard(title: "Effects", subtitle: "Motion and progress effects applied without restart.") {
            VStack(alignment: .leading, spacing: 14) {
                NMSwitchRow(title: "Parallax album art", subtitle: "Tilt artwork with pointer movement.", isOn: $enableParallaxAlbumArt)
                NMSwitchRow(title: "Album art flip", subtitle: "Flip artwork when playback changes.", isOn: $enableAlbumArtFlip)
                NMSwitchRow(title: "Wavy progress bar", subtitle: "Use the wave-shaped playback progress.", isOn: $enableWavyProgressBar)
            }
        }
    }

    private var visualizerCard: some View {
        musicSettingsCard(title: "Visualizer", subtitle: "Audio-reactive waveform for supported macOS versions.") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 8) {
                    NMSwitchRow(
                        title: "Real-time audio waveform",
                        subtitle: realtimeAudioWaveformSupported
                            ? "Uses system audio capture for a real FFT waveform."
                            : "Requires macOS 14.2 or later.",
                        isOn: Binding(
                            get: { Defaults[.realtimeAudioWaveform] },
                            set: { Defaults[.realtimeAudioWaveform] = $0 }
                        )
                    )
                    .disabled(!realtimeAudioWaveformSupported)
                    .opacity(realtimeAudioWaveformSupported ? 1 : 0.45)

                    NMBadge(realtimeAudioWaveformSupported ? "Compatible" : "Unavailable", color: realtimeAudioWaveformSupported ? .green : .orange)
                }

                Text("Audio capture permission is required so NotchMac can analyze the current output and draw the waveform.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var albumArtPreview: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: previewArtwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 38 * liveActivityAlbumArtSize, height: 38 * liveActivityAlbumArtSize)
                    .clipShape(RoundedRectangle(cornerRadius: 7 * liveActivityAlbumArtCornerRadius, style: .continuous))
                    .shadow(color: liveActivityAlbumArtShadow ? .black.opacity(0.6) : .clear, radius: 5, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(musicManager.songTitle.isEmpty ? "Now Playing" : musicManager.songTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(musicManager.artistName.isEmpty ? "Artist" : musicManager.artistName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.black)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 0.7))
            )
        }
    }

    private var previewArtwork: NSImage {
        if albumArtDisplayMode == .appIcon,
           let bundleIdentifier = musicManager.bundleIdentifier,
           let icon = AppIconAsNSImage(for: bundleIdentifier) {
            return icon
        }
        return musicManager.albumArt
    }

    private func musicSettingsCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: title, subtitle: subtitle)
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private func labeledPicker<Selection: Hashable, Content: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Picker("", selection: selection, content: content)
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { $0 != .nowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
}

// Legacy CalendarSettings replaced by NMCalendarPanel (sidebar route).

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}

struct About: View {
    @State private var showBuildNumber: Bool = false
    let updaterController: SPUStandardUpdaterController
    @Environment(\.openWindow) var openWindow
    var body: some View {
        VStack {
            Form {
                Section {
                    HStack {
                        Text("Release name")
                        Spacer()
                        Text(Defaults[.releaseName])
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        if showBuildNumber {
                            Text("(\(Bundle.main.buildVersionNumber ?? ""))")
                                .foregroundStyle(.secondary)
                        }
                        Text(Bundle.main.releaseVersionNumber ?? "unkown")
                            .foregroundStyle(.secondary)
                    }
                    .onTapGesture {
                        withAnimation {
                            showBuildNumber.toggle()
                        }
                    }
                } header: {
                    Text("Version info")
                }

                UpdaterSettingsView(updater: updaterController.updater)

                HStack(spacing: 30) {
                    Spacer(minLength: 0)
                    Button {
                        if let url = URL(string: "https://github.com/TheBoredTeam/boring.notch") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image("Github")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 18)
                            Text("GitHub")
                        }
                        .contentShape(Rectangle())
                    }
                    Spacer(minLength: 0)
                }
                .buttonStyle(PlainButtonStyle())
            }
            VStack(spacing: 0) {
                Divider()
                Text("Made with 🫶🏻 by not so boring not.people")
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.bottom, 7)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .toolbar {
            //            Button("Welcome window") {
            //                openWindow(id: "onboarding")
            //            }
            //            .controlSize(.extraLarge)
            CheckForUpdatesView(updater: updaterController.updater)
        }
        .navigationTitle("About")
    }
}

struct Shelf: View {
    var body: some View { NMShelfPanel() }
}

//struct Extensions: View {
//    @State private var effectTrigger: Bool = false
//    var body: some View {
//        Form {
//            Section {
//                List {
//                    ForEach(extensionManager.installedExtensions.indices, id: \.self) { index in
//                        let item = extensionManager.installedExtensions[index]
//                        HStack {
//                            AppIcon(for: item.bundleIdentifier)
//                                .resizable()
//                                .frame(width: 24, height: 24)
//                            Text(item.name)
//                            ListItemPopover {
//                                Text("Description")
//                            }
//                            Spacer(minLength: 0)
//                            HStack(spacing: 6) {
//                                Circle()
//                                    .frame(width: 6, height: 6)
//                                    .foregroundColor(
//                                        isExtensionRunning(item.bundleIdentifier)
//                                            ? .green : item.status == .disabled ? .gray : .red
//                                    )
//                                    .conditionalModifier(isExtensionRunning(item.bundleIdentifier))
//                                { view in
//                                    view
//                                        .shadow(color: .green, radius: 3)
//                                }
//                                Text(
//                                    isExtensionRunning(item.bundleIdentifier)
//                                        ? "Running"
//                                        : item.status == .disabled ? "Disabled" : "Stopped"
//                                )
//                                .contentTransition(.numericText())
//                                .foregroundStyle(.secondary)
//                                .font(.footnote)
//                            }
//                            .frame(width: 60, alignment: .leading)
//
//                            Menu(
//                                content: {
//                                    Button("Restart") {
//                                        let ws = NSWorkspace.shared
//
//                                        if let ext = ws.runningApplications.first(where: {
//                                            $0.bundleIdentifier == item.bundleIdentifier
//                                        }) {
//                                            ext.terminate()
//                                        }
//
//                                        if let appURL = ws.urlForApplication(
//                                            withBundleIdentifier: item.bundleIdentifier)
//                                        {
//                                            ws.openApplication(
//                                                at: appURL, configuration: .init(),
//                                                completionHandler: nil)
//                                        }
//                                    }
//                                    .keyboardShortcut("R", modifiers: .command)
//                                    Button("Disable") {
//                                        if let ext = NSWorkspace.shared.runningApplications.first(
//                                            where: { $0.bundleIdentifier == item.bundleIdentifier })
//                                        {
//                                            ext.terminate()
//                                        }
//                                        extensionManager.installedExtensions[index].status =
//                                            .disabled
//                                    }
//                                    .keyboardShortcut("D", modifiers: .command)
//                                    Divider()
//                                    Button("Uninstall", role: .destructive) {
//                                        //
//                                    }
//                                },
//                                label: {
//                                    Image(systemName: "ellipsis.circle")
//                                        .foregroundStyle(.secondary)
//                                }
//                            )
//                            .controlSize(.regular)
//                        }
//                        .buttonStyle(PlainButtonStyle())
//                        .padding(.vertical, 5)
//                    }
//                }
//                .frame(minHeight: 120)
//                .actionBar {
//                    Button {
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "plus")
//                            Text("Add manually")
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                    .disabled(true)
//                    Spacer()
//                    Button {
//                        withAnimation(.linear(duration: 1)) {
//                            effectTrigger.toggle()
//                        } completion: {
//                            effectTrigger.toggle()
//                        }
//                        extensionManager.checkIfExtensionsAreInstalled()
//                    } label: {
//                        HStack(spacing: 3) {
//                            Image(systemName: "arrow.triangle.2.circlepath")
//                                .rotationEffect(effectTrigger ? .degrees(360) : .zero)
//                        }
//                        .foregroundStyle(.secondary)
//                    }
//                }
//                .controlSize(.small)
//                .buttonStyle(PlainButtonStyle())
//                .overlay {
//                    if extensionManager.installedExtensions.isEmpty {
//                        Text("No extension installed")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                            .padding(.bottom, 22)
//                    }
//                }
//            } header: {
//                HStack(spacing: 0) {
//                    Text("Installed extensions")
//                    if !extensionManager.installedExtensions.isEmpty {
//                        Text(" – \(extensionManager.installedExtensions.count)")
//                            .foregroundStyle(.secondary)
//                    }
//                }
//            }
//        }
//        .accentColor(.effectiveAccent)
//        .navigationTitle("Extensions")
//        // TipsView()
//        // .padding(.horizontal, 19)
//    }
//}

// Legacy `Shortcuts` form view replaced by `NMShortcutsPanel`
// (rendered through `NotchUtilitySettingsView`'s sidebar route).

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    HUD()
}

// MARK: - NotchMac utility settings view (mockup parity)

struct NotchUtilitySettingsView: View {
    enum SidebarItem: String, Hashable {
        case general
        case notch
        case modules
        case music
        case shelf
        case calendar
        case battery
        case airPods
        case pomodoro
        case hud
        case shortcuts
        case updates
        case about
    }

    let updaterController: SPUStandardUpdaterController?

    @State private var selectedItem: SidebarItem = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .background(Color.black.opacity(0.45))

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 14)

                Divider().opacity(0.12)

                ScrollView {
                    VStack(spacing: 16) {
                        settingsContent
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .frame(minWidth: 820, maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.026, blue: 0.028),
                        Color(red: 0.055, green: 0.058, blue: 0.064)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(minWidth: 1100, minHeight: 760)
        .preferredColorScheme(.dark)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                NMSidebarItem(
                    title: "General",
                    systemImage: "gearshape.fill",
                    isSelected: selectedItem == .general,
                    action: { selectedItem = .general }
                )
                NMSidebarItem(
                    title: "Notch",
                    systemImage: "rectangle.topthird.inset.filled",
                    isSelected: selectedItem == .notch,
                    action: { selectedItem = .notch }
                )
            }
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 14)

            NMSidebarSection(title: "MODULES")
                .padding(.horizontal, 18)
                .padding(.bottom, 6)

            VStack(spacing: 2) {
                NMSidebarItem(
                    title: "Modules",
                    systemImage: "square.grid.2x2.fill",
                    isSelected: selectedItem == .modules,
                    action: { selectedItem = .modules }
                )
                NMSidebarItem(
                    title: "Music",
                    systemImage: "music.note",
                    isSelected: selectedItem == .music,
                    action: { selectedItem = .music }
                )
                NMSidebarItem(
                    title: "Shelf",
                    systemImage: "tray.full.fill",
                    isSelected: selectedItem == .shelf,
                    action: { selectedItem = .shelf }
                )
                NMSidebarItem(
                    title: "Calendar",
                    systemImage: "calendar",
                    isSelected: selectedItem == .calendar,
                    action: { selectedItem = .calendar }
                )
                NMSidebarItem(
                    title: "Battery",
                    systemImage: "battery.100",
                    isSelected: selectedItem == .battery,
                    action: { selectedItem = .battery }
                )
                if AirPodsModule.visible {
                    NMSidebarItem(
                        title: "AirPods",
                        systemImage: "airpods",
                        isSelected: selectedItem == .airPods,
                        action: { selectedItem = .airPods }
                    )
                }
                NMSidebarItem(
                    title: "Pomodoro",
                    systemImage: "timer",
                    isSelected: selectedItem == .pomodoro,
                    action: { selectedItem = .pomodoro }
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)

            NMSidebarSection(title: "SYSTEM")
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                NMSidebarItem(
                    title: "HUD",
                    systemImage: "speaker.wave.2.fill",
                    isSelected: selectedItem == .hud,
                    action: { selectedItem = .hud }
                )
                NMSidebarItem(
                    title: "Shortcuts",
                    systemImage: "command",
                    isSelected: selectedItem == .shortcuts,
                    action: { selectedItem = .shortcuts }
                )
                NMSidebarItem(
                    title: "Updates",
                    systemImage: "arrow.triangle.2.circlepath",
                    isSelected: selectedItem == .updates,
                    action: { selectedItem = .updates }
                )
                NMSidebarItem(
                    title: "About",
                    systemImage: "info.circle.fill",
                    isSelected: selectedItem == .about,
                    action: { selectedItem = .about }
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("NotchMac v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(headerTitle)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
            Text(headerSubtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerTitle: String {
        switch selectedItem {
        case .general: return "General"
        case .notch: return "Notch"
        case .modules: return "Modules"
        case .music: return "Music"
        case .shelf: return "Shelf"
        case .calendar: return "Calendar"
        case .battery: return "Battery"
        case .airPods: return "AirPods"
        case .pomodoro: return "Pomodoro"
        case .hud: return "HUD"
        case .shortcuts: return "Shortcuts"
        case .updates: return "Updates"
        case .about: return "About"
        }
    }

    private var headerSubtitle: String {
        switch selectedItem {
        case .general: return "System preferences, display routing, and window privacy."
        case .notch: return "Sizing, hover behavior, gestures, and auto-hide apps."
        case .modules: return "Toggle modules live and preview the closed and open notch."
        case .music: return "Playback source, live activity, sneak peek, artwork, and controls."
        case .shelf: return "Collect, drag, and share files from the notch."
        case .calendar: return "Events, reminders, and agenda shown in the notch."
        case .battery: return "Battery level, charging state, and power notifications."
        case .airPods: return "3D live activity, battery rings, and connection alerts."
        case .pomodoro: return "Focus sessions, breaks, and timer indicators in the notch."
        case .hud: return "Replace macOS volume, brightness, keyboard, and Caps Lock indicators."
        case .shortcuts: return "Keyboard shortcuts for fast notch controls."
        case .updates: return "Keep NotchMac current with automatic releases."
        case .about: return "Version, credits, license, and project links."
        }
    }

    // MARK: Main settings content

    private var settingsContent: some View {
        VStack(spacing: 16) {
            switch selectedItem {
            case .general:
                NMGeneralSystemCard()
                NMWindowPrivacyCard()
                NMAppStatusCard()
            case .notch:
                NMBehaviorCard()
                NMSizingCard()
                NMGesturesCard()
                NMAutoHideAppsCard()
            case .modules:
                NMModulesCard()
                NMLivePreviewCard()
            case .music:
                Media()
            case .shelf:
                NMShelfPanel()
            case .calendar:
                NMCalendarPanel()
            case .battery:
                NMBatterySettingsView()
            case .airPods:
                if AirPodsModule.visible {
                    NMAirPodsPanel()
                }
            case .pomodoro:
                NMPomodoroPanel()
            case .hud:
                NMHUDPanel()
            case .shortcuts:
                NMShortcutsPanel()
            case .updates:
                NMUpdatesPanel(updater: updaterController?.updater)
            case .about:
                NMAboutPanel(updaterController: updaterController)
            }
        }
    }

    private var twoColumnGrid: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
}

// MARK: - General settings cards

private struct NMGeneralSystemCard: View {
    @Default(.menubarIcon) private var showMenuBarIcon
    @Default(.showOnAllDisplays) private var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) private var automaticallySwitchDisplay
    @Default(.showCaffeinateButton) private var showCaffeinateButton
    @ObservedObject private var coordinator = BoringViewCoordinator.shared
    @State private var screens: [(uuid: String, name: String)] = Self.availableScreens()

    var body: some View {
        NMSettingsCard(title: "System") {
            NMPreferenceRow(
                title: "Show menu bar icon",
                subtitle: "Keep NotchMac available from the macOS menu bar."
            ) {
                Toggle("", isOn: $showMenuBarIcon)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            NMPreferenceRow(
                title: "Launch at login",
                subtitle: "Start NotchMac automatically when you sign in."
            ) {
                LaunchAtLogin.Toggle("")
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            NMPreferenceRow(
                title: "Show on all displays",
                subtitle: "Create a notch window on each connected display."
            ) {
                Toggle("", isOn: $showOnAllDisplays)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
            .onChange(of: showOnAllDisplays) {
                NotificationCenter.default.post(name: .showOnAllDisplaysChanged, object: nil)
            }

            NMPreferenceRow(
                title: "Preferred display",
                subtitle: "Choose the display that owns the notch when mirroring is off.",
                badge: showOnAllDisplays ? "Unavailable" : nil,
                isEnabled: !showOnAllDisplays
            ) {
                Picker("", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(Optional(screen.uuid))
                    }
                }
                .labelsHidden()
                .frame(width: 210)
                .disabled(showOnAllDisplays)
            }

            NMPreferenceRow(
                title: "Automatically switch displays",
                subtitle: "Follow the active display when the preferred display is unavailable.",
                badge: showOnAllDisplays ? "Unavailable" : "Beta",
                isEnabled: !showOnAllDisplays
            ) {
                Toggle("", isOn: $automaticallySwitchDisplay)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(showOnAllDisplays)
            }
            .onChange(of: automaticallySwitchDisplay) {
                NotificationCenter.default.post(name: .automaticallySwitchDisplayChanged, object: nil)
            }

            NMPreferenceRow(
                title: "Show caffeinate button in notch",
                subtitle: "Adds the quick keep-awake control to the open notch header."
            ) {
                Toggle("", isOn: $showCaffeinateButton)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = Self.availableScreens()
        }
    }

    private static func availableScreens() -> [(uuid: String, name: String)] {
        NSScreen.screens.compactMap { screen in
            guard let uuid = screen.displayUUID else { return nil }
            return (uuid, screen.localizedName)
        }
    }
}

private struct NMWindowPrivacyCard: View {
    @Default(.hideTitleBar) private var hideTitleBar
    @Default(.showOnLockScreen) private var showOnLockScreen
    @Default(.hideFromScreenRecording) private var hideFromScreenRecording

    var body: some View {
        NMSettingsCard(title: "Window & Privacy") {
            NMPreferenceRow(
                title: "Hide title bar",
                subtitle: "Keeps the notch window visually flush with the menu bar."
            ) {
                Toggle("", isOn: $hideTitleBar)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            NMPreferenceRow(
                title: "Show on lock screen",
                subtitle: "Allows the notch window to remain visible while macOS is locked.",
                badge: "Requires Permission"
            ) {
                Toggle("", isOn: $showOnLockScreen)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            NMPreferenceRow(
                title: "Hide from screen recording",
                subtitle: "Marks the notch window private for supported capture paths.",
                badge: "Requires Permission"
            ) {
                Toggle("", isOn: $hideFromScreenRecording)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
        }
    }
}

private struct NMAppStatusCard: View {
    @State private var isActive: Bool = NSApp.isActive

    private var version: String {
        let v = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? "Unavailable" : v
    }

    private var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? ""
    }

    private var statusText: String { isActive ? "Running — Active" : "Running — Background" }

    var body: some View {
        NMSettingsCard(title: "App") {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    NMInfoPill(title: "Version", value: build.isEmpty ? version : "\(version) (\(build))")
                    NMStatusPill(title: "Execution", value: statusText, active: isActive)
                    Spacer(minLength: 0)
                }

                Rectangle()
                    .fill(.white.opacity(0.06))
                    .frame(height: 1)
                    .padding(.vertical, 14)

                HStack {
                    Text("Terminates all notch windows and background helpers.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                    Spacer(minLength: 12)
                    Button(role: .destructive) {
                        NSApp.terminate(nil)
                    } label: {
                        Text("Quit App")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.red.opacity(0.85))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isActive = false
        }
    }
}

private struct NMStatusPill: View {
    let title: String
    let value: String
    let active: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? Color.green : Color.yellow.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .shadow(color: (active ? Color.green : Color.yellow).opacity(0.55), radius: 3)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.045))
        )
    }
}

private struct NMSettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                content
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMSettingsCardBackground())
    }
}

private struct NMPreferenceRow<Control: View>: View {
    let title: String
    let subtitle: String
    var badge: String? = nil
    var isEnabled: Bool = true
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(isEnabled ? 0.92 : 0.38))
                    if let badge {
                        NMBadge(text: badge)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.46 : 0.26))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            control
                .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct NMInfoPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.045))
        )
    }
}

private struct NMBadge: View {
    let text: String
    let color: Color
    let subtle: Bool

    init(text: String) {
        self.text = text
        self.color = .white
        self.subtle = true
    }

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
        self.subtle = false
    }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color.opacity(subtle ? 0.72 : 0.95))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(subtle ? 0.08 : 0.16)))
            .overlay(Capsule().stroke(color.opacity(subtle ? 0.08 : 0.18), lineWidth: 0.5))
    }
}

private struct NMSettingsCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.085, green: 0.088, blue: 0.096).opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 0.7)
            )
    }
}

// MARK: - Sidebar components

private struct NMSidebarSection: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NMSidebarItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.65))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.10 : 0))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live preview

private struct NMLivePreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: "Live Preview", subtitle: "Active module plates in the closed and open notch.")

            HStack(alignment: .top, spacing: 16) {
                NMNotchMockup(isOpen: false)
                NMNotchMockup(isOpen: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(NMCardBG())
    }
}

private struct NMNotchMockup: View {
    let isOpen: Bool

    @Default(.showMusicModule) private var showMusicModule
    @Default(.showCalendar) private var showCalendar
    @Default(.showTimerModule) private var showTimerModule
    @Default(.boringShelf) private var showShelf
    @Default(.showBatteryIndicator) private var showBattery
    @Default(.enableAirPodsWidget) private var showAirPods
    @Default(.pomodoroIndicatorStyle) private var pomodoroIndicator
    @ObservedObject private var session = FocusSessionModel.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isOpen ? "Open" : "Closed")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.48))

            HStack(spacing: isOpen ? 12 : 8) {
                if showMusicModule { musicSection }
                if showShelf { previewChip("Shelf", systemImage: "tray.full.fill", tint: .blue) }
                if showCalendar { previewChip("Calendar", systemImage: "calendar", tint: .red) }
                if showBattery { batteryBadge }
                if showTimerModule { timerSection }
                if AirPodsModule.visible && showAirPods {
                    previewChip("AirPods", systemImage: "airpods", tint: .mint)
                }
                if activeChipCount == 0 {
                    Text("No active modules")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, isOpen ? 16 : 12)
            .padding(.vertical, isOpen ? 13 : 8)
            .frame(maxWidth: .infinity, minHeight: isOpen ? 96 : 44)
            .background(notchBackground)
        }
    }

    private var notchBackground: some View {
        RoundedRectangle(cornerRadius: isOpen ? 24 : 16, style: .continuous)
            .fill(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: isOpen ? 24 : 16, style: .continuous)
                    .stroke(
                        pomodoroIndicator == .ring && session.isRunning
                            ? Color.yellow.opacity(0.9)
                            : .white.opacity(0.08),
                        lineWidth: pomodoroIndicator == .ring && session.isRunning ? 2 : 0.8
                    )
            )
            .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 12)
    }

    private var activeChipCount: Int {
        [showMusicModule, showShelf, showCalendar, showBattery, showTimerModule, AirPodsModule.visible && showAirPods]
            .filter { $0 }
            .count
    }

    private func previewChip(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tint.opacity(0.22))
                .overlay(
                    Capsule().stroke(tint.opacity(0.42), lineWidth: 0.6)
                )
        )
    }

    private var musicSection: some View {
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(musicManager.songTitle.isEmpty ? "Now Playing" : musicManager.songTitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(musicManager.artistName.isEmpty ? "Artist" : musicManager.artistName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            if isOpen {
                HStack(spacing: 12) {
                    Image(systemName: "backward.fill")
                    Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13))
                    Image(systemName: "forward.fill")
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
            }
        }
    }

    private var timerSection: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(session.remainingFraction))
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 22, height: 22)
            Text(session.timeString)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
    }

    private var batteryBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: batteryModel.isCharging ? "battery.100.bolt" : "battery.100")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green.opacity(0.85))
            Text("\(Int(batteryModel.levelBattery))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(.green.opacity(0.16)))
    }
}

// MARK: - Cards

private struct NMCardBG: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 0.6)
            )
    }
}

private struct NMCardHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

private struct NMModulesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: "Module Overview", subtitle: "Toggle each notch module live.")

            VStack(spacing: 0) {
                NMModuleRow(title: "Music", subtitle: "Playback controls and track info", systemImage: "music.note", tint: .pink, key: .showMusicModule, pair: .showCalendar)
                NMDivider()
                NMModuleRow(title: "Shelf", subtitle: "Quick access to files and docs", systemImage: "tray.full.fill", tint: .blue, key: .boringShelf)
                NMDivider()
                NMModuleRow(title: "Calendar", subtitle: "Upcoming events and agenda", systemImage: "calendar", tint: .red, key: .showCalendar, pair: .showMusicModule, badges: ["Requires Permission"])
                NMDivider()
                NMModuleRow(title: "Battery", subtitle: "Battery status and charging state", systemImage: "battery.100", tint: .green, key: .showBatteryIndicator)
                NMDivider()
                NMModuleRow(title: "Timer / Pomodoro", subtitle: "Focus countdown and notch indicator", systemImage: "timer", tint: .orange, key: .showTimerModule, badges: ["Beta"])
                if AirPodsModule.visible {
                    NMDivider()
                    NMModuleRow(title: "AirPods", subtitle: "Device plate and battery alerts", systemImage: "airpods", tint: .mint, key: .enableAirPodsWidget, badges: ["Beta"])
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMMusicEffectsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(
                title: NSLocalizedString("music_effects_title", comment: "Music effects card title"),
                subtitle: NSLocalizedString("music_effects_subtitle", comment: "Music effects card subtitle")
            )

            NMDefaultsSwitchRow(
                title: NSLocalizedString("music_effects_parallax_title", comment: "Parallax tilt toggle title"),
                subtitle: NSLocalizedString("music_effects_parallax_subtitle", comment: "Parallax tilt toggle subtitle"),
                key: .enableParallaxAlbumArt
            )
            NMDefaultsSwitchRow(
                title: NSLocalizedString("music_effects_flip_title", comment: "Album art flip toggle title"),
                subtitle: NSLocalizedString("music_effects_flip_subtitle", comment: "Album art flip toggle subtitle"),
                key: .enableAlbumArtFlip
            )
            NMDefaultsSwitchRow(
                title: NSLocalizedString("music_effects_wavy_title", comment: "Wavy progress bar toggle title"),
                subtitle: NSLocalizedString("music_effects_wavy_subtitle", comment: "Wavy progress bar toggle subtitle"),
                key: .enableWavyProgressBar
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMAppleIntelligenceCard: View {
    @Default(.enableAppleIntelligenceShelf) private var enabled

    private var available: Bool { AppleIntelligenceManager.shared.isAvailable }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .leading, endPoint: .trailing))
                    .font(.system(size: 14, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple Intelligence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("On-device PDF summary and chat, shown as a tile in the shelf.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
            }

            NMSwitchRow(
                title: "Show PDF tile in shelf",
                subtitle: available
                    ? "Drop a PDF on the tile to summarize and chat about it."
                    : "Requires macOS 26 with Apple Intelligence enabled.",
                isOn: $enabled
            )

            HStack(spacing: 6) {
                Image(systemName: available ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(available ? Color.green : Color.orange)
                Text(available ? "Available on this Mac" : "Unavailable on this Mac")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 2)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMDefaultsSwitchRow: View {
    let title: String
    let subtitle: String
    let key: Defaults.Key<Bool>

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Defaults.Toggle("", key: key)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
        }
    }
}

// MARK: - Pomodoro panel

private struct NMPomodoroPanel: View {
    @Default(.showTimerModule) private var enabled
    @ObservedObject private var session = FocusSessionModel.shared

    var body: some View {
        VStack(spacing: 16) {
            if session.isRunning && !enabled {
                NMPomodoroHiddenBanner()
            }
            NMPomodoroTimerModuleCard()
            NMPomodoroCurrentTimerCard()
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
                spacing: 16
            ) {
                NMPomodoroDurationsCard()
                NMPomodoroIndicatorCard()
            }
            NMPomodoroBehaviorCard()
        }
    }
}

private struct NMPomodoroHiddenBanner: View {
    @Default(.showTimerModule) private var enabled

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 1) {
                Text("Timer is running but hidden from the notch.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Enable the Timer module to bring it back to the notch.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Button("Show Timer Module") { enabled = true }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.yellow)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.yellow.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.yellow.opacity(0.32), lineWidth: 0.8)
                )
        )
    }
}

private struct NMPomodoroTimerModuleCard: View {
    @Default(.showTimerModule) private var enabled
    @ObservedObject private var session = FocusSessionModel.shared

    private var statusText: String {
        if !enabled { return "Disabled" }
        if session.isRunning { return "Running" }
        if session.hasStarted && session.remaining > 0 && session.remaining < session.total { return "Paused" }
        return "Enabled"
    }

    private var statusColor: Color {
        switch statusText {
        case "Running": return .green
        case "Paused":  return .yellow
        case "Disabled": return .white.opacity(0.45)
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                NMCardHeader(title: "Timer Module", subtitle: "Show or hide the Pomodoro plate in the notch.")
                Spacer()
                statusPill
            }

            NMPreferenceRow(
                title: "Enable Timer / Pomodoro",
                subtitle: "Plate, indicator, and live activity in the notch."
            ) {
                Toggle("", isOn: $enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("PREVIEW")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.45))
                HStack(alignment: .top, spacing: 12) {
                    NMPomodoroNotchPreview(isOpen: false)
                    NMPomodoroNotchPreview(isOpen: true)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var statusPill: some View {
        Text(statusText.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.6)
            .foregroundStyle(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(statusColor.opacity(0.15))
                    .overlay(Capsule().stroke(statusColor.opacity(0.35), lineWidth: 0.6))
            )
    }
}

private struct NMPomodoroNotchPreview: View {
    let isOpen: Bool
    @Default(.showTimerModule) private var enabled
    @Default(.pomodoroIndicatorStyle) private var indicatorStyle
    @ObservedObject private var session = FocusSessionModel.shared

    private var ringActive: Bool { enabled && indicatorStyle == .ring && session.isRunning }
    private var dotActive: Bool { enabled && indicatorStyle == .dot && session.isRunning }
    private var sessionTint: Color { session.isBreak ? .green : .orange }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isOpen ? "Open" : "Closed")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.4))

            ZStack {
                RoundedRectangle(cornerRadius: isOpen ? 18 : 12, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: isOpen ? 18 : 12, style: .continuous)
                            .stroke(
                                ringActive ? sessionTint.opacity(0.9) : .white.opacity(0.10),
                                lineWidth: ringActive ? 2 : 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 6)

                HStack(spacing: isOpen ? 8 : 6) {
                    if enabled {
                        timerChip
                    } else {
                        Text("Hidden")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                    if dotActive {
                        Circle()
                            .fill(sessionTint)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, isOpen ? 16 : 10)
            }
            .frame(maxWidth: .infinity)
            .frame(height: isOpen ? 78 : 36)
        }
    }

    private var timerChip: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().stroke(.white.opacity(0.15), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: CGFloat(session.remainingFraction))
                    .stroke(sessionTint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: isOpen ? 26 : 18, height: isOpen ? 26 : 18)
            Text(session.timeString)
                .font(.system(size: isOpen ? 13 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            if isOpen {
                Text(session.hasStarted ? session.sessionLabel : "Idle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(sessionTint)
            }
        }
    }
}

private struct NMPomodoroDurationsCard: View {
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroBreakMinutes) private var breakMinutes
    @ObservedObject private var session = FocusSessionModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Durations", subtitle: "Focus and break length in minutes.")

            NMStepperRow(
                title: "Focus Session",
                subtitle: "1 – 180 min",
                value: $focusMinutes,
                range: 1...180,
                suffix: "min"
            )
            NMStepperRow(
                title: "Break",
                subtitle: "1 – 60 min",
                value: $breakMinutes,
                range: 1...60,
                suffix: "min"
            )

            Button {
                focusMinutes = 25
                breakMinutes = 5
                if !session.isRunning {
                    session.applyConfiguredDurationToCurrentTimer(resetRemaining: true)
                }
            } label: {
                Label("Reset to defaults (25 / 5)", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
        .onChange(of: focusMinutes) { _, _ in
            guard !session.isRunning, !session.isBreak else { return }
            session.applyConfiguredDurationToCurrentTimer(resetRemaining: true)
        }
        .onChange(of: breakMinutes) { _, _ in
            guard !session.isRunning, session.isBreak else { return }
            session.applyConfiguredDurationToCurrentTimer(resetRemaining: true)
        }
    }
}

private struct NMPomodoroIndicatorCard: View {
    @Default(.pomodoroIndicatorStyle) private var indicatorStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Notch Indicator", subtitle: "Shown while a Pomodoro session is active.")

            Picker("", selection: $indicatorStyle) {
                Text("Off").tag(PomodoroIndicatorStyle.off)
                Text("Dot").tag(PomodoroIndicatorStyle.dot)
                Text("Ring").tag(PomodoroIndicatorStyle.ring)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            NMPomodoroNotchPreview(isOpen: false)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMPomodoroCurrentTimerCard: View {
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroBreakMinutes) private var breakMinutes
    @ObservedObject private var session = FocusSessionModel.shared

    private var stateLabel: String {
        if !session.hasStarted { return "Idle" }
        return session.isBreak ? "Break" : "Focus"
    }

    private var stateTint: Color {
        if !session.hasStarted { return .white.opacity(0.55) }
        return session.isBreak ? .green : .orange
    }

    private var needsApply: Bool {
        guard session.hasStarted else { return false }
        let configured = session.isBreak ? breakMinutes : focusMinutes
        return Int(session.total) != configured * 60
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Current Timer", subtitle: "Control the live Pomodoro session.")

            HStack(spacing: 18) {
                ringDisplay
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(stateTint).frame(width: 7, height: 7)
                        Text(stateLabel.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.6)
                            .foregroundStyle(stateTint)
                    }
                    Text(session.timeString)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("of \(session.totalString)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                        .monospacedDigit()
                }
                Spacer()
            }

            buttonsRow

            if needsApply {
                Button {
                    session.applyConfiguredDurationToCurrentTimer(resetRemaining: false)
                } label: {
                    Label("Apply Settings to Current Timer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.orange)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var ringDisplay: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.10), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(session.remainingFraction))
                .stroke(
                    AngularGradient(colors: [stateTint, stateTint.opacity(0.55), stateTint], center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: session.remainingFraction)
        }
        .frame(width: 78, height: 78)
    }

    private var buttonsRow: some View {
        HStack(spacing: 8) {
            Button {
                session.startFocus()
            } label: {
                Label("Start Focus", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)

            Button {
                session.startBreak()
            } label: {
                Label("Start Break", systemImage: "cup.and.saucer.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                session.toggle()
            } label: {
                Label(session.isRunning ? "Pause" : "Resume",
                      systemImage: session.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!session.hasStarted)

            Button {
                session.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()
        }
    }
}

private struct NMPomodoroBehaviorCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            NMCardHeader(title: "Behavior", subtitle: "How sessions chain and notify when they end.")
                .padding(.bottom, 8)

            NMDefaultsSwitchRow(
                title: "Auto-start break after focus",
                subtitle: "Start the break countdown the moment focus ends.",
                key: .pomodoroAutoStartBreak
            )
            Divider().background(Color.white.opacity(0.05))
            NMDefaultsSwitchRow(
                title: "Auto-start next focus after break",
                subtitle: "Roll straight into the next focus block.",
                key: .pomodoroAutoStartFocus
            )
            Divider().background(Color.white.opacity(0.05))
            NMDefaultsSwitchRow(
                title: "Play sound when session ends",
                subtitle: "macOS Glass alert on completion.",
                key: .pomodoroPlaySoundOnEnd
            )
            Divider().background(Color.white.opacity(0.05))
            NMDefaultsSwitchRow(
                title: "Show completion notification",
                subtitle: "Banner via macOS Notification Center.",
                key: .pomodoroShowCompletionNotification
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMPomodoroMiniPreview: View {
    @Default(.pomodoroIndicatorStyle) private var indicatorStyle
    @ObservedObject private var session = FocusSessionModel.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(session.remainingFraction))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.orange)
                Text(session.timeString)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            Spacer()

            Text(indicatorStyle.rawValue)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.045))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.07), lineWidth: 0.6))
        )
    }
}

private struct NMAlbumArtCard: View {
    @Default(.albumArtDisplayMode) private var displayMode
    @Default(.liveActivityAlbumArtSize) private var artSize
    @Default(.liveActivityAlbumArtCornerRadius) private var artCornerRadius
    @Default(.liveActivityAlbumArtShadow) private var artShadow

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(
                title: "Album Art",
                subtitle: "How the music live activity shows the artwork on the closed notch."
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Display Mode")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Always show, fade after 3 s of inactivity, or swap the artwork for the source app icon.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Picker("", selection: $displayMode) {
                    ForEach(AlbumArtDisplayMode.allCases) { mode in
                        Text(mode.localizedString).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            NMSliderRow(
                title: "Size",
                subtitle: "Multiplier over the closed-notch base size.",
                value: $artSize,
                range: 0.5...1.5,
                step: 0.05,
                format: "%.2fx"
            )

            NMSliderRow(
                title: "Corner Radius",
                subtitle: "Multiplier over the closed-notch base corner radius.",
                value: $artCornerRadius,
                range: 0.0...2.0,
                step: 0.05,
                format: "%.2fx"
            )

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drop Shadow")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Adds a subtle shadow under the artwork.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $artShadow)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(.green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMSliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let step: CGFloat
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
                .tint(.green)
        }
    }
}

private struct NMStepperRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value) \(suffix)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 62, alignment: .trailing)
            }
            .controlSize(.small)
            .frame(width: 145)
        }
    }
}

private struct NMDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 44)
    }
}

private struct NMModuleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: SwiftUI.Color
    let key: Defaults.Key<Bool>
    var pair: Defaults.Key<Bool>? = nil
    var badges: [String] = []
    @Default(.showMusicModule) private var musicOn
    @Default(.boringShelf) private var shelfOn
    @Default(.showCalendar) private var calendarOn
    @Default(.showBatteryIndicator) private var batteryOn
    @Default(.showTimerModule) private var timerOn
    @Default(.enableAirPodsWidget) private var airPodsOn

    var body: some View {
        let _ = refreshToken
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 7) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    ForEach(badges, id: \.self) { badge in
                        NMBadge(text: badge)
                    }
                }
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(isEnabled ? .green.opacity(0.9) : .white.opacity(0.36))
                .frame(width: 54, alignment: .trailing)
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
        }
        .padding(.vertical, 9)
    }

    private var isEnabled: Bool { Defaults[key] }

    private var refreshToken: String {
        "\(musicOn)-\(shelfOn)-\(calendarOn)-\(batteryOn)-\(timerOn)-\(airPodsOn)"
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { Defaults[key] },
            set: { newValue in
                Defaults[key] = newValue
                if let pair, newValue == false, Defaults[pair] == false {
                    Defaults[pair] = true
                }
            }
        )
    }
}

private struct NMBehaviorCard: View {
    @Default(.openNotchOnHover) var openOnHover
    @Default(.minimumHoverDuration) var hoverDelay
    @Default(.enableHaptics) var enableHaptics
    @ObservedObject private var coordinator = BoringViewCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Behavior", subtitle: "Opening and feedback behavior.")

            NMSwitchRow(title: "Open on hover", subtitle: "Expand when the pointer rests on the notch.", isOn: $openOnHover)
                .onChange(of: openOnHover) { _, enabled in
                    if !enabled { Defaults[.enableGestures] = true }
                }
            NMSliderRow(
                title: "Hover delay",
                subtitle: "Delay before hover opens the notch.",
                value: Binding(
                    get: { CGFloat(hoverDelay) },
                    set: { hoverDelay = TimeInterval($0) }
                ),
                range: 0...1,
                step: 0.05,
                format: "%.2fs"
            )
            .opacity(openOnHover ? 1 : 0.45)
            .disabled(!openOnHover)
            NMSwitchRow(title: "Enable haptic feedback", subtitle: "Use subtle trackpad feedback on interactions.", isOn: $enableHaptics)
            NMSwitchRow(title: "Remember last tab", subtitle: "Reopen the notch on the last selected tab.", isOn: $coordinator.openLastTabByDefault)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMSizingCard: View {
    @Default(.notchHeightMode) private var notchHeightMode
    @Default(.notchHeight) private var notchHeight
    @Default(.nonNotchHeightMode) private var nonNotchHeightMode
    @Default(.nonNotchHeight) private var nonNotchHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: "Sizing", subtitle: "Closed notch height per display type.")

            heightModeSection(
                title: "Notch height on notch displays",
                selection: $notchHeightMode,
                height: $notchHeight,
                defaultReal: 38,
                defaultMenu: 44,
                range: 15...45
            )

            Divider().opacity(0.10)

            heightModeSection(
                title: "Notch height on non-notch displays",
                selection: $nonNotchHeightMode,
                height: $nonNotchHeight,
                defaultReal: 32,
                defaultMenu: 24,
                range: 0...40
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private func heightModeSection(
        title: String,
        selection: Binding<WindowHeightMode>,
        height: Binding<CGFloat>,
        defaultReal: CGFloat,
        defaultMenu: CGFloat,
        range: ClosedRange<CGFloat>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)

            Picker("", selection: Binding(
                get: { selection.wrappedValue },
                set: { newValue in
                    selection.wrappedValue = newValue
                    switch newValue {
                    case .matchRealNotchSize:
                        height.wrappedValue = defaultReal
                    case .matchMenuBar:
                        height.wrappedValue = defaultMenu
                    case .custom:
                        height.wrappedValue = defaultReal
                    }
                    publishSizingChange()
                }
            )) {
                Text("Match real notch height").tag(WindowHeightMode.matchRealNotchSize)
                Text("Match menu bar height").tag(WindowHeightMode.matchMenuBar)
                Text("Custom height").tag(WindowHeightMode.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if selection.wrappedValue == .custom {
                NMSliderRow(
                    title: "Custom height",
                    subtitle: "Applies instantly to all notch windows.",
                    value: Binding(
                        get: { height.wrappedValue },
                        set: {
                            height.wrappedValue = $0
                            publishSizingChange()
                        }
                    ),
                    range: range,
                    step: 1,
                    format: "%.0f px"
                )
            }
        }
    }

    private func publishSizingChange() {
        NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
    }
}

private struct NMGesturesCard: View {
    @Default(.enableGestures) private var enableGestures
    @Default(.enableHorizontalMediaGestures) private var horizontalGestures
    @Default(.closeGestureEnabled) private var closeGesture
    @Default(.gestureSensitivity) private var gestureSensitivity
    @Default(.openNotchOnHover) private var openOnHover

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                NMCardHeader(title: "Gestures", subtitle: "Trackpad gestures for the notch.")
                NMBadge("Beta", color: .purple)
                Spacer()
            }

            NMSwitchRow(title: "Enable gestures", subtitle: "Use gestures to open and close the notch.", isOn: $enableGestures)
                .disabled(!openOnHover)
                .opacity(openOnHover ? 1 : 0.45)
            NMSwitchRow(title: "Change media with horizontal gestures", subtitle: "Swipe horizontally to change tracks.", isOn: $horizontalGestures)
                .disabled(!enableGestures)
                .opacity(enableGestures ? 1 : 0.45)
            NMSwitchRow(title: "Close gesture", subtitle: "Swipe up to collapse the notch.", isOn: $closeGesture)
                .disabled(!enableGestures)
                .opacity(enableGestures ? 1 : 0.45)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Gesture sensitivity")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(sensitivityLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Picker("", selection: $gestureSensitivity) {
                    Text("High").tag(CGFloat(100))
                    Text("Medium").tag(CGFloat(200))
                    Text("Low").tag(CGFloat(300))
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!enableGestures)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var sensitivityLabel: String {
        gestureSensitivity == 100 ? "High" : gestureSensitivity == 200 ? "Medium" : "Low"
    }
}

private struct NMAutoHideAppsCard: View {
    @Default(.nmAutoHideAppBundleIDs) var autoHideBundleIDs
    @State private var runningApps: [NMAppChoice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                NMCardHeader(title: "Auto-hide Apps", subtitle: "Hide the notch when selected apps are active.")
                Spacer()
                NMBadge("⌥X manual toggle", color: .white)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Configured apps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                ForEach(configuredApps) { app in
                    NMConfiguredAppRow(
                        app: app,
                        isActive: app.bundleID == NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                        remove: { remove(app.bundleID) }
                    )
                }

                if configuredApps.isEmpty {
                    Text("No apps configured.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Active apps detected")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                ForEach(runningApps.prefix(6)) { app in
                    NMAppToggleRow(
                        app: app,
                        isActive: app.bundleID == NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                        isOn: Binding(
                            get: { autoHideBundleIDs.contains(app.bundleID) },
                            set: { enabled in
                                if enabled { add(app.bundleID) } else { remove(app.bundleID) }
                            }
                        )
                    )
                }
            }

            HStack {
                Button {
                    pickApp()
                } label: {
                    Label("Choose App", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
        .onAppear(perform: refreshRunningApps)
        .onReceive(workspacePublisher(NSWorkspace.didActivateApplicationNotification)) { _ in
            refreshRunningApps()
        }
        .onReceive(workspacePublisher(NSWorkspace.didLaunchApplicationNotification)) { _ in
            refreshRunningApps()
        }
        .onReceive(workspacePublisher(NSWorkspace.didTerminateApplicationNotification)) { _ in
            refreshRunningApps()
        }
    }

    private var configuredApps: [NMAppChoice] {
        autoHideBundleIDs.map { NMAppChoice(bundleID: $0) }
            .uniquedByBundleID()
            .sorted { lhs, rhs in
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private func add(_ bundleID: String) {
        guard !autoHideBundleIDs.contains(bundleID) else { return }
        autoHideBundleIDs.append(bundleID)
        notifyChange()
    }

    private func remove(_ bundleID: String) {
        autoHideBundleIDs.removeAll { $0 == bundleID }
        notifyChange()
    }

    private func refreshRunningApps() {
        let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .compactMap { app -> NMAppChoice? in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier else { return nil }
                return NMAppChoice(bundleID: bundleID, fallbackName: app.localizedName)
            }

        let frontmost = frontmostBundleID == Bundle.main.bundleIdentifier
            ? nil
            : frontmostBundleID.map { NMAppChoice(bundleID: $0) }
        runningApps = (apps + [frontmost].compactMap { $0 })
            .uniquedByBundleID()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK,
              let url = panel.url,
              let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else { return }
        add(bundleID)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .nmAutoHideAppsChanged, object: nil)
    }

    private func workspacePublisher(_ name: Notification.Name) -> NotificationCenter.Publisher {
        NSWorkspace.shared.notificationCenter.publisher(for: name)
    }
}

private struct NMAppChoice: Identifiable {
    let bundleID: String
    let fallbackName: String?

    init(bundleID: String, fallbackName: String? = nil) {
        self.bundleID = bundleID
        self.fallbackName = fallbackName
    }

    var id: String { bundleID }

    var name: String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url) else {
            return fallbackName ?? bundleID
        }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? fallbackName
            ?? url.deletingPathExtension().lastPathComponent
    }

    var icon: NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}

private struct NMAppToggleRow: View {
    let app: NMAppChoice
    let isActive: Bool
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
            if isActive {
                Text("Active")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.green.opacity(0.95))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.green.opacity(0.16)))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.green)
        }
    }
}

private struct NMConfiguredAppRow: View {
    let app: NMAppChoice
    let isActive: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 20, height: 20)
            Text(app.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
            if isActive {
                NMBadge("Active", color: .green)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
    }
}

private extension Array where Element == NMAppChoice {
    func uniquedByBundleID() -> [NMAppChoice] {
        var seen: Set<String> = []
        return filter { seen.insert($0.bundleID).inserted }
    }
}

private struct NMSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
        }
    }
}

// MARK: - About panel

private struct NMAboutPanel: View {
    let updaterController: SPUStandardUpdaterController?

    @Default(.releaseName) private var releaseName: String
    @State private var diagnosticsCopied: Bool = false
    @State private var onboardingReset: Bool = false

    private var versionString: String {
        Bundle.main.releaseVersionNumber ?? "—"
    }

    private var buildString: String {
        Bundle.main.buildVersionNumber ?? "—"
    }

    var body: some View {
        VStack(spacing: 16) {
            aboutCard
            HStack(alignment: .top, spacing: 16) {
                creditsCard
                linksCard
            }
            diagnosticsCard
        }
    }

    // MARK: About card

    private var aboutCard: some View {
        HStack(alignment: .center, spacing: 18) {
            appIcon
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.6)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("NotchMac")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                Text("Personal fork of boring.notch")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                HStack(spacing: 8) {
                    NMAboutTag(label: "Version", value: versionString)
                    NMAboutTag(label: "Build", value: buildString)
                    NMAboutTag(label: "Release", value: releaseName)
                }
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var appIcon: some View {
        Group {
            if let icon = NSImage(named: NSImage.Name("AppIcon")) ?? NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.08))
            }
        }
    }

    // MARK: Credits card

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Credits", subtitle: "Project lineage and authors.")

            VStack(spacing: 0) {
                NMAboutCreditRow(
                    title: "Original",
                    value: "TheBoredTeam",
                    url: URL(string: "https://github.com/TheBoredTeam")
                )
                NMUpdatesDivider()
                NMAboutCreditRow(
                    title: "Rebrand & customizations",
                    value: "@fabiannavarrofonte",
                    url: URL(string: "https://github.com/fabiannavarroo")
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    // MARK: Links card

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Links", subtitle: "Source, license, and releases.")

            VStack(spacing: 0) {
                NMAboutLinkRow(
                    title: "Original repo",
                    subtitle: "TheBoredTeam/boring.notch",
                    systemImage: "chevron.left.forwardslash.chevron.right",
                    url: URL(string: "https://github.com/TheBoredTeam/boring.notch")!
                )
                NMUpdatesDivider()
                NMAboutLinkRow(
                    title: "This fork",
                    subtitle: "fabiannavarroo/Notch-Mac-v2",
                    systemImage: "arrow.triangle.branch",
                    url: URL(string: "https://github.com/fabiannavarroo/Notch-Mac-v2")!
                )
                NMUpdatesDivider()
                NMAboutLinkRow(
                    title: "License",
                    subtitle: "GPL-3.0",
                    systemImage: "doc.text",
                    url: URL(string: "https://github.com/fabiannavarroo/Notch-Mac-v2/blob/main/LICENSE")!
                )
                NMUpdatesDivider()
                NMAboutLinkRow(
                    title: "Changelog / Releases",
                    subtitle: "GitHub releases feed",
                    systemImage: "tag",
                    url: URL(string: "https://github.com/fabiannavarroo/Notch-Mac-v2/releases")!
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    // MARK: Diagnostics card

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Diagnostics", subtitle: "Helpful info when reporting a bug.")

            HStack(spacing: 10) {
                NMAboutActionButton(
                    title: diagnosticsCopied ? "Copied" : "Copy Diagnostics",
                    systemImage: diagnosticsCopied ? "checkmark" : "doc.on.clipboard",
                    tint: .green
                ) {
                    copyDiagnostics()
                }

                NMAboutActionButton(
                    title: "Open Logs",
                    systemImage: "terminal",
                    tint: .white.opacity(0.18)
                ) {
                    openLogs()
                }

                NMAboutActionButton(
                    title: onboardingReset ? "Restarted" : "Reset Onboarding",
                    systemImage: onboardingReset ? "checkmark" : "arrow.counterclockwise",
                    tint: .white.opacity(0.18)
                ) {
                    resetOnboarding()
                }

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    // MARK: Actions

    private func copyDiagnostics() {
        let proc = ProcessInfo.processInfo
        let os = proc.operatingSystemVersion
        let osString = "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
        let lines: [String] = [
            "NotchMac \(versionString) (\(buildString))",
            "Release name: \(releaseName)",
            "Bundle: \(Bundle.main.bundleIdentifier ?? "—")",
            "macOS: \(osString)",
            "Locale: \(Locale.current.identifier)",
            "Screens: \(NSScreen.screens.count)"
        ]
        let payload = lines.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)

        diagnosticsCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            diagnosticsCopied = false
        }
    }

    private func openLogs() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.fabiannavarrofonte.notchmac"
        let consoleURL = URL(fileURLWithPath: "/System/Applications/Utilities/Console.app")
        NSWorkspace.shared.open(consoleURL)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(bundleID, forType: .string)
    }

    private func resetOnboarding() {
        NotificationCenter.default.post(
            name: .nmShowOnboarding,
            object: nil,
            userInfo: ["reset": true]
        )
        onboardingReset = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            onboardingReset = false
        }
    }
}

private struct NMAboutTag: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(0.6)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.white.opacity(0.05))
                .overlay(Capsule().stroke(.white.opacity(0.06), lineWidth: 0.5))
        )
    }
}

private struct NMAboutCreditRow: View {
    let title: String
    let value: String
    let url: URL?

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            if let url {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Text(value)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
    }
}

private struct NMAboutLinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let url: URL

    var body: some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct NMAboutActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(tint == .green ? 0.85 : 1))
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct NMUpdateRow: View {
    @ObservedObject private var checker: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        self.checker = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text("Updates")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text(updater.automaticallyChecksForUpdates
                     ? "Comprueba en GitHub cada hora."
                     : "Comprobaciones automáticas desactivadas.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            Button {
                updater.checkForUpdates()
            } label: {
                Label("Buscar actualizaciones", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.accentColor)
            .disabled(!checker.canCheckForUpdates)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Updates panel

private struct NMUpdatesPanel: View {
    let updater: SPUUpdater?
    @ObservedObject private var model = UpdatesStatusModel.shared

    var body: some View {
        VStack(spacing: 16) {
            softwareUpdatesCard
            HStack(alignment: .top, spacing: 16) {
                versionCard
                statusCard
            }
            releaseNotesCard
        }
    }

    // MARK: Software Updates

    private var softwareUpdatesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Software Updates", subtitle: "Sparkle pulls signed releases from GitHub.")

            NMUpdatesSwitchRow(
                title: "Automatically check for updates",
                subtitle: "Look for new releases every hour.",
                isOn: $model.automaticallyChecksForUpdates,
                isEnabled: updater != nil
            )
            NMUpdatesSwitchRow(
                title: "Automatically download updates",
                subtitle: "Stage the installer in the background when one is found.",
                isOn: $model.automaticallyDownloadsUpdates,
                isEnabled: updater != nil && model.automaticallyChecksForUpdates
            )

            Divider().background(.white.opacity(0.06))

            HStack(spacing: 10) {
                Text("Trigger an immediate check now.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    model.checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        if model.sessionInProgress {
                            ProgressView()
                                .controlSize(.mini)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(model.sessionInProgress ? "Checking…" : "Check for Updates")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.green)
                .disabled(updater == nil || !model.canCheckForUpdates || model.sessionInProgress)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    // MARK: Current Version

    private var versionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Current Version", subtitle: "Build info reported by the app bundle.")

            VStack(spacing: 0) {
                NMUpdatesInfoRow(label: "App version", value: Bundle.main.releaseVersionNumber ?? "—")
                NMUpdatesDivider()
                NMUpdatesInfoRow(label: "Build number", value: Bundle.main.buildVersionNumber ?? "—")
                NMUpdatesDivider()
                NMUpdatesInfoRow(label: "Release name", value: Defaults[.releaseName])
                NMUpdatesDivider()
                NMUpdatesInfoRow(label: "Last checked", value: formattedLastChecked)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var formattedLastChecked: String {
        guard let date = model.lastChecked else { return "Never" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    // MARK: Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Status", subtitle: "Updater feedback.")

            HStack(spacing: 12) {
                statusIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(statusSubtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer()
                if model.sessionInProgress {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if case let .updateAvailable(_, _, url?) = model.status {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Download update")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private var statusIcon: some View {
        Group {
            switch model.status {
            case .checking:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.white)
            case .upToDate:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .updateAvailable:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .idle:
                Image(systemName: "circle.dotted")
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .font(.system(size: 18, weight: .semibold))
        .frame(width: 22)
    }

    private var statusTitle: String {
        switch model.status {
        case .checking: return "Checking…"
        case .upToDate: return "Up to date"
        case .updateAvailable(let v, _, _): return "Update available · \(v)"
        case .failed: return "Check failed"
        case .idle: return "Idle"
        }
    }

    private var statusSubtitle: String {
        switch model.status {
        case .checking:
            return "Contacting the appcast feed."
        case .upToDate:
            return "You have the latest signed release."
        case .updateAvailable(_, let notes, _):
            if let notes, !notes.isEmpty {
                return notes.replacingOccurrences(of: "\n", with: " ")
            }
            return "A newer signed release is available."
        case .failed(let msg):
            return msg
        case .idle:
            return "Click Check for Updates to query the feed."
        }
    }

    // MARK: Release Notes

    private var releaseNotesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Release Notes", subtitle: "What changed in recent releases.")

            if case let .updateAvailable(_, notes, _) = model.status, let notes, !notes.isEmpty {
                Text(notes)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Notes appear here when an update is detected. Open the releases page for the full changelog.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let url = URL(string: "https://github.com/fabiannavarroo/Notch-Mac-v2/releases") {
                HStack {
                    Spacer()
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.right.square")
                            Text("Open Releases")
                        }
                        .font(.system(size: 12, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.white)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMUpdatesSwitchRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.45))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.5 : 0.3))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
                .disabled(!isEnabled)
        }
    }
}

private struct NMUpdatesInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 8)
    }
}

private struct NMUpdatesDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 0.6)
    }
}

// MARK: - AirPods debug card

private struct NMAirPodsDebugCard: View {
    @Default(.airPodsShowConnectActivity) private var showOnConnect
    @Default(.airPodsDebugAlwaysShow)     private var alwaysShow
    @Default(.airPodsDebugVariant)        private var debugVariantRaw

    @ObservedObject private var tuningCenter = AirPodsTuningCenter.shared

    @State private var previewVM = BoringViewModel()
    @State private var expandedAdvanced: Bool = false
    @State private var expandedDashboard: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NMCardHeader(
                title: "AirPods — apariencia (modo tuning)",
                subtitle: "Activa “Modo tuning” para que el notch real muestre la variante seleccionada sin tener que conectar AirPods. Útil para afinar cada modelo antes de fijar los valores por defecto."
            )
            .padding(.bottom, 12)

            // Sticky header — preview + variant picker + global toggles
            // stay pinned while the slider list scrolls below.
            VStack(alignment: .leading, spacing: 12) {
                preview
                variantPicker
                HStack(spacing: 14) {
                    compactToggle($alwaysShow, label: "Modo tuning (forzar visible)")
                    compactToggle($showOnConnect, label: "Animación al conectar")
                }
                Text("Ajustes para: \(variantDisplayName(selectedVariant))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.mint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 0.6)
                    )
            )
            .padding(.bottom, 12)

            // Scrolling slider area
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    slidersContent
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 360)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    private func compactToggle(_ binding: Binding<Bool>, label: String) -> some View {
        Toggle(isOn: binding) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
    }

    @ViewBuilder
    private var slidersContent: some View {
        Group {

            Group {
                sectionTitle("Layout del tile 3D")
                slider("Ancho del tile (× alto)",   tuneBinding(\.artWidthMultiplier), range: 1.0...3.5, step: 0.05, format: "%.2f")
                slider("Padding lateral del 3D",    tuneBinding(\.artSidePadding),     range: 0...40,    step: 1,    format: "%.0f pt")
                slider("Desplazamiento horizontal", tuneBinding(\.artLeftShift),       range: -60...30,  step: 1,    format: "%.0f pt")
            }

            Divider().background(.white.opacity(0.08))

            Group {
                sectionTitle("Modelo 3D — render")
                Toggle(isOn: tuneBindingBool(\.showFullModel)) {
                    debugLabel("Mostrar modelo completo",
                               "Desactiva el filtro de caja y muestra los AirPods enteros (caja incluida).")
                }
                .toggleStyle(.switch)
                Toggle(isOn: tuneBindingBool(\.rotationReversed)) {
                    debugLabel("Rotación invertida",
                               "Cambia el sentido de giro del modelo.")
                }
                .toggleStyle(.switch)
                slider("Zoom modelo",             tuneBinding(\.modelZoom),       range: 0.3...2.5, step: 0.02, format: "%.2f")
                slider("Inclinación X (°)",       tuneBinding(\.modelTiltX),      range: -45...45,  step: 1,    format: "%.0f°")
                slider("Desplazamiento vertical", tuneBinding(\.modelYShift),     range: -0.4...0.4, step: 0.01, format: "%.2f")
                slider("Segundos por vuelta",     tuneBinding(\.rotationSeconds), range: 1.0...20,  step: 0.5,  format: "%.1f s")
            }

            DisclosureGroup(isExpanded: $expandedAdvanced) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Cámara")
                    slider("Campo de visión (FOV)", tuneBinding(\.cameraFOV), range: 10...60,   step: 1,    format: "%.0f°")
                    slider("Distancia cámara (Z)",  tuneBinding(\.cameraZ),   range: 1.5...6.0, step: 0.05, format: "%.2f")
                    slider("Altura cámara (Y)",     tuneBinding(\.cameraY),   range: -0.5...0.5, step: 0.01, format: "%.2f")

                    Divider().background(.white.opacity(0.08))

                    sectionTitle("Filtro de caja")
                    Toggle(isOn: tuneBindingBool(\.filterStrict)) {
                        debugLabel("Filtro estricto (OR)",
                                   "Quita LED + barra de metal + bisagra: borra mallas que estén bajo la línea Y *o* sean demasiado anchas. Desactivar = solo borra si cumple ambas (puede dejar piezas sueltas).")
                    }
                    .toggleStyle(.switch)
                    slider("Línea de corte (Y)",    tuneBinding(\.filterPositionCut), range: 0.0...1.0, step: 0.01, format: "%.2f")
                    slider("Umbral de área",        tuneBinding(\.filterAreaCut),     range: 0.1...0.9, step: 0.01, format: "%.2f")
                    Text("Estricto borra cualquier malla bajo la línea Y. Si los palos (stems) desaparecen, baja la línea de corte hacia 0.35.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 8)
            } label: {
                debugLabel("Avanzado (cámara + filtro)",
                           "Controles finos para casos raros. Si no los necesitas, déjalos colapsados.")
            }
            .tint(.mint)

            Divider().background(.white.opacity(0.08))

            Group {
                sectionTitle("Anillo de batería")
                slider("Diámetro",        tuneBinding(\.ringDiameter),    range: 10...50, step: 1,    format: "%.0f pt")
                slider("Grosor",          tuneBinding(\.ringStrokeWidth), range: 0.5...8, step: 0.1,  format: "%.1f pt")
                slider("Padding lateral", tuneBinding(\.ringSidePadding), range: 0...40,  step: 1,    format: "%.0f pt")
                slider("Tamaño del %",    tuneBinding(\.ringTextScale),   range: 0.2...0.7, step: 0.01, format: "%.2f")
            }

            DisclosureGroup(isExpanded: $expandedDashboard) {
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("Modelo 3D — expandido")
                    Toggle(isOn: tuneBindingBool(\.dashboardShowFullModel)) {
                        debugLabel("Mostrar caja en expandido",
                                   "ON: rota AirPods + caja completa. OFF: aplica el filtro de caja del mini.")
                    }
                    .toggleStyle(.switch)
                    slider("Tamaño tile",         tuneBinding(\.dashboardTileSize),       range: 60...180, step: 1,    format: "%.0f pt")
                    slider("Zoom modelo",         tuneBinding(\.dashboardModelZoom),      range: 0.3...2.5, step: 0.02, format: "%.2f")
                    slider("Inclinación X (°)",   tuneBinding(\.dashboardModelTiltX),     range: -45...45,  step: 1,    format: "%.0f°")
                    slider("Distancia cámara Z",  tuneBinding(\.dashboardCameraZ),        range: 1.5...6.0, step: 0.05, format: "%.2f")
                    slider("Altura cámara Y",     tuneBinding(\.dashboardCameraY),        range: -0.5...0.5, step: 0.01, format: "%.2f")
                    slider("Campo visión (FOV)",  tuneBinding(\.dashboardCameraFOV),      range: 10...60,   step: 1,    format: "%.0f°")
                    slider("Segundos por vuelta", tuneBinding(\.dashboardRotationSeconds), range: 1.0...20,  step: 0.5,  format: "%.1f s")
                }
                .padding(.top, 8)
            } label: {
                debugLabel("Expandido (notch abierto)",
                           "Ajustes independientes para la vista grande con caja y batería L/R/Case.")
            }
            .tint(.mint)

            Divider().background(.white.opacity(0.08))

            HStack {
                Button("Restablecer valores", action: resetDefaults)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
                Button("Replay animación") {
                    AirPodsManager.shared.replaySneakActivity()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // Two previews stacked: the closed-notch mini and the expanded
    // dashboard. Each shows the actual rendered view with the user's
    // current per-variant tuning so what you see in Settings matches
    // what shows up on the real notch.
    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            previewBlock(title: "MINI (NOTCH CERRADO)") {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black)
                    AirPodsLiveActivity(
                        override: AirPodsLiveActivity.mockState(for: selectedVariant),
                        heightOverride: 32
                    )
                    .environmentObject(previewVM)
                }
                .frame(height: 56)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            previewBlock(title: "EXPANDIDO (NOTCH ABIERTO)") {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black)
                    AirPodsDashboardPreviewWrapper(
                        variant: selectedVariant
                    )
                    .environmentObject(previewVM)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func previewBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.45))
            content()
        }
    }

    /// Variant the preview + the debug-always-show fallback render. Bound
    /// to airPodsDebugVariant so the real notch reflects the choice too.
    private var selectedVariant: AirPodsModelVariant {
        AirPodsModelVariant(rawValue: debugVariantRaw) ?? .airPodsPro
    }

    private var variantPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Modelo a previsualizar")
            Picker("", selection: Binding(
                get: { selectedVariant },
                set: { debugVariantRaw = $0.rawValue }
            )) {
                Text("AirPods").tag(AirPodsModelVariant.airPods)
                Text("AirPods 4 ANC").tag(AirPodsModelVariant.airPodsANC)
                Text("AirPods Pro").tag(AirPodsModelVariant.airPodsPro)
                Text("AirPods Max").tag(AirPodsModelVariant.airPodsMax)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("La descarga del modelo es perezosa: la primera vez que cambies de variante puede tardar 1–2 s en aparecer mientras se baja desde Apple.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(.white.opacity(0.55))
    }

    private func debugLabel(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func slider(
        _ title: String,
        _ binding: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                // Current value — big, bright, monospaced badge so the
                // user sees the number change live as they drag.
                Text(String(format: format, binding.wrappedValue))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.mint)
                    .monospacedDigit()
                    .frame(minWidth: 72, alignment: .trailing)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.mint.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.mint.opacity(0.35), lineWidth: 0.6)
                            )
                    )
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.12), value: binding.wrappedValue)
            }
            Slider(value: binding, in: range, step: step)
                .controlSize(.small)
                .tint(.mint)
            // Min / max hint so the user knows the bounds at a glance
            // without having to drag to either end.
            HStack {
                Text(String(format: format, range.lowerBound))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.30))
                Spacer()
                Text(String(format: format, range.upperBound))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.30))
            }
        }
    }

    private func resetDefaults() {
        // Only the currently selected variant is reset — other variants
        // keep their settings so the user doesn't lose all their work.
        AirPodsTuningStore.reset(selectedVariant)
    }

    // MARK: Bindings into the active variant's tuning struct

    private var currentTuning: AirPodsTuning {
        tuningCenter.tuning(for: selectedVariant)
    }

    private func writeCurrentTuning(_ new: AirPodsTuning) {
        tuningCenter.write(new, for: selectedVariant)
    }

    private func tuneBinding(_ keyPath: WritableKeyPath<AirPodsTuning, Double>) -> Binding<Double> {
        Binding(
            get: { currentTuning[keyPath: keyPath] },
            set: { newValue in
                var t = currentTuning
                t[keyPath: keyPath] = newValue
                writeCurrentTuning(t)
            }
        )
    }

    private func tuneBindingBool(_ keyPath: WritableKeyPath<AirPodsTuning, Bool>) -> Binding<Bool> {
        Binding(
            get: { currentTuning[keyPath: keyPath] },
            set: { newValue in
                var t = currentTuning
                t[keyPath: keyPath] = newValue
                writeCurrentTuning(t)
            }
        )
    }

    private func variantDisplayName(_ v: AirPodsModelVariant) -> String {
        switch v {
        case .airPods:    return "AirPods"
        case .airPodsANC: return "AirPods 4 ANC"
        case .airPodsPro: return "AirPods Pro"
        case .airPodsMax: return "AirPods Max"
        }
    }
}

/// Thin wrapper so the Settings preview can show the expanded dashboard
/// with a forced variant + mock state regardless of what's connected.
private struct AirPodsDashboardPreviewWrapper: View {
    let variant: AirPodsModelVariant
    var body: some View {
        AirPodsDashboardView(
            override: AirPodsLiveActivity.mockState(for: variant)
        )
    }
}

// MARK: - Calendar settings panel

private struct NMCalendarPanel: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar

    var body: some View {
        VStack(spacing: 16) {
            NMCalendarDisplayCard()
            NMCalendarListCard()
            NMRemindersListCard()
            NMCalendarPreviewCard()
        }
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }
}

private struct NMCalendarDisplayCard: View {
    @Default(.showCalendar) private var showCalendar
    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.hideAllDayEvents) private var hideAllDayEvents
    @Default(.autoScrollToNextEvent) private var autoScrollToNextEvent
    @Default(.showFullEventTitles) private var showFullEventTitles

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Display", subtitle: "What appears on the calendar plate.")

            NMCalRow(title: "Show calendar",
                     subtitle: "Toggle the Calendar plate on the notch.",
                     isOn: $showCalendar)
            NMCalDivider()
            NMCalRow(title: "Hide completed reminders",
                     subtitle: "Drop checked-off reminders from the agenda.",
                     isOn: $hideCompletedReminders,
                     disabled: !showCalendar)
            NMCalDivider()
            NMCalRow(title: "Hide all-day events",
                     subtitle: "Skip events that span the full day.",
                     isOn: $hideAllDayEvents,
                     disabled: !showCalendar)
            NMCalDivider()
            NMCalRow(title: "Auto-scroll to next event",
                     subtitle: "Center the upcoming event when the notch opens.",
                     isOn: $autoScrollToNextEvent,
                     disabled: !showCalendar)
            NMCalDivider()
            NMCalRow(title: "Always show full event titles",
                     subtitle: "Wrap long titles instead of truncating.",
                     isOn: $showFullEventTitles,
                     disabled: !showCalendar)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMCalendarListCard: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                NMCardHeader(title: "Calendars", subtitle: "Sources used to build the agenda.")
                Spacer()
                NMAuthBadge(status: calendarManager.calendarAuthorizationStatus)
            }

            if calendarManager.calendarAuthorizationStatus != .fullAccess {
                NMPermissionPrompt(
                    message: "NotchMac needs Calendar access to show events on the notch.",
                    buttonTitle: "Open Calendar Settings",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                )
            } else if calendarManager.eventCalendars.isEmpty {
                NMEmptyHint(text: "No calendars found in this account.")
            } else {
                NMSourceList(
                    sources: calendarManager.eventCalendars,
                    isEnabled: showCalendar
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMRemindersListCard: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                NMCardHeader(title: "Reminders", subtitle: "Lists merged into the agenda.")
                Spacer()
                NMAuthBadge(status: calendarManager.reminderAuthorizationStatus)
            }

            if calendarManager.reminderAuthorizationStatus != .fullAccess {
                NMPermissionPrompt(
                    message: "NotchMac needs Reminders access to show lists on the notch.",
                    buttonTitle: "Open Reminder Settings",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                )
            } else if calendarManager.reminderLists.isEmpty {
                NMEmptyHint(text: "No reminder lists found.")
            } else {
                NMSourceList(
                    sources: calendarManager.reminderLists,
                    isEnabled: showCalendar
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMCalendarPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Preview", subtitle: "Snapshot of the agenda shown on the open notch.")
            NMCalendarMiniPreview()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

// MARK: Calendar helper rows

private struct NMCalRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var disabled: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(disabled ? 0.45 : 1))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(disabled ? 0.3 : 0.5))
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(.green)
                .disabled(disabled)
        }
    }
}

private struct NMCalDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.05))
            .frame(height: 0.6)
    }
}

private struct NMAuthBadge: View {
    let status: EKAuthorizationStatus

    var body: some View {
        switch status {
        case .fullAccess:
            NMBadge("Granted", color: .green)
        case .denied, .restricted:
            NMBadge("Denied", color: .red)
        case .writeOnly:
            NMBadge("Write Only", color: .orange)
        case .notDetermined:
            NMBadge("Requires Permission", color: .orange)
        @unknown default:
            NMBadge("Unknown", color: .orange)
        }
    }
}

private struct NMPermissionPrompt: View {
    let message: String
    let buttonTitle: String
    let settingsURL: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                if let url = URL(string: settingsURL) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label(buttonTitle, systemImage: "arrow.up.right.square")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.orange.opacity(0.22), lineWidth: 0.6)
                )
        )
    }
}

private struct NMEmptyHint: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .padding(.vertical, 8)
    }
}

private struct NMSourceList: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    let sources: [CalendarModel]
    let isEnabled: Bool

    private let rowHeight: CGFloat = 36
    private let maxVisibleRows: Int = 6

    var body: some View {
        let height = min(CGFloat(sources.count), CGFloat(maxVisibleRows)) * rowHeight
        ScrollView(showsIndicators: sources.count > maxVisibleRows) {
            VStack(spacing: 0) {
                ForEach(sources.indices, id: \.self) { idx in
                    let source = sources[idx]
                    NMSourceRow(source: source, isEnabled: isEnabled)
                        .frame(height: rowHeight)
                    if idx < sources.count - 1 {
                        NMCalDivider()
                    }
                }
            }
        }
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.05), lineWidth: 0.5)
                )
        )
    }
}

private struct NMSourceRow: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    let source: CalendarModel
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(source.color))
                .frame(width: 9, height: 9)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 0.5)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(source.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.45))
                    .lineLimit(1)
                if !source.account.isEmpty {
                    Text(source.account)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(isEnabled ? 0.45 : 0.25))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.green)
                .disabled(!isEnabled)
        }
        .padding(.horizontal, 12)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { calendarManager.getCalendarSelected(source) },
            set: { newValue in
                Task {
                    await calendarManager.setCalendarSelected(source, isSelected: newValue)
                }
            }
        )
    }
}

private struct NMCalendarMiniPreview: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) private var showCalendar
    @Default(.hideAllDayEvents) private var hideAllDayEvents
    @Default(.hideCompletedReminders) private var hideCompletedReminders
    @Default(.showFullEventTitles) private var showFullEventTitles

    private var previewEvents: [EventModel] {
        EventListView.filteredEvents(events: calendarManager.dashboardEvents)
    }

    var body: some View {
        VStack(spacing: 8) {
            if !showCalendar {
                Text("Calendar plate disabled.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if previewEvents.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .foregroundStyle(.white.opacity(0.55))
                    Text("No upcoming events.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                }
            } else {
                ForEach(previewEvents.prefix(4)) { event in
                    NMPreviewEventRow(event: event,
                                      showFullTitle: showFullEventTitles)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.6)
                )
        )
        .onAppear {
            Task { await calendarManager.updateDashboardEvents() }
        }
    }
}

private struct NMPreviewEventRow: View {
    let event: EventModel
    let showFullTitle: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color(event.calendar.color))
                .frame(width: 2.5)
                .cornerRadius(1.5)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(showFullTitle ? nil : 1)
                if event.isAllDay {
                    Text("All-day")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    Text(event.start, style: .time)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shelf settings panel

struct NMShelfPanel: View {
    var body: some View {
        VStack(spacing: 16) {
            NMShelfBehaviorCard()
            NMQuickShareCard()
            NMDropZonePreviewCard()
            NMShelfAppleIntelligenceCard()
        }
        .onAppear {
            Task { await QuickShareService.shared.discoverAvailableProviders() }
        }
    }
}

private struct NMShelfBehaviorCard: View {
    @Default(.boringShelf) private var enabled
    @Default(.openShelfByDefault) private var openByDefault
    @Default(.expandedDragDetection) private var expandedDrag
    @Default(.copyOnDrag) private var copyOnDrag
    @Default(.autoRemoveShelfItems) private var autoRemove

    var body: some View {
        NMSettingsCard(title: "Shelf Behavior") {
            NMPreferenceRow(
                title: "Enable shelf",
                subtitle: "Show the shelf plate and tab in the notch."
            ) {
                Toggle("", isOn: $enabled)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
            }

            NMPreferenceRow(
                title: "Open shelf by default if items are present",
                subtitle: "When items exist, expand straight into the shelf tab.",
                isEnabled: enabled
            ) {
                Toggle("", isOn: $openByDefault)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                    .disabled(!enabled)
            }

            NMPreferenceRow(
                title: "Expanded drag detection area",
                subtitle: "Enlarge the hit zone around the notch while dragging files.",
                isEnabled: enabled
            ) {
                Toggle("", isOn: $expandedDrag)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                    .disabled(!enabled)
            }
            .onChange(of: expandedDrag) { _, _ in
                NotificationCenter.default.post(name: .expandedDragDetectionChanged, object: nil)
            }

            NMPreferenceRow(
                title: "Copy items on drag",
                subtitle: "Drag a copy out of the shelf instead of moving the file.",
                isEnabled: enabled
            ) {
                Toggle("", isOn: $copyOnDrag)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                    .disabled(!enabled)
            }

            NMPreferenceRow(
                title: "Remove from shelf after dragging",
                subtitle: "Auto-clear an item once it leaves the shelf.",
                isEnabled: enabled
            ) {
                Toggle("", isOn: $autoRemove)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                    .disabled(!enabled)
            }
        }
    }
}

private struct NMQuickShareCard: View {
    @Default(.quickShareProvider) private var providerId
    @Default(.boringShelf) private var shelfEnabled
    @StateObject private var service = QuickShareService.shared
    @State private var refreshing = false

    private var selected: QuickShareProvider? {
        service.availableProviders.first(where: { $0.id == providerId })
    }

    var body: some View {
        NMSettingsCard(title: "Quick Share") {
            NMPreferenceRow(
                title: "Quick Share Service",
                subtitle: "Service used when sharing files from the shelf.",
                badge: service.availableProviders.isEmpty ? "Unavailable" : nil,
                isEnabled: shelfEnabled
            ) {
                Picker("", selection: $providerId) {
                    ForEach(service.availableProviders, id: \.id) { provider in
                        Text(provider.id).tag(provider.id)
                    }
                }
                .labelsHidden()
                .frame(width: 210)
                .disabled(!shelfEnabled || service.availableProviders.isEmpty)
            }

            if let provider = selected {
                HStack(spacing: 10) {
                    Group {
                        if let nsImg = service.icon(for: provider.id, size: 18) {
                            Image(nsImage: nsImg).resizable().aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(width: 18, height: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(provider.id)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Selected share destination")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Button {
                        refreshing = true
                        Task {
                            await service.discoverAvailableProviders()
                            await MainActor.run { refreshing = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if refreshing {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text("Refresh Services")
                                .font(.system(size: 11, weight: .semibold))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.045))
                )
                .padding(.vertical, 4)
            }
        }
    }
}

private struct NMDropZonePreviewCard: View {
    @Default(.quickShareProvider) private var providerId
    @StateObject private var service = QuickShareService.shared
    @State private var lastAction: String? = nil

    var body: some View {
        NMSettingsCard(title: "Drop Zone Preview") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    NMShelfChip(title: "PDF", systemImage: "doc.richtext", tint: .red)
                    NMShelfChip(title: "Image", systemImage: "photo", tint: .blue)
                    NMShelfChip(title: "Link", systemImage: "link", tint: .indigo)
                    NMShelfChip(title: "Text", systemImage: "text.alignleft", tint: .gray)
                    Spacer()
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(.white.opacity(0.18))
                        )
                )

                HStack(spacing: 10) {
                    Text(lastAction ?? "Sample shelf items. Click Share to preview the active provider.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Button {
                        let name = service.availableProviders.first(where: { $0.id == providerId })?.id ?? providerId
                        lastAction = "Would share via \(name)"
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 6)
        }
    }
}

private struct NMShelfChip: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(tint.opacity(0.14))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.25), lineWidth: 0.6)
        )
    }
}

private struct NMShelfAppleIntelligenceCard: View {
    @Default(.enableAppleIntelligenceShelf) private var enabled
    @Default(.boringShelf) private var shelfEnabled

    private var available: Bool { AppleIntelligenceManager.shared.isAvailable }

    var body: some View {
        NMSettingsCard(title: "Apple Intelligence") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.purple, .pink, .cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("PDF tile in shelf")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(shelfEnabled ? 0.92 : 0.4))
                        NMBadge("On-device", color: .purple)
                        if !available {
                            NMBadge("Unavailable", color: .orange)
                        }
                    }
                    Text("On-device PDF summary and chat.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    HStack(spacing: 5) {
                        Image(systemName: available ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(available ? Color.green : Color.orange)
                        Text(available
                             ? "Available on this Mac"
                             : "Unavailable, requires macOS 26 + Apple Intelligence")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                Toggle("", isOn: $enabled)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                    .disabled(!available || !shelfEnabled)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - AirPods Settings Panel

private struct NMAirPodsPanel: View {
    @ObservedObject private var manager = AirPodsManager.shared

    var body: some View {
        VStack(spacing: 16) {
            NMAirPodsActivityCard()
            NMAirPodsAlertsCard()
            NMAirPodsPreviewCard(manager: manager)
            NMAirPodsModelCard(manager: manager)
            if AirPodsModule.tuningPanelVisible {
                NMAirPodsDeveloperTuningCard()
            }
        }
    }
}

private struct NMAirPodsActivityCard: View {
    @Default(.enableAirPodsWidget)         private var enableWidget
    @Default(.airPodsShowConnectActivity)  private var showConnect
    @Default(.airPodsBatteryNotifications) private var notifications

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NMCardHeader(
                title: "AirPods Live Activity",
                subtitle: "Closed-notch plate, connect peek, and battery notifications."
            )
            .padding(.bottom, 6)

            NMAirPodsToggleRow(
                title: "Enable AirPods widget",
                subtitle: "Show the AirPods plate and tab on the notch.",
                isOn: $enableWidget,
                badges: ["Beta"]
            )
            NMAirPodsRowDivider()
            NMAirPodsToggleRow(
                title: "Show connect activity",
                subtitle: "Animate a sneak peek when AirPods connect.",
                isOn: $showConnect,
                disabled: !enableWidget
            )
            NMAirPodsRowDivider()
            NMAirPodsToggleRow(
                title: "Battery notifications",
                subtitle: "Send a notification when battery hits a threshold.",
                isOn: $notifications,
                disabled: !enableWidget,
                badges: ["Requires Permission"]
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMAirPodsAlertsCard: View {
    @Default(.enableAirPodsWidget)         private var enableWidget
    @Default(.airPodsBatteryNotifications) private var notifications
    @Default(.airPodsThresholdHigh)        private var high
    @Default(.airPodsThresholdLow)         private var low
    @Default(.airPodsThresholdCritical)    private var critical

    private var disabled: Bool { !enableWidget || !notifications }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NMCardHeader(
                title: "Battery Alerts",
                subtitle: "Levels at which NotchMac notifies you. Highest fires first."
            )
            .padding(.bottom, 6)

            NMAirPodsThresholdRow(
                title: "High",
                subtitle: "First reminder. Plenty left.",
                color: .green,
                value: highBinding,
                range: 30...80,
                disabled: disabled
            )
            NMAirPodsRowDivider()
            NMAirPodsThresholdRow(
                title: "Low",
                subtitle: "Second reminder. Plug in soon.",
                color: .orange,
                value: lowBinding,
                range: 10...40,
                disabled: disabled
            )
            NMAirPodsRowDivider()
            NMAirPodsThresholdRow(
                title: "Critical",
                subtitle: "Final reminder. Battery almost dead.",
                color: .red,
                value: criticalBinding,
                range: 3...20,
                disabled: disabled
            )

            HStack(spacing: 10) {
                NMAirPodsAlertSwatch(color: .green,  label: "\(high)%")
                NMAirPodsAlertSwatch(color: .orange, label: "\(low)%")
                NMAirPodsAlertSwatch(color: .red,    label: "\(critical)%")
                Spacer()
            }
            .padding(.top, 12)
            .opacity(disabled ? 0.4 : 1)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    // Clamp so High > Low > Critical at all times — avoids notification
    // reordering bugs without exposing extra UI.
    private var highBinding: Binding<Int> {
        Binding(get: { high }, set: { high = max($0, low + 5) })
    }
    private var lowBinding: Binding<Int> {
        Binding(get: { low }, set: { low = min(max($0, critical + 5), high - 5) })
    }
    private var criticalBinding: Binding<Int> {
        Binding(get: { critical }, set: { critical = min($0, low - 5) })
    }
}

private struct NMAirPodsPreviewCard: View {
    @ObservedObject var manager: AirPodsManager
    @Default(.airPodsDebugVariant) private var debugVariantRaw

    @State private var previewVM = BoringViewModel()

    private var selectedVariant: AirPodsModelVariant {
        if let s = manager.state { return s.variant }
        return AirPodsModelVariant(rawValue: debugVariantRaw) ?? .airPodsPro
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                NMCardHeader(
                    title: "Preview",
                    subtitle: "Live mini and dashboard using your active variant and tuning."
                )
                Spacer()
                NMAirPodsConnectionPill(connected: manager.state != nil,
                                        name: manager.state?.name)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CLOSED — LIVE ACTIVITY")
                    .font(.system(size: 9, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black)
                    AirPodsLiveActivity(
                        override: AirPodsLiveActivity.mockState(for: selectedVariant),
                        heightOverride: 32
                    )
                    .environmentObject(previewVM)
                }
                .frame(height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("OPEN — DASHBOARD")
                    .font(.system(size: 9, weight: .bold)).tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black)
                    AirPodsDashboardPreviewWrapper(variant: selectedVariant)
                        .environmentObject(previewVM)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMAirPodsModelCard: View {
    @ObservedObject var manager: AirPodsManager
    @Default(.airPodsDebugVariant) private var debugVariantRaw

    private var selectedVariant: AirPodsModelVariant {
        AirPodsModelVariant(rawValue: debugVariantRaw) ?? .airPodsPro
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(
                title: "Model",
                subtitle: "Variant used for the preview and the debug-always-show fallback. Auto-detected when AirPods are connected."
            )

            Picker("", selection: Binding(
                get: { selectedVariant },
                set: { debugVariantRaw = $0.rawValue }
            )) {
                Text("AirPods").tag(AirPodsModelVariant.airPods)
                Text("AirPods 4 ANC").tag(AirPodsModelVariant.airPodsANC)
                Text("AirPods Pro").tag(AirPodsModelVariant.airPodsPro)
                Text("AirPods Max").tag(AirPodsModelVariant.airPodsMax)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let detected = manager.state?.variant {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.mint)
                    Text("Connected: \(Self.variantDisplayName(detected)) — live values override this picker.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            if !AirPodsModule.tuningPanelVisible {
                Text("Advanced render tuning is hidden. Enable developer mode in code (AirPodsModule.tuningPanelVisible) to expose per-variant 3D knobs.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }

    static func variantDisplayName(_ v: AirPodsModelVariant) -> String {
        switch v {
        case .airPods:    return "AirPods"
        case .airPodsANC: return "AirPods 4 ANC"
        case .airPodsPro: return "AirPods Pro"
        case .airPodsMax: return "AirPods Max"
        }
    }
}

private struct NMAirPodsDeveloperTuningCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                Text("DEVELOPER TUNING")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(.orange)
                NMBadge("Debug", color: .orange)
                Spacer()
            }
            NMAirPodsDebugCard()
        }
    }
}

private struct NMAirPodsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var disabled: Bool = false
    var badges: [String] = []

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(disabled ? 0.4 : 0.95))
                    ForEach(badges, id: \.self) { NMBadge(text: $0) }
                }
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(disabled ? 0.25 : 0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 18)
            Toggle("", isOn: $isOn)
                .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
                .disabled(disabled)
        }
        .padding(.vertical, 10)
    }
}

private struct NMAirPodsThresholdRow: View {
    let title: String
    let subtitle: String
    let color: Color
    @Binding var value: Int
    let range: ClosedRange<Int>
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 22, height: 22)
                Circle().fill(color.opacity(disabled ? 0.35 : 0.9)).frame(width: 10, height: 10)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(disabled ? 0.4 : 0.95))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(disabled ? 0.25 : 0.5))
            }
            Spacer()
            Stepper(value: $value, in: range) {
                Text("\(value)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(disabled ? 0.4 : 0.95))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
            .controlSize(.small)
            .frame(width: 132)
            .disabled(disabled)
        }
        .padding(.vertical, 10)
    }
}

private struct NMAirPodsAlertSwatch: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(color.opacity(0.10))
                .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 0.6))
        )
    }
}

private struct NMAirPodsConnectionPill: View {
    let connected: Bool
    let name: String?
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? Color.green : Color.white.opacity(0.4))
                .frame(width: 7, height: 7)
            Text(connected ? (name ?? "Connected") : "Disconnected")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(connected ? 0.95 : 0.55))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill((connected ? Color.green : Color.white).opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke((connected ? Color.green : Color.white).opacity(0.22), lineWidth: 0.6)
                )
        )
    }
}

private struct NMAirPodsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
    }
}

// MARK: - Shortcuts panel

private struct NMShortcutsPanel: View {
    @State private var conflictMessage: String? = nil
    @State private var unregistrableMessage: String? = nil

    private let recordable: [KeyboardShortcuts.Name] = [
        .toggleSneakPeek,
        .toggleNotchOpen,
        .hideIsland
    ]

    private static let shortcutChangeNotification =
        Notification.Name("KeyboardShortcuts_shortcutByNameDidChange")

    var body: some View {
        VStack(spacing: 16) {
            mediaCard
            notchCard
            actionsCard
            conflictsCard
        }
        .onAppear(perform: refreshState)
        .onReceive(NotificationCenter.default.publisher(for: Self.shortcutChangeNotification)) { _ in
            refreshState()
        }
    }

    // MARK: Cards

    private var mediaCard: some View {
        NMSettingsCard(title: "Media") {
            NMShortcutRow(
                title: "Sneak Peek",
                subtitle: "Toggles the quick media glance under the closed notch.",
                name: .toggleSneakPeek
            )
        }
    }

    private var notchCard: some View {
        NMSettingsCard(title: "Notch") {
            NMShortcutRow(
                title: "Toggle Notch Open",
                subtitle: "Expands or collapses the notch from anywhere.",
                name: .toggleNotchOpen
            )
            NMShortcutsDivider()
            NMShortcutDisplayRow(
                title: "Manual Hide Island",
                subtitle: "Hide the live activity island instantly.",
                name: .hideIsland
            )
        }
    }

    private var actionsCard: some View {
        NMSettingsCard(title: "Actions") {
            NMShortcutActionRow(
                title: "Reset Shortcuts",
                subtitle: "Restore every recorded shortcut to its default.",
                buttonLabel: "Reset",
                role: .standard,
                action: resetAll
            )
            NMShortcutsDivider()
            NMShortcutActionRow(
                title: "Clear Shortcuts",
                subtitle: "Remove every recorded shortcut binding.",
                buttonLabel: "Clear",
                role: .destructive,
                action: clearAll
            )
        }
    }

    private var conflictsCard: some View {
        NMSettingsCard(title: "Conflicts") {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hasIssue ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(hasIssue ? Color.yellow : Color.green)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(hasIssue ? "Conflict detected" : "No conflicts detected")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        if hasIssue {
                            NMBadge(text: "FIX")
                        } else {
                            NMBadge(text: "OK")
                        }
                    }
                    if let detail = combinedDetailMessage {
                        Text(detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("All recorded shortcuts registered successfully.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
    }

    private var hasIssue: Bool {
        conflictMessage != nil || unregistrableMessage != nil
    }

    private var combinedDetailMessage: String? {
        [conflictMessage, unregistrableMessage]
            .compactMap { $0 }
            .joined(separator: "\n")
            .nilIfEmpty
    }

    // MARK: Actions

    private func resetAll() {
        KeyboardShortcuts.reset(recordable)
        refreshState()
    }

    private func clearAll() {
        for name in recordable {
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        refreshState()
    }

    private func refreshState() {
        var bucket: [String: [KeyboardShortcuts.Name]] = [:]

        for name in recordable {
            guard let shortcut = name.shortcut else { continue }
            let key = "\(shortcut.carbonKeyCode)|\(shortcut.modifiers.rawValue)"
            bucket[key, default: []].append(name)
        }

        let duplicates = bucket.values.filter { $0.count > 1 }
        if duplicates.isEmpty {
            conflictMessage = nil
        } else {
            let descriptions = duplicates.map { group in
                group.map(prettyTitle(for:)).joined(separator: " · ")
            }
            conflictMessage = "Same combination used by: " + descriptions.joined(separator: ", ") + "."
        }

        // Library does not expose a public "could not register" hook beyond
        // conflict detection. Surface for future wiring.
        unregistrableMessage = nil
    }

    private func prettyTitle(for name: KeyboardShortcuts.Name) -> String {
        switch name {
        case .toggleSneakPeek: return "Sneak Peek"
        case .toggleNotchOpen: return "Toggle Notch Open"
        case .hideIsland: return "Manual Hide Island"
        default: return name.rawValue
        }
    }
}

// MARK: - Shortcut row primitives

private struct NMShortcutRow: View {
    let title: String
    let subtitle: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            KeyboardShortcuts.Recorder(for: name)
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.vertical, 10)
    }
}

private struct NMShortcutDisplayRow: View {
    let title: String
    let subtitle: String
    let name: KeyboardShortcuts.Name

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            NMShortcutKeycaps(shortcut: name.shortcut)
        }
        .padding(.vertical, 10)
    }
}

private struct NMShortcutKeycaps: View {
    let shortcut: KeyboardShortcuts.Shortcut?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(modifierSymbols.enumerated()), id: \.offset) { _, symbol in
                NMKeyCap(label: symbol)
            }
            if let key = keySymbol {
                NMKeyCap(label: key)
            } else {
                NMKeyCap(label: "—", dimmed: true)
            }
        }
    }

    private var modifierSymbols: [String] {
        guard let modifiers = shortcut?.modifiers else { return [] }
        var symbols: [String] = []
        if modifiers.contains(.control) { symbols.append("⌃") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.command) { symbols.append("⌘") }
        return symbols
    }

    private var keySymbol: String? {
        guard let shortcut else { return nil }
        let raw = shortcut.description
        guard let last = raw.unicodeScalars.last else { return nil }
        return String(last).uppercased()
    }
}

private struct NMKeyCap: View {
    let label: String
    var dimmed: Bool = false

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(dimmed ? 0.35 : 0.88))
            .frame(minWidth: 22, minHeight: 22)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.6)
                    )
            )
    }
}

private struct NMShortcutActionRow: View {
    enum Role { case standard, destructive }

    let title: String
    let subtitle: String
    let buttonLabel: String
    let role: Role
    let action: () -> Void

    @State private var confirmingDestructive = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.46))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 16)
            Button(action: invoke) {
                Text(buttonLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(role == .destructive ? Color.red.opacity(0.18) : Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(
                                        (role == .destructive ? Color.red : Color.white).opacity(0.25),
                                        lineWidth: 0.6
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
            .confirmationDialog(
                "Clear all NotchMac shortcuts?",
                isPresented: $confirmingDestructive
            ) {
                Button("Clear", role: .destructive, action: action)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Recorded keyboard shortcuts will be removed. You can re-record them at any time.")
            }
        }
        .padding(.vertical, 10)
    }

    private func invoke() {
        if role == .destructive {
            confirmingDestructive = true
        } else {
            action()
        }
    }
}

private struct NMShortcutsDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.06))
            .frame(height: 1)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
