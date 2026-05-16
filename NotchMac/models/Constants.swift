//
//  Constants.swift
//  boringNotch
//
//  Created by Richard Kunkli on 2024. 10. 17..
//

import SwiftUI
import Defaults

private let availableDirectories = FileManager
    .default
    .urls(for: .documentDirectory, in: .userDomainMask)
let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let bundleIdentifier = Bundle.main.bundleIdentifier!
let appVersion = "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))"

let temporaryDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
let spacing: CGFloat = 16

struct CustomVisualizer: Codable, Hashable, Equatable, Defaults.Serializable {
    let UUID: UUID
    var name: String
    var url: URL
    var speed: CGFloat = 1.0
}

enum CalendarSelectionState: Codable, Defaults.Serializable {
    case all
    case selected(Set<String>)
}

enum HideNotchOption: String, Defaults.Serializable {
    case always
    case nowPlayingOnly
    case never
}

// Define notification names at file scope
extension Notification.Name {
    static let mediaControllerChanged = Notification.Name("mediaControllerChanged")
    static let nmAutoHideAppsChanged = Notification.Name("nmAutoHideAppsChanged")
}

// Media controller types for selection in settings
enum MediaControllerType: String, CaseIterable, Identifiable, Defaults.Serializable {
    case nowPlaying = "Now Playing"
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    
    var id: String { self.rawValue }
}

// Sneak peek styles for selection in settings
enum SneakPeekStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case standard = "Default"
    case inline = "Inline"

    var id: String { self.rawValue }
}

// Album art display options for the closed-notch music live activity
enum AlbumArtDisplayMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case always
    case fade
    case appIcon

    var id: String { self.rawValue }

    var localizedString: String {
        switch self {
        case .always:
            return NSLocalizedString("album_art_always", comment: "Album art display: Always show")
        case .fade:
            return NSLocalizedString("album_art_fade", comment: "Album art display: Fade after 3 seconds")
        case .appIcon:
            return NSLocalizedString("album_art_app_icon", comment: "Album art display: Show app icon")
        }
    }
}

// Action to perform when Option (⌥) is held while pressing media keys
enum OptionKeyAction: String, CaseIterable, Identifiable, Defaults.Serializable {
    case openSettings = "Open System Settings"
    case showHUD = "Show HUD"
    case none = "No Action"

    var id: String { self.rawValue }
}

