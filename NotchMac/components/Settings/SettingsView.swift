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

struct Charge: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBatteryIndicator) {
                    Text("Show battery indicator")
                }
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("General")
            }
            Section {
                Defaults.Toggle(key: .showBatteryPercentage) {
                    Text("Show battery percentage")
                }
                Defaults.Toggle(key: .showPowerStatusIcons) {
                    Text("Show power status icons")
                }
            } header: {
                Text("Battery Information")
            }
        }
        .onAppear {
            Task { @MainActor in
                await XPCHelperClient.shared.isAccessibilityAuthorized()
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Battery")
    }
}

struct HUD: View {
    @EnvironmentObject var vm: BoringViewModel
    @Default(.inlineHUD) var inlineHUD
    @Default(.enableGradient) var enableGradient
    @Default(.optionKeyAction) var optionKeyAction
    @Default(.hudReplacement) var hudReplacement
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @State private var accessibilityAuthorized = false
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replace system HUD")
                            .font(.headline)
                        Text("Replaces the standard macOS volume, display brightness, and keyboard brightness HUDs with a custom design.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 40)
                    Defaults.Toggle("", key: .hudReplacement)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.large)
                    .disabled(!accessibilityAuthorized)
                }
                
                if !accessibilityAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Accessibility access is required to replace the system HUD.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button("Request Accessibility") {
                                XPCHelperClient.shared.requestAccessibilityAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            
            Section {
                Picker("Option key behaviour", selection: $optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                
                Picker("Progress bar style", selection: $enableGradient) {
                    Text("Hierarchical")
                        .tag(false)
                    Text("Gradient")
                        .tag(true)
                }
                Defaults.Toggle(key: .systemEventIndicatorShadow) {
                    Text("Enable glowing effect")
                }
                Defaults.Toggle(key: .systemEventIndicatorUseAccent) {
                    Text("Tint progress bar with accent color")
                }
            } header: {
                Text("General")
            }
            .disabled(!hudReplacement)
            
            Section {
                Defaults.Toggle(key: .showOpenNotchHUD) {
                    Text("Show HUD in open notch")
                }
                Defaults.Toggle(key: .showOpenNotchHUDPercentage) {
                    Text("Show percentage")
                }
                .disabled(!Defaults[.showOpenNotchHUD])
            } header: {
                HStack {
                    Text("Open Notch")
                    customBadge(text: "Beta")
                }
            }
            .disabled(!hudReplacement)
            
            Section {
                Picker("HUD style", selection: $inlineHUD) {
                    Text("Default")
                        .tag(false)
                    Text("Inline")
                        .tag(true)
                }
                .onChange(of: Defaults[.inlineHUD]) {
                    if Defaults[.inlineHUD] {
                        withAnimation {
                            Defaults[.systemEventIndicatorShadow] = false
                            Defaults[.enableGradient] = false
                        }
                    }
                }
                
                Defaults.Toggle(key: .showClosedNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Closed Notch")
            }
            .disabled(!Defaults[.hudReplacement])

            Section {
                Defaults.Toggle(key: .showCapsLockHUD) {
                    Text("Show Caps Lock indicator in notch")
                }
            } header: {
                Text("Caps Lock")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("HUDs")
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek
    @Default(.sneakPeekStyles) var sneakPeekStyles
    @Default(.albumArtDisplayMode) var albumArtDisplayMode
    @Default(.liveActivityAlbumArtSize) var liveActivityAlbumArtSize
    @Default(.liveActivityAlbumArtCornerRadius) var liveActivityAlbumArtCornerRadius
    @Default(.liveActivityAlbumArtShadow) var liveActivityAlbumArtShadow

    @Default(.enableLyrics) var enableLyrics

    private var realtimeAudioWaveformSupported: Bool {
        if #available(macOS 14.2, *) { return true }
        return false
    }

    var body: some View {
        Form {
            Section {
                Picker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link(
                            "https://github.com/pear-devs/pear-desktop",
                            destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                        )
                        .font(.caption)
                        .foregroundColor(.blue)  // Ensures it's visibly a link
                    }
                } else {
                    Text(
                        "'Now Playing' was the only option on previous versions and works with all media apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Show music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                Toggle("Show sneak peek on playback changes", isOn: $enableSneakPeek)
                Picker("Sneak Peek Style", selection: $sneakPeekStyles) {
                    ForEach(SneakPeekStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Picker(
                    selection: $hideNotchOption,
                    label:
                        HStack {
                            Text("Full screen behavior")
                            customBadge(text: "Beta")
                        }
                ) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for media app only").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Media playback live activity")
            }

            Section {
                Picker("Album art display", selection: $albumArtDisplayMode) {
                    ForEach(AlbumArtDisplayMode.allCases) { mode in
                        Text(mode.localizedString).tag(mode)
                    }
                }
                HStack {
                    Text("Album art size")
                    Spacer()
                    Text(String(format: "%.2fx", liveActivityAlbumArtSize))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $liveActivityAlbumArtSize, in: 0.5...1.5, step: 0.05)
                HStack {
                    Text("Album art corner radius")
                    Spacer()
                    Text(String(format: "%.2fx", liveActivityAlbumArtCornerRadius))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $liveActivityAlbumArtCornerRadius, in: 0.0...2.0, step: 0.05)
                Toggle("Drop shadow on album art", isOn: $liveActivityAlbumArtShadow)
            } header: {
                Text("Album art")
            } footer: {
                Text("Size and corner radius are multipliers applied to the closed-notch base values. Fade hides the artwork after 3 seconds of inactivity; App icon swaps to the source media app icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                MusicSlotConfigurationView()
                Defaults.Toggle(key: .enableLyrics) {
                    HStack {
                        Text("Show lyrics below artist name")
                        customBadge(text: "Beta")
                    }
                }
            } header: {
                Text("Media controls")
            }  footer: {
                Text("Customize which controls appear in the music player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Defaults.Toggle(key: .realtimeAudioWaveform) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Real-time audio waveform")
                        Group {
                            if realtimeAudioWaveformSupported {
                                Text("Uses Accelerate FFT on the playing app's audio. Requires audio capture permission and uses slightly more CPU.")
                            } else {
                                Text("Requires macOS 14.2 or later. Update macOS to enable real-time audio waveform.")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .disabled(!realtimeAudioWaveformSupported)
            } header: {
                Text("Visualizer")
            } footer: {
                Text("When disabled, the visualizer animates randomly. The FFT mode reacts to the system audio of the currently playing app — no external audio driver required.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Media")
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

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.showCalendar) var showCalendar: Bool
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent

    var body: some View {
        Form {
            Defaults.Toggle(key: .showCalendar) {
                Text("Show calendar")
            }
            Defaults.Toggle(key: .hideCompletedReminders) {
                Text("Hide completed reminders")
            }
            Defaults.Toggle(key: .hideAllDayEvents) {
                Text("Hide all-day events")
            }
            Defaults.Toggle(key: .autoScrollToNextEvent) {
                Text("Auto-scroll to next event")
            }
            Defaults.Toggle(key: .showFullEventTitles) {
                Text("Always show full event titles")
            }
            Section(header: Text("Calendars")) {
                if calendarManager.calendarAuthorizationStatus != .fullAccess {
                    Text("Calendar access is denied. Please enable it in System Settings.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Calendar Settings") {
                        if let settingsURL = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                        ) {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.eventCalendars, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                            .disabled(!showCalendar)
                        }
                    }
                }
            }
            Section(header: Text("Reminders")) {
                if calendarManager.reminderAuthorizationStatus != .fullAccess {
                    Text("Reminder access is denied. Please enable it in System Settings.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Reminder Settings") {
                        if let settingsURL = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                        ) {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.reminderLists, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                            .disabled(!showCalendar)
                        }
                    }
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }
}

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
    
    @Default(.shelfTapToOpen) var shelfTapToOpen: Bool
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection: Bool
    @StateObject private var quickShareService = QuickShareService.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }
    
    init() {
        Task { await QuickShareService.shared.discoverAvailableProviders() }
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .boringShelf) {
                    Text("Enable shelf")
                }
                Defaults.Toggle(key: .openShelfByDefault) {
                    Text("Open shelf by default if items are present")
                }
                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .onChange(of: expandedDragDetection) {
                    NotificationCenter.default.post(
                        name: Notification.Name.expandedDragDetectionChanged,
                        object: nil
                    )
                }
                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }

            } header: {
                HStack {
                    Text("General")
                }
            }
            
            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            Group {
                                if let nsImg = quickShareService.icon(for: provider.id, size: 16) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)

                if let selectedProvider = selectedProvider {
                    HStack {
                        Group {
                            if let nsImg = quickShareService.icon(for: selectedProvider.id, size: 16) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // Providers are always enabled; user can pick default service above.
                
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Click the shelf button to select files, or drag files onto it to share immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
    }
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

struct Shortcuts: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Toggle Sneak Peek:", name: .toggleSneakPeek)
            } header: {
                Text("Media")
            } footer: {
                Text(
                    "Sneak Peek shows the media title and artist under the notch for a few seconds."
                )
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .font(.caption)
            }
            Section {
                KeyboardShortcuts.Recorder("Toggle Notch Open:", name: .toggleNotchOpen)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shortcuts")
    }
}

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
    }
    enum TopTab: String, CaseIterable {
        case settings = "Settings"
        case modules = "Modules"
        case about = "About"
        var systemImage: String {
            switch self {
            case .settings: return "gearshape.fill"
            case .modules: return "square.grid.2x2.fill"
            case .about: return "info.circle"
            }
        }
    }

    let updaterController: SPUStandardUpdaterController?

    @State private var selectedItem: SidebarItem = .general
    @State private var selectedTab: TopTab = .settings

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
                    VStack(spacing: 18) {
                        Group {
                            switch selectedTab {
                            case .settings:
                                settingsContent
                            case .modules:
                                NMModulesCard()
                                NMPomodoroSettingsCard()
                                if AirPodsModule.visible {
                                    NMAirPodsDebugCard()
                                }
                                NMAlbumArtCard()
                            case .about:
                                NMAboutPanel(updaterController: updaterController)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .padding(.bottom, 28)
                    }
                }
            }
            .frame(minWidth: 820, maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.85))
        }
        .frame(minWidth: 1100, minHeight: 760)
        .preferredColorScheme(.dark)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            NMSidebarItem(
                title: "General",
                systemImage: "gearshape.fill",
                isSelected: selectedItem == .general,
                action: { selectedItem = .general }
            )
            .padding(.horizontal, 14)
            .padding(.top, 22)
            .padding(.bottom, 18)

            NMSidebarSection(title: "MODULES")
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                NMSidebarToggle(title: "Music", systemImage: "music.note", key: .showMusicModule, pair: .showCalendar)
                NMSidebarToggle(title: "Shelf", systemImage: "tray.full.fill", key: .boringShelf)
                NMSidebarToggle(title: "Calendar", systemImage: "calendar", key: .showCalendar, pair: .showMusicModule)
                NMSidebarToggle(title: "Battery", systemImage: "battery.100", key: .showBatteryIndicator)
                NMSidebarToggle(title: "Timer / Pomodoro", systemImage: "timer", key: .showTimerModule)
                if AirPodsModule.visible {
                    NMSidebarToggle(title: "AirPods", systemImage: "airpods", key: .enableAirPodsWidget)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("NotchMac v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                HStack(spacing: 3) {
                    Text("Made with")
                    Image(systemName: "heart.fill").foregroundStyle(.red.opacity(0.7))
                    Text("for macOS")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notch Utility")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                ForEach(TopTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 11, weight: .semibold))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(.white.opacity(selectedTab == tab ? 0.12 : 0))
                        )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    // MARK: Main settings content

    private var settingsContent: some View {
        VStack(spacing: 18) {
            switch selectedItem {
            case .general:
                NMLivePreviewCard()
                LazyVGrid(columns: twoColumnGrid, spacing: 16) {
                    NMBehaviorCard()
                    NMAutoHideAppsCard()
                }
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

private struct NMSidebarToggle: View {
    let title: String
    let systemImage: String
    let key: Defaults.Key<Bool>
    /// If set, turning this toggle OFF while the paired key is also OFF will auto-enable the pair
    /// (mutual fallback). Used to guarantee at least one of music/calendar stays visible.
    var pair: Defaults.Key<Bool>? = nil
    @Default(.showMusicModule) private var musicOn
    @Default(.showCalendar) private var calendarOn

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { Defaults[key] },
            set: { newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    Defaults[key] = newValue
                    if let pair, newValue == false, Defaults[pair] == false {
                        Defaults[pair] = true
                    }
                }
            }
        )
    }
}

// MARK: - Live preview

private struct NMLivePreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live Preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                Spacer()
                NMNotchMockup()
                Spacer()
            }

            Text("This is how your notch will look with the current settings.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(NMCardBG())
    }
}

private struct NMNotchMockup: View {
    @Default(.showMusicModule) private var showMusicModule
    @Default(.showCalendar) private var showCalendar
    @Default(.showTimerModule) private var showTimerModule
    @Default(.boringShelf) private var showShelf
    @Default(.showBatteryIndicator) private var showBattery
    @Default(.pomodoroIndicatorStyle) private var pomodoroIndicator
    @ObservedObject private var session = FocusSessionModel.shared
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var batteryModel = BatteryStatusViewModel.shared

    var body: some View {
        HStack(spacing: 14) {
            if showMusicModule { musicSection }
            if !showMusicModule && !showCalendar && !showTimerModule && !showShelf {
                emptyMessage
            }
            Spacer(minLength: 8)
            if showTimerModule { timerSection }
            if showShelf { shelfBadge }
            if showCalendar { calendarSection }
            if showBattery { batteryBadge }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 880, minHeight: 86)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            pomodoroIndicator == .ring && session.isRunning
                                ? Color.yellow.opacity(0.9)
                                : .white.opacity(0.08),
                            lineWidth: pomodoroIndicator == .ring && session.isRunning ? 2 : 0.8
                        )
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

    private var shelfBadge: some View {
        Image(systemName: "tray.full.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.blue.opacity(0.85))
    }

    private var calendarSection: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.red.opacity(0.85))
            Text(shortDate)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
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
    }

    private var emptyMessage: some View {
        Text("Enable a module to preview it here.")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: Date())
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
            NMCardHeader(title: "Modules", subtitle: "Enable or disable modules to show in your notch.")

            VStack(spacing: 10) {
                NMModuleRow(title: "Music", subtitle: "Show playback controls and track info", systemImage: "music.note", tint: .pink, key: .showMusicModule)
                NMModuleRow(title: "Shelf", subtitle: "Quick access to your files and docs", systemImage: "tray.full.fill", tint: .blue, key: .boringShelf)
                NMModuleRow(title: "Calendar", subtitle: "Upcoming events and agenda", systemImage: "calendar", tint: .red, key: .showCalendar)
                NMModuleRow(title: "Battery", subtitle: "Show battery status and charging", systemImage: "battery.100", tint: .green, key: .showBatteryIndicator)
                NMModuleRow(title: "Timer / Pomodoro", subtitle: "Countdown timer and focus sessions", systemImage: "timer", tint: .orange, key: .showTimerModule)
                if AirPodsModule.visible {
                    NMModuleRow(title: "AirPods", subtitle: "Live activity 3D + battery alerts", systemImage: "airpods", tint: .mint, key: .enableAirPodsWidget)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMPomodoroSettingsCard: View {
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroBreakMinutes) private var breakMinutes
    @Default(.pomodoroIndicatorStyle) private var indicatorStyle
    @ObservedObject private var session = FocusSessionModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: "Pomodoro", subtitle: "Configure the timer shown in the notch.")

            NMStepperRow(
                title: "Focus Session",
                subtitle: "Main countdown duration",
                value: $focusMinutes,
                range: 1...180,
                suffix: "min"
            )
            NMStepperRow(
                title: "Break",
                subtitle: "Short reset duration",
                value: $breakMinutes,
                range: 1...60,
                suffix: "min"
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Notch Indicator")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Choose how an active session appears on the closed notch.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Picker("", selection: $indicatorStyle) {
                    ForEach(PomodoroIndicatorStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            Button {
                session.resetToFocusDuration()
            } label: {
                Label("Apply to Current Timer", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
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

private struct NMModuleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: SwiftUI.Color
    let key: Defaults.Key<Bool>

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.9))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )

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

private struct NMBehaviorCard: View {
    @Default(.openNotchOnHover) var openOnHover
    @Default(.enableGestures) var enableGestures
    @Default(.closeGestureEnabled) var closeGesture
    @Default(.enableHaptics) var enableHaptics
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    @Default(.hideTitleBar) var hideTitleBar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Behavior", subtitle: "Control how the notch opens, hides, and reacts.")

            NMSwitchRow(title: "Open on Hover", subtitle: "Expand the notch when the pointer rests on it", isOn: $openOnHover)
            NMSwitchRow(title: "Gestures", subtitle: "Use drag gestures to open and close the notch", isOn: $enableGestures)
            NMSwitchRow(title: "Close Gesture", subtitle: "Allow the upward drag gesture to collapse the notch", isOn: $closeGesture)
                .opacity(enableGestures ? 1 : 0.45)
                .disabled(!enableGestures)
            NMSwitchRow(title: "Haptics", subtitle: "Play subtle feedback on notch interactions", isOn: $enableHaptics)
            NMSwitchRow(title: "Lock Screen", subtitle: "Keep the notch visible while the screen is locked", isOn: $showOnLockScreen)
            NMSwitchRow(title: "Screen Recording", subtitle: "Hide the notch from screen capture when possible", isOn: $hideFromScreenRecording)
            NMSwitchRow(title: "Hide Title Bar", subtitle: "Keep the notch window visually clean", isOn: $hideTitleBar)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMAutoHideAppsCard: View {
    @Default(.nmAutoHideAppBundleIDs) var autoHideBundleIDs
    @State private var runningApps: [NMAppChoice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Auto-hide Apps", subtitle: "Hide the notch when selected apps are active.")

            VStack(alignment: .leading, spacing: 8) {
                Text("Apps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                ForEach(availableApps.prefix(7)) { app in
                    NMAppToggleRow(
                        app: app,
                        isActive: app.bundleID == NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
                        isOn: Binding(
                            get: { autoHideBundleIDs.contains(app.bundleID) },
                            set: { enabled in
                                if enabled {
                                    add(app.bundleID)
                                } else {
                                    remove(app.bundleID)
                                }
                            }
                        )
                    )
                }

                if availableApps.isEmpty {
                    Text("Open an app or choose one manually.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Button {
                pickApp()
            } label: {
                Label("Choose App", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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

    private var availableApps: [NMAppChoice] {
        (runningApps + autoHideBundleIDs.map { NMAppChoice(bundleID: $0) })
            .uniquedByBundleID()
            .sorted { lhs, rhs in
                let lhsSelected = autoHideBundleIDs.contains(lhs.bundleID)
                let rhsSelected = autoHideBundleIDs.contains(rhs.bundleID)
                if lhsSelected != rhsSelected { return lhsSelected && !rhsSelected }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            NMCardHeader(title: "About NotchMac", subtitle: "Personal fork of boring.notch (GPL-3.0).")
            Text("Original by TheBoredTeam. Rebrand y personalizaciones por @fabiannavarrofonte.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
            Text("Version \(appVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            if let updater = updaterController?.updater {
                NMUpdateRow(updater: updater)
            }

            HStack {
                Link("Original repo", destination: URL(string: "https://github.com/TheBoredTeam/boring.notch")!)
                Spacer()
                Link("This fork", destination: URL(string: "https://github.com/fabiannavarroo/Notch-Mac-v2")!)
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
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
