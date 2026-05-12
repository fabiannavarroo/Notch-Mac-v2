//
//  SettingsView.swift
//  boringNotch
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI
import SwiftUIIntrospect
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selectedTab = "General"
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

    private var legacyBody: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                NavigationLink(value: "General") {
                    Label("General", systemImage: "gear")
                }
                NavigationLink(value: "Appearance") {
                    Label("Appearance", systemImage: "eye")
                }
                NavigationLink(value: "Media") {
                    Label("Media", systemImage: "play.laptopcomputer")
                }
                NavigationLink(value: "Calendar") {
                    Label("Calendar", systemImage: "calendar")
                }
                NavigationLink(value: "HUD") {
                    Label("HUDs", systemImage: "dial.medium.fill")
                }
                NavigationLink(value: "Battery") {
                    Label("Battery", systemImage: "battery.100.bolt")
                }
//                NavigationLink(value: "Downloads") {
//                    Label("Downloads", systemImage: "square.and.arrow.down")
//                }
                NavigationLink(value: "Shelf") {
                    Label("Shelf", systemImage: "books.vertical")
                }
                NavigationLink(value: "Shortcuts") {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                // NavigationLink(value: "Extensions") {
                //     Label("Extensions", systemImage: "puzzlepiece.extension")
                // }
                NavigationLink(value: "Advanced") {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                NavigationLink(value: "About") {
                    Label("About", systemImage: "info.circle")
                }
            }
            .listStyle(SidebarListStyle())
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(200)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Appearance":
                    Appearance()
                case "Media":
                    Media()
                case "Calendar":
                    CalendarSettings()
                case "HUD":
                    HUD()
                case "Battery":
                    Charge()
                case "Shelf":
                    Shelf()
                case "Shortcuts":
                    Shortcuts()
                case "Extensions":
                    GeneralSettings()
                case "Advanced":
                    Advanced()
                case "About":
                    if let controller = updaterController {
                        About(updaterController: controller)
                    } else {
                        // Fallback with a default controller
                        About(
                            updaterController: SPUStandardUpdaterController(
                                startingUpdater: false, updaterDelegate: nil,
                                userDriverDelegate: nil))
                    }
                default:
                    GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(.effectiveAccent)
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
                Toggle("Change media with horizontal gestures", isOn: .constant(false))
                    .disabled(true)
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

//struct Downloads: View {
//    @Default(.selectedDownloadIndicatorStyle) var selectedDownloadIndicatorStyle
//    @Default(.selectedDownloadIconStyle) var selectedDownloadIconStyle
//    var body: some View {
//        Form {
//            warningBadge("We don't support downloads yet", "It will be supported later on.")
//            Section {
//                Defaults.Toggle(key: .enableDownloadListener) {
//                    Text("Show download progress")
//                }
//                    .disabled(true)
//                Defaults.Toggle(key: .enableSafariDownloads) {
//                    Text("Enable Safari Downloads")
//                }
//                    .disabled(!Defaults[.enableDownloadListener])
//                Picker("Download indicator style", selection: $selectedDownloadIndicatorStyle) {
//                    Text("Progress bar")
//                        .tag(DownloadIndicatorStyle.progress)
//                    Text("Percentage")
//                        .tag(DownloadIndicatorStyle.percentage)
//                }
//                Picker("Download icon style", selection: $selectedDownloadIconStyle) {
//                    Text("Only app icon")
//                        .tag(DownloadIconStyle.onlyAppIcon)
//                    Text("Only download icon")
//                        .tag(DownloadIconStyle.onlyIcon)
//                    Text("Both")
//                        .tag(DownloadIconStyle.iconAndAppIcon)
//                }
//
//            } header: {
//                HStack {
//                    Text("Download indicators")
//                    comingSoonTag()
//                }
//            }
//            Section {
//                List {
//                    ForEach([].indices, id: \.self) { index in
//                        Text("\(index)")
//                    }
//                }
//                .frame(minHeight: 96)
//                .overlay {
//                    if true {
//                        Text("No excluded apps")
//                            .foregroundStyle(Color(.secondaryLabelColor))
//                    }
//                }
//                .actionBar(padding: 0) {
//                    Group {
//                        Button {
//                        } label: {
//                            Image(systemName: "plus")
//                                .frame(width: 25, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//
//                        Divider()
//                        Button {
//                        } label: {
//                            Image(systemName: "minus")
//                                .frame(width: 20, height: 16, alignment: .center)
//                                .contentShape(Rectangle())
//                                .foregroundStyle(.secondary)
//                        }
//                    }
//                }
//            } header: {
//                HStack(spacing: 4) {
//                    Text("Exclude apps")
//                    comingSoonTag()
//                }
//            }
//        }
//        .navigationTitle("Downloads")
//    }
//}

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

    @Default(.enableLyrics) var enableLyrics

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
                                if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
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
                            if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
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

struct Appearance: View {
    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @Default(.mirrorShape) var mirrorShape
    @Default(.sliderColor) var sliderColor
    @Default(.useMusicVisualizer) var useMusicVisualizer
    @Default(.customVisualizers) var customVisualizers
    @Default(.selectedVisualizer) var selectedVisualizer

    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    @State private var selectedListVisualizer: CustomVisualizer? = nil
    @State private var isPresented: Bool = false
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var speed: CGFloat = 1.0
    var body: some View {
        Form {
            Section {
                Toggle("Always show tabs", isOn: $coordinator.alwaysShowTabs)
                Defaults.Toggle(key: .settingsIconInNotch) {
                    Text("Show settings icon in notch")
                }

            } header: {
                Text("General")
            }

            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults
                    .Toggle("Player tinting", key: .playerColorTinting)
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
                Picker("Slider color", selection: $sliderColor) {
                    ForEach(SliderColorEnum.allCases, id: \.self) { option in
                        Text(option.rawValue)
                    }
                }
            } header: {
                Text("Media")
            }

            Section {
                Toggle(
                    "Use music visualizer spectrogram",
                    isOn: $useMusicVisualizer.animation()
                )
                .disabled(true)
                if !useMusicVisualizer {
                    if customVisualizers.count > 0 {
                        Picker(
                            "Selected animation",
                            selection: $selectedVisualizer
                        ) {
                            ForEach(
                                customVisualizers,
                                id: \.self
                            ) { visualizer in
                                Text(visualizer.name)
                                    .tag(visualizer)
                            }
                        }
                    } else {
                        HStack {
                            Text("Selected animation")
                            Spacer()
                            Text("No custom animation available")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Custom music live activity animation")
                    customBadge(text: "Coming soon")
                }
            }

            Section {
                List {
                    ForEach(customVisualizers, id: \.self) { visualizer in
                        HStack {
                            LottieView(
                                url: visualizer.url, speed: visualizer.speed,
                                loopMode: .loop
                            )
                            .frame(width: 30, height: 30, alignment: .center)
                            Text(visualizer.name)
                            Spacer(minLength: 0)
                            if selectedVisualizer == visualizer {
                                Text("selected")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.vertical, 2)
                        .background(
                            selectedListVisualizer != nil
                                ? selectedListVisualizer == visualizer
                                    ? Color.effectiveAccent : Color.clear : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedListVisualizer == visualizer {
                                selectedListVisualizer = nil
                                return
                            }
                            selectedListVisualizer = visualizer
                        }
                    }
                }
                .safeAreaPadding(
                    EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0)
                )
                .frame(minHeight: 120)
                .actionBar {
                    HStack(spacing: 5) {
                        Button {
                            name = ""
                            url = ""
                            speed = 1.0
                            isPresented.toggle()
                        } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                        Divider()
                        Button {
                            if selectedListVisualizer != nil {
                                let visualizer = selectedListVisualizer!
                                selectedListVisualizer = nil
                                customVisualizers.remove(
                                    at: customVisualizers.firstIndex(of: visualizer)!)
                                if visualizer == selectedVisualizer && customVisualizers.count > 0 {
                                    selectedVisualizer = customVisualizers[0]
                                }
                            }
                        } label: {
                            Image(systemName: "minus")
                                .foregroundStyle(.secondary)
                                .contentShape(Rectangle())
                        }
                    }
                }
                .controlSize(.small)
                .buttonStyle(PlainButtonStyle())
                .overlay {
                    if customVisualizers.isEmpty {
                        Text("No custom visualizer")
                            .foregroundStyle(Color(.secondaryLabelColor))
                            .padding(.bottom, 22)
                    }
                }
                .sheet(isPresented: $isPresented) {
                    VStack(alignment: .leading) {
                        Text("Add new visualizer")
                            .font(.largeTitle.bold())
                            .padding(.vertical)
                        TextField("Name", text: $name)
                        TextField("Lottie JSON URL", text: $url)
                        HStack {
                            Text("Speed")
                            Spacer(minLength: 80)
                            Text("\(speed, specifier: "%.1f")s")
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                            Slider(value: $speed, in: 0...2, step: 0.1)
                        }
                        .padding(.vertical)
                        HStack {
                            Button {
                                isPresented.toggle()
                            } label: {
                                Text("Cancel")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            Button {
                                let visualizer: CustomVisualizer = .init(
                                    UUID: UUID(),
                                    name: name,
                                    url: URL(string: url)!,
                                    speed: speed
                                )

                                if !customVisualizers.contains(visualizer) {
                                    customVisualizers.append(visualizer)
                                }

                                isPresented.toggle()
                            } label: {
                                Text("Add")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .controlSize(.extraLarge)
                    .padding()
                }
            } header: {
                HStack(spacing: 0) {
                    Text("Custom vizualizers (Lottie)")
                    if !Defaults[.customVisualizers].isEmpty {
                        Text(" – \(Defaults[.customVisualizers].count)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Defaults.Toggle(key: .showMirror) {
                    Text("Enable boring mirror")
                }
                    .disabled(!checkVideoInput())
                Picker("Mirror shape", selection: $mirrorShape) {
                    Text("Circle")
                        .tag(MirrorShapeEnum.circle)
                    Text("Square")
                        .tag(MirrorShapeEnum.rectangle)
                }
                Defaults.Toggle(key: .showNotHumanFace) {
                    Text("Show cool face animation while inactive")
                }
            } header: {
                HStack {
                    Text("Additional features")
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Appearance")
    }

    func checkVideoInput() -> Bool {
        if AVCaptureDevice.default(for: .video) != nil {
            return true
        }

        return false
    }
}

struct Advanced: View {
    @Default(.useCustomAccentColor) var useCustomAccentColor
    @Default(.customAccentColorData) var customAccentColorData
    @Default(.extendHoverArea) var extendHoverArea
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    
    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor? = nil
    let icons: [String] = ["logo2"]
    @State private var selectedIcon: String = "logo2"
    
    // macOS accent colors
    enum PresetAccentColor: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case graphite = "Graphite"
        
        var id: String { self.rawValue }
        
        var color: Color {
            switch self {
            case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
            case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .pink: return Color(red: 1.0, green: 0.176, blue: 0.333)
            case .red: return Color(red: 1.0, green: 0.271, blue: 0.227)
            case .orange: return Color(red: 1.0, green: 0.584, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
            case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
            case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle between system and custom
                    Picker("Accent color", selection: $useCustomAccentColor) {
                        Text("System").tag(false)
                        Text("Custom").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if !useCustomAccentColor {
                        // System accent info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                AccentCircleButton(
                                    isSelected: true,
                                    color: .accentColor,
                                    isSystemDefault: true
                                ) {}
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Using System Accent")
                                        .font(.body)
                                    Text("Your macOS system accent color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Custom color options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color Presets")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(PresetAccentColor.allCases) { preset in
                                    AccentCircleButton(
                                        isSelected: selectedPresetColor == preset,
                                        color: preset.color,
                                        isMulticolor: false
                                    ) {
                                        selectedPresetColor = preset
                                        customAccentColor = preset.color
                                        saveCustomColor(preset.color)
                                        forceUiUpdate()
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Custom color picker
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pick a Color")
                                        .font(.body)
                                    Text("Choose any color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                ColorPicker(selection: Binding(
                                    get: { customAccentColor },
                                    set: { newColor in
                                        customAccentColor = newColor
                                        selectedPresetColor = nil
                                        saveCustomColor(newColor)
                                        forceUiUpdate()
                                    }
                                ), supportsOpacity: false) {
                                    ZStack {
                                        Circle()
                                            .fill(customAccentColor)
                                            .frame(width: 32, height: 32)
                                        
                                        if selectedPresetColor == nil {
                                            Circle()
                                                .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent color")
            } footer: {
                Text("Choose between your system accent color or customize it with your own selection.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .onAppear {
                initializeAccentColorState()
            }
            
            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable window shadow")
                }
                Defaults.Toggle(key: .cornerRadiusScaling) {
                    Text("Corner radius scaling")
                }
            } header: {
                Text("Window Appearance")
            }
            
            Section {
                HStack {
                    ForEach(icons, id: \.self) { icon in
                        Spacer()
                        VStack {
                            Image(icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .circular)
                                        .strokeBorder(
                                            icon == selectedIcon ? Color.effectiveAccent : .clear,
                                            lineWidth: 2.5
                                        )
                                )

                            Text("Default")
                                .fontWeight(.medium)
                                .font(.caption)
                                .foregroundStyle(icon == selectedIcon ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(icon == selectedIcon ? Color.effectiveAccent : .clear)
                                )
                        }
                        .onTapGesture {
                            withAnimation {
                                selectedIcon = icon
                            }
                            NSApp.applicationIconImage = NSImage(named: icon)
                        }
                        Spacer()
                    }
                }
                .disabled(true)
            } header: {
                HStack {
                    Text("App icon")
                    customBadge(text: "Coming soon")
                }
            }
            
            Section {
                Defaults.Toggle(key: .extendHoverArea) {
                    Text("Extend hover area")
                }
                Defaults.Toggle(key: .hideTitleBar) {
                    Text("Hide title bar")
                }
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show notch on lock screen")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
            } header: {
                Text("Window Behavior")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
        .onAppear {
            loadCustomColor()
        }
    }
    
    private func forceUiUpdate() {
        // Force refresh the UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("AccentColorChanged"), object: nil)
        }
    }
    
    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            Defaults[.customAccentColorData] = colorData
            forceUiUpdate()
        }
    }
    
    private func loadCustomColor() {
        if let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            customAccentColor = Color(nsColor: nsColor)
            
            // Check if loaded color matches a preset
            selectedPresetColor = nil
            for preset in PresetAccentColor.allCases {
                if colorsAreEqual(Color(nsColor: nsColor), preset.color) {
                    selectedPresetColor = preset
                    break
                }
            }
        }
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1).usingColorSpace(.sRGB) ?? NSColor(color1)
        let nsColor2 = NSColor(color2).usingColorSpace(.sRGB) ?? NSColor(color2)
        
        return abs(nsColor1.redComponent - nsColor2.redComponent) < 0.01 &&
               abs(nsColor1.greenComponent - nsColor2.greenComponent) < 0.01 &&
               abs(nsColor1.blueComponent - nsColor2.blueComponent) < 0.01
    }
    
    private func initializeAccentColorState() {
        if !useCustomAccentColor {
            selectedPresetColor = nil // Multicolor is selected when useCustomAccentColor is false
        } else {
            loadCustomColor()
        }
    }
}

// MARK: - Accent Circle Button Component
struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    var isMulticolor: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Color circle
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                // Subtle border
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                // Apple-style highlight ring around the middle when selected
                if isSelected {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}

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

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4).stroke(
                Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
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
        case general, layout, appearance, accentColor, iconStyle, spacing, reducedMode, shortcuts, advanced
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
                NMSidebarToggle(title: "Music", systemImage: "music.note", key: .showMusicModule)
                NMSidebarToggle(title: "Shelf", systemImage: "tray.full.fill", key: .boringShelf)
                NMSidebarToggle(title: "Calendar", systemImage: "calendar", key: .showCalendar)
                NMSidebarToggle(title: "Battery", systemImage: "battery.100", key: .showBatteryIndicator)
                NMSidebarToggle(title: "Timer / Pomodoro", systemImage: "timer", key: .showTimerModule)
                NMSidebarToggle(title: "Clipboard", systemImage: "doc.on.clipboard", key: .showClipboardModule)
                NMSidebarToggle(title: "Quick Actions", systemImage: "bolt.fill", key: .showQuickActionsModule)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)

            NMSidebarSection(title: "CUSTOMIZATION")
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                NMSidebarItem(title: "Layout", systemImage: "square.grid.3x3", isSelected: selectedItem == .layout) { selectedItem = .layout }
                NMSidebarItem(title: "Appearance", systemImage: "paintbrush", isSelected: selectedItem == .appearance) { selectedItem = .appearance }
                NMSidebarItem(title: "Accent Color", systemImage: "paintpalette", isSelected: selectedItem == .accentColor) { selectedItem = .accentColor }
                NMSidebarItem(title: "Icon Style", systemImage: "app.fill", isSelected: selectedItem == .iconStyle) { selectedItem = .iconStyle }
                NMSidebarItem(title: "Spacing", systemImage: "arrow.left.and.right", isSelected: selectedItem == .spacing) { selectedItem = .spacing }
                NMSidebarItem(title: "Reduced Mode", systemImage: "moon.zzz.fill", isSelected: selectedItem == .reducedMode) { selectedItem = .reducedMode }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)

            NMSidebarSection(title: "SYSTEM")
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                NMSidebarItem(title: "Shortcuts", systemImage: "command", isSelected: selectedItem == .shortcuts) { selectedItem = .shortcuts }
                NMSidebarItem(title: "Advanced", systemImage: "wrench.and.screwdriver", isSelected: selectedItem == .advanced) { selectedItem = .advanced }
            }
            .padding(.horizontal, 14)

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

    // MARK: Main settings content (3x2 cards)

    private var settingsContent: some View {
        VStack(spacing: 18) {
            NMLivePreviewCard()

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                NMModulesCard()
                NMLayoutCard()
                NMAppearanceCard()
                NMBehaviorCard()
                NMAutoHideAppsCard()
                NMShortcutsCard()
                NMReducedModeCard()
            }
        }
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

    @Default(.showMusicModule) private var _placeholder // ignored, just for re-render
    @State private var value: Bool = true

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
            Toggle("", isOn: Binding(
                get: { Defaults[key] },
                set: { Defaults[key] = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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
    var body: some View {
        HStack(spacing: 16) {
            // Artwork
            ZStack {
                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                Text("🌅")
                    .font(.system(size: 26))
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("AIRBNB")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Text("Mora")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer(minLength: 30)

            HStack(spacing: 18) {
                Image(systemName: "backward.fill")
                Image(systemName: "pause.fill").font(.system(size: 14))
                Image(systemName: "forward.fill")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)

            Spacer(minLength: 12)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("may")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("2026")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 8) {
                    ForEach(["sáb","dom","lun","mar","mié","jue"], id: \.self) { d in
                        let isLun = d == "lun"
                        VStack(spacing: 3) {
                            Text(d)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.55))
                            Text(d == "sáb" ? "09" : d == "dom" ? "10" : d == "lun" ? "11" : d == "mar" ? "12" : d == "mié" ? "13" : "14")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isLun ? .white : .white.opacity(0.7))
                                .padding(5)
                                .background(
                                    Circle().fill(isLun ? Color.blue : Color.clear)
                                )
                        }
                    }
                }
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: 880)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.8)
                )
        )
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
                NMModuleRow(title: "Clipboard", subtitle: "Quick clipboard history access", systemImage: "doc.on.clipboard", tint: .indigo, key: .showClipboardModule)
                NMModuleRow(title: "Quick Actions", subtitle: "Custom actions and shortcuts", systemImage: "bolt.fill", tint: .purple, key: .showQuickActionsModule)
            }

            Button("Manage Modules…") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
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
            Toggle("", isOn: Binding(
                get: { Defaults[key] },
                set: { Defaults[key] = $0 }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .tint(.green)
        }
    }
}

private struct NMLayoutCard: View {
    @Default(.nmModuleOrder) var order
    @Default(.nmModuleSpacing) var spacing
    @Default(.nmVerticalAlignment) var vAlign
    @Default(.nmCompactMode) var compact

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Layout", subtitle: "Arrange and size your notch modules.")

            HStack {
                Text("Order")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Picker("", selection: $order) {
                    ForEach(NMModuleOrder.allCases, id: \.self) { o in
                        Text(o.displayName).tag(o)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Module Spacing")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Picker("", selection: $spacing) {
                    ForEach(NMSpacing.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            HStack {
                Text("Vertical Alignment")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Picker("", selection: $vAlign) {
                    Image(systemName: "arrow.up.to.line").tag(NMVerticalAlignment.top)
                    Image(systemName: "arrow.up.and.down").tag(NMVerticalAlignment.center)
                    Image(systemName: "arrow.down.to.line").tag(NMVerticalAlignment.bottom)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 120)
            }

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Compact Mode")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Reduce padding for more content")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Toggle("", isOn: $compact)
                    .labelsHidden().toggleStyle(.switch).controlSize(.small).tint(.green)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMAppearanceCard: View {
    @Default(.useCustomAccentColor) var useCustom
    @Default(.customAccentColorData) var accentData
    @Default(.nmBackgroundStyle) var bg
    @Default(.nmIconStyle) var iconStyle

    private let palette: [NSColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemBlue, .systemIndigo, .systemPurple, .systemGray
    ]

    private var currentColor: NSColor? {
        guard useCustom, let data = accentData,
              let c = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return c
    }

    private func setAccent(_ color: NSColor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            accentData = data
            useCustom = true
            NotificationCenter.default.post(name: NSNotification.Name("AccentColorChanged"), object: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Appearance", subtitle: "Customize the look and feel.")

            VStack(alignment: .leading, spacing: 6) {
                Text("Accent Color")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 8) {
                    ForEach(palette, id: \.self) { c in
                        let color = SwiftUI.Color(c)
                        let isCurrent = currentColor.map { $0.isEqual(c) } ?? false
                        Button { setAccent(c) } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle().stroke(.white, lineWidth: isCurrent ? 2 : 0)
                                        .padding(-2)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Background")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Picker("", selection: $bg) {
                    ForEach(NMBackgroundStyle.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented).labelsHidden()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon Style")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Picker("", selection: $iconStyle) {
                    Text("Filled").tag(NMIconStyle.filled)
                    Text("Outline").tag(NMIconStyle.outline)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMBehaviorCard: View {
    @Default(.nmShowOnNotch) var showOnNotch
    @Default(.nmPlaySounds) var playSounds
    @Default(.nmShowBanners) var showBanners
    @Default(.nmReducedMode) var reducedMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NMCardHeader(title: "Behavior", subtitle: "Configure how Notch Utility behaves.")

            NMSwitchRow(title: "Show on Notch", subtitle: "Display modules in the notch area", isOn: $showOnNotch)
            NMSwitchRow(title: "Play Sounds", subtitle: "Play notification sounds", isOn: $playSounds)
            NMSwitchRow(title: "Show Banners", subtitle: "Show notifications as banners", isOn: $showBanners)
            NMSwitchRow(title: "Reduced Mode", subtitle: "Simplify UI in Low Power Mode", isOn: $reducedMode)
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

            VStack(spacing: 10) {
                ForEach(selectedApps) { app in
                    NMAppRow(app: app) {
                        remove(app.bundleID)
                    }
                }

                if selectedApps.isEmpty {
                    Text("No apps selected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Divider().opacity(0.12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Running Apps")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                ForEach(runningApps.prefix(5)) { app in
                    NMAppToggleRow(
                        app: app,
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
            }

            HStack(spacing: 8) {
                Button {
                    addFrontmostApp()
                } label: {
                    Label("Add Active", systemImage: "plus.circle")
                }

                Button {
                    pickApp()
                } label: {
                    Label("Choose App", systemImage: "folder")
                }

                Button {
                    refreshRunningApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh running apps")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
        .onAppear(perform: refreshRunningApps)
    }

    private var selectedApps: [NMAppChoice] {
        autoHideBundleIDs
            .map { NMAppChoice(bundleID: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func addFrontmostApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        add(bundleID)
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
        runningApps = NSWorkspace.shared.runningApplications
            .compactMap { app -> NMAppChoice? in
                guard let bundleID = app.bundleIdentifier,
                      bundleID != Bundle.main.bundleIdentifier else { return nil }
                return NMAppChoice(bundleID: bundleID, fallbackName: app.localizedName)
            }
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

private struct NMAppRow: View {
    let app: NMAppChoice
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(app.bundleID)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct NMAppToggleRow: View {
    let app: NMAppChoice
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

private struct NMShortcutsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NMCardHeader(title: "Shortcuts", subtitle: "Customize keyboard shortcuts.")

            NMShortcutRow(label: "Show / Hide Notch", keys: ["⌥","⌘","N"])
            NMShortcutRow(label: "Next Module", keys: ["⌥","⌘","→"])
            NMShortcutRow(label: "Previous Module", keys: ["⌥","⌘","←"])
            NMShortcutRow(label: "Open Settings", keys: ["⌘",","])

            Button("Restore Defaults") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
    }
}

private struct NMShortcutRow: View {
    let label: String
    let keys: [String]
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    Text(k)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .padding(.horizontal, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(.white.opacity(0.1))
                        )
                }
            }
        }
    }
}

private struct NMReducedModeCard: View {
    @Default(.nmReducedMode) var reducedMode
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NMCardHeader(title: "Reduced Mode", subtitle: "Lighter UI for Low Power Mode.")
            HStack {
                Image(systemName: "moon.zzz.fill").foregroundStyle(.indigo)
                Text("Activate reduced UI automatically when battery is low.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            Toggle("Enabled", isOn: $reducedMode)
                .toggleStyle(.switch).controlSize(.small).tint(.green)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NMCardBG())
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