extension Defaults.Keys {
    // MARK: General
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)
    static let automaticallySwitchDisplay = Key<Bool>("automaticallySwitchDisplay", default: true)
    static let releaseName = Key<String>("releaseName", default: "Flying Rabbit 🐇🪽")
    
    // MARK: Behavior
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.3)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let extendHoverArea = Key<Bool>("extendHoverArea", default: false)
    static let notchHeightMode = Key<WindowHeightMode>(
        "notchHeightMode",
        default: WindowHeightMode.matchRealNotchSize
    )
    static let nonNotchHeightMode = Key<WindowHeightMode>(
        "nonNotchHeightMode",
        default: WindowHeightMode.matchMenuBar
    )
    static let nonNotchHeight = Key<CGFloat>("nonNotchHeight", default: 32)
    static let notchHeight = Key<CGFloat>("notchHeight", default: 32)
    //static let openLastTabByDefault = Key<Bool>("openLastTabByDefault", default: false)
    static let showOnLockScreen = Key<Bool>("showOnLockScreen", default: false)
    static let hideFromScreenRecording = Key<Bool>("hideFromScreenRecording", default: false)
    
    // MARK: Appearance
    static let showEmojis = Key<Bool>("showEmojis", default: false)
    //static let alwaysShowTabs = Key<Bool>("alwaysShowTabs", default: true)
    static let showMirror = Key<Bool>("showMirror", default: false)
    static let mirrorShape = Key<MirrorShapeEnum>("mirrorShape", default: MirrorShapeEnum.rectangle)
    static let settingsIconInNotch = Key<Bool>("settingsIconInNotch", default: true)
    static let showCaffeinateButton = Key<Bool>("showCaffeinateButton", default: true)
    static let lightingEffect = Key<Bool>("lightingEffect", default: true)
    static let enableShadow = Key<Bool>("enableShadow", default: true)
    static let cornerRadiusScaling = Key<Bool>("cornerRadiusScaling", default: true)

    static let showNotHumanFace = Key<Bool>("showNotHumanFace", default: false)
    static let showCapsLockHUD = Key<Bool>("showCapsLockHUD", default: true)
    static let tileShowLabels = Key<Bool>("tileShowLabels", default: false)
    static let showCalendar = Key<Bool>("showCalendar", default: false)
    static let hideCompletedReminders = Key<Bool>("hideCompletedReminders", default: true)
    static let sliderColor = Key<SliderColorEnum>(
        "sliderUseAlbumArtColor",
        default: SliderColorEnum.white
    )
    static let playerColorTinting = Key<Bool>("playerColorTinting", default: true)
    static let useMusicVisualizer = Key<Bool>("useMusicVisualizer", default: true)
    static let customVisualizers = Key<[CustomVisualizer]>("customVisualizers", default: [])
    static let selectedVisualizer = Key<CustomVisualizer?>("selectedVisualizer", default: nil)
    
    // MARK: Gestures
    static let enableGestures = Key<Bool>("enableGestures", default: true)
    static let enableHorizontalMediaGestures = Key<Bool>("enableHorizontalMediaGestures", default: true)
    static let closeGestureEnabled = Key<Bool>("closeGestureEnabled", default: true)
    static let gestureSensitivity = Key<CGFloat>("gestureSensitivity", default: 200.0)
    
    // MARK: Media playback
    static let coloredSpectrogram = Key<Bool>("coloredSpectrogram", default: true)
    static let realtimeAudioWaveform = Key<Bool>("realtimeAudioWaveform", default: false)
    static let enableSneakPeek = Key<Bool>("enableSneakPeek", default: true)
    static let sneakPeekStyles = Key<SneakPeekStyle>("sneakPeekStyles", default: .standard)
    static let waitInterval = Key<Double>("waitInterval", default: 3)
    static let showShuffleAndRepeat = Key<Bool>("showShuffleAndRepeat", default: false)
    static let enableLyrics = Key<Bool>("enableLyrics", default: false)
    static let musicControlSlots = Key<[MusicControlButton]>(
        "musicControlSlots",
        default: MusicControlButton.defaultLayout
    )
    static let musicControlSlotLimit = Key<Int>(
        "musicControlSlotLimit",
        default: MusicControlButton.defaultLayout.count
    )
    static let albumArtDisplayMode = Key<AlbumArtDisplayMode>(
        "albumArtDisplayMode",
        default: .always
    )
    static let liveActivityAlbumArtSize = Key<CGFloat>(
        "nm.liveActivity.albumArtSize",
        default: 1.0
    )
    static let liveActivityAlbumArtCornerRadius = Key<CGFloat>(
        "nm.liveActivity.albumArtCornerRadius",
        default: 1.0
    )
    static let liveActivityAlbumArtShadow = Key<Bool>(
        "nm.liveActivity.albumArtShadow",
        default: false
    )


    // MARK: NotchMac modules (mockup parity)
    static let showMusicModule = Key<Bool>("nm.module.music", default: true)
    static let showTimerModule = Key<Bool>("nm.module.timer", default: true)
    static let pomodoroFocusMinutes = Key<Int>("nm.pomodoro.focusMinutes", default: 25)
    static let pomodoroBreakMinutes = Key<Int>("nm.pomodoro.breakMinutes", default: 5)
    /// Legacy switch kept for migration; superseded by `pomodoroIndicatorStyle`.
    static let pomodoroNotchRing = Key<Bool>("nm.pomodoro.notchRing", default: true)
    /// Visual style for an active Pomodoro session on the closed notch. Default `.dot` para que
    /// el indicador aparezca automáticamente junto a los tabs cuando hay una sesión activa.
    static let pomodoroIndicatorStyle = Key<PomodoroIndicatorStyle>("nm.pomodoro.indicatorStyle", default: .dot)

    // MARK: Ref-design dashboard (mockup-style expanded view)
    static let nmDashboardRefDesign = Key<Bool>("nm.dashboard.refDesign", default: true)
    static let nmShowMenuBarIcon = Key<Bool>("nm.menuBar.showIcon", default: true)
    static let nmIslandHidden = Key<Bool>("nm.island.hidden", default: false)
    static let nmAutoHideAppBundleIDs = Key<[String]>("nm.island.autoHideApps", default: [])

    // MARK: AirPods
    static let enableAirPodsWidget = Key<Bool>("nm.airpods.enabled", default: true)
    static let airPodsBatteryNotifications = Key<Bool>("nm.airpods.notifications", default: true)
    static let airPodsThresholdHigh = Key<Int>("nm.airpods.threshold.high", default: 50)
    static let airPodsThresholdLow = Key<Int>("nm.airpods.threshold.low", default: 20)
    static let airPodsThresholdCritical = Key<Int>("nm.airpods.threshold.critical", default: 10)
    static let airPodsShowConnectActivity = Key<Bool>("nm.airpods.connectActivity", default: true)

    // MARK: AirPods debug + live-tune
    /// Forces the closed-notch live activity to render at all times, even
    /// without AirPods connected (uses fake battery values). Lets the user
    /// iterate on visuals without unpairing/repairing the buds.
    static let airPodsDebugAlwaysShow = Key<Bool>("nm.airpods.debug.alwaysShow", default: false)
    /// Live-tunable layout. Defaults match the prior hard-coded values.
    static let airPodsArtWidthMultiplier = Key<Double>("nm.airpods.tune.artWidthMul", default: 1.9)
    static let airPodsArtSidePadding = Key<Double>("nm.airpods.tune.artSidePad", default: 10.0)
    static let airPodsArtLeftShift = Key<Double>("nm.airpods.tune.artLeftShift", default: -14.0)
    static let airPodsModelZoom = Key<Double>("nm.airpods.tune.modelZoom", default: 0.85)
    static let airPodsRingDiameter = Key<Double>("nm.airpods.tune.ringDiameter", default: 22.0)
    static let airPodsRingStrokeWidth = Key<Double>("nm.airpods.tune.ringStroke", default: 3.0)
    static let airPodsRingSidePadding = Key<Double>("nm.airpods.tune.ringSidePad", default: 14.0)
    static let airPodsRingTextScale = Key<Double>("nm.airpods.tune.ringTextScale", default: 0.42)

    // 3D render tuning — applies to the closed-notch mini view (tightCrop).
    /// Forward/backward tilt of the model in degrees. 0 = upright.
    static let airPodsModelTiltX = Key<Double>("nm.airpods.tune.tiltX", default: 0.0)
    /// Vertical offset applied to the pivot inside the SCNView (scene units).
    static let airPodsModelYShift = Key<Double>("nm.airpods.tune.yShift", default: 0.0)
    /// Camera distance along Z. Higher = model appears smaller.
    static let airPodsCameraZ = Key<Double>("nm.airpods.tune.cameraZ", default: 3.2)
    /// Camera vertical position. Higher = looks down at the model.
    static let airPodsCameraY = Key<Double>("nm.airpods.tune.cameraY", default: 0.05)
    /// Camera field of view (degrees). Lower = telephoto, higher = wide.
    static let airPodsCameraFOV = Key<Double>("nm.airpods.tune.cameraFOV", default: 28.0)
    /// Seconds per full rotation. Lower = spins faster.
    static let airPodsRotationSeconds = Key<Double>("nm.airpods.tune.rotSeconds", default: 5.0)
    /// Reverse rotation direction (counter-clockwise when viewed from above).
    static let airPodsRotationReversed = Key<Bool>("nm.airpods.tune.rotReversed", default: false)
    /// Disable the case filter entirely → renders the whole imported model.
    static let airPodsShowFullModel = Key<Bool>("nm.airpods.tune.showFullModel", default: false)
    /// Lower Y cut for the case filter (0…1 of bbox height). Geometry below
    /// this line is treated as case-territory.
    static let airPodsFilterPositionCut = Key<Double>("nm.airpods.tune.filterPosCut", default: 0.50)
    /// Horizontal footprint fraction above which a mesh is treated as case.
    static let airPodsFilterAreaCut = Key<Double>("nm.airpods.tune.filterAreaCut", default: 0.30)
    /// Filter strictness. `true` = drop if mesh is bulky OR sits below the
    /// Y line (catches the LED + metal hinge bar). `false` = needs both.
    static let airPodsFilterStrict = Key<Bool>("nm.airpods.tune.filterStrict", default: true)
    /// Which AirPods variant the debug preview + the always-show fallback
    /// render. Mirrors AirPodsModelVariant.rawValue.
    static let airPodsDebugVariant = Key<String>("nm.airpods.debug.variant", default: "airPodsPro")
    /// Multiplier applied to the chin height for the 3D tile.
    static let airPodsTileHeightMul = Key<Double>("nm.airpods.tune.tileHeightMul", default: 1.0)

    // MARK: Battery
    static let showPowerStatusNotifications = Key<Bool>("showPowerStatusNotifications", default: true)
    static let showBatteryIndicator = Key<Bool>("showBatteryIndicator", default: true)
    static let showBatteryPercentage = Key<Bool>("showBatteryPercentage", default: true)
    static let showPowerStatusIcons = Key<Bool>("showPowerStatusIcons", default: true)
    
    // MARK: Downloads
    static let enableDownloadListener = Key<Bool>("enableDownloadListener", default: true)
    static let enableSafariDownloads = Key<Bool>("enableSafariDownloads", default: true)
    static let selectedDownloadIndicatorStyle = Key<DownloadIndicatorStyle>("selectedDownloadIndicatorStyle", default: DownloadIndicatorStyle.progress)
    static let selectedDownloadIconStyle = Key<DownloadIconStyle>("selectedDownloadIconStyle", default: DownloadIconStyle.onlyAppIcon)
    
    // MARK: HUD
    static let hudReplacement = Key<Bool>("hudReplacement", default: false)
    static let inlineHUD = Key<Bool>("inlineHUD", default: false)
    static let enableGradient = Key<Bool>("enableGradient", default: false)
    static let systemEventIndicatorShadow = Key<Bool>("systemEventIndicatorShadow", default: false)
    static let systemEventIndicatorUseAccent = Key<Bool>("systemEventIndicatorUseAccent", default: false)
    static let showOpenNotchHUD = Key<Bool>("showOpenNotchHUD", default: true)
    static let showOpenNotchHUDPercentage = Key<Bool>("showOpenNotchHUDPercentage", default: true)
    static let showClosedNotchHUDPercentage = Key<Bool>("showClosedNotchHUDPercentage", default: false)
    // Option key modifier behaviour for media keys
    static let optionKeyAction = Key<OptionKeyAction>("optionKeyAction", default: OptionKeyAction.openSettings)
    
    // MARK: Shelf
    static let boringShelf = Key<Bool>("boringShelf", default: true)
    static let openShelfByDefault = Key<Bool>("openShelfByDefault", default: true)
    static let shelfTapToOpen = Key<Bool>("shelfTapToOpen", default: true)
    static let quickShareProvider = Key<String>("quickShareProvider", default: QuickShareProvider.defaultProvider.id)
    static let copyOnDrag = Key<Bool>("copyOnDrag", default: false)
    static let autoRemoveShelfItems = Key<Bool>("autoRemoveShelfItems", default: false)
    static let expandedDragDetection = Key<Bool>("expandedDragDetection", default: true)
    
    // MARK: Calendar
    static let calendarSelectionState = Key<CalendarSelectionState>("calendarSelectionState", default: .all)
    static let hideAllDayEvents = Key<Bool>("hideAllDayEvents", default: false)
    static let showFullEventTitles = Key<Bool>("showFullEventTitles", default: false)
    static let autoScrollToNextEvent = Key<Bool>("autoScrollToNextEvent", default: true)
    static let calendarPermissionPrompted = Key<Bool>("nm.calendar.permissionPrompted", default: false)
    static let reminderPermissionPrompted = Key<Bool>("nm.reminders.permissionPrompted", default: false)
    
    // MARK: Fullscreen Media Detection
    static let hideNotchOption = Key<HideNotchOption>("hideNotchOption", default: .always)
    
    // MARK: Media Controller
    static let mediaController = Key<MediaControllerType>("mediaController", default: defaultMediaController)
    
    // MARK: Advanced Settings
    static let useCustomAccentColor = Key<Bool>("useCustomAccentColor", default: false)
    static let customAccentColorData = Key<Data?>("customAccentColorData", default: nil)
    // Show or hide the title bar
    static let hideTitleBar = Key<Bool>("hideTitleBar", default: true)
    
    // Helper to determine the default media controller based on NowPlaying deprecation status
    static var defaultMediaController: MediaControllerType {
        if MusicManager.shared.isNowPlayingDeprecated {
            return .appleMusic
        } else {
            return .nowPlaying
        }
    }

    static let didClearLegacyURLCacheV1 = Key<Bool>("didClearLegacyURLCache_v1", default: false)
}
