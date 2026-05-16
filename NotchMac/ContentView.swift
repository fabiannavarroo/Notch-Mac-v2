//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @ObservedObject var capsLockManager = CapsLockManager.shared
    @ObservedObject var airPodsManager = AirPodsManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero
    @State private var horizontalMediaGestureTriggered = false
    @State private var horizontalMediaGestureFeedback: CGFloat = .zero
    @State private var isHoveringMusicArea = false

    @State private var haptics: Bool = false

    @State private var albumArtOpacity: Double = 1.0
    @State private var albumArtFadeTask: Task<Void, Never>?

    @State private var capsLockHUDVisible: Bool = false
    @State private var capsLockHUDDismissTask: Task<Void, Never>?

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer

    @Default(.showNotHumanFace) var showNotHumanFace
    @Default(.albumArtDisplayMode) var albumArtDisplayMode
    @Default(.liveActivityAlbumArtSize) var liveActivityAlbumArtSize
    @Default(.liveActivityAlbumArtCornerRadius) var liveActivityAlbumArtCornerRadius
    @Default(.liveActivityAlbumArtShadow) var liveActivityAlbumArtShadow
    @Default(.showMusicModule) var showMusicModule
    @Default(.showTimerModule) var showTimerModule
    @Default(.boringShelf) var showShelfModule
    @Default(.showCalendar) var showCalendarModule
    @Default(.showBatteryIndicator) var showBatteryModule
    @Default(.pomodoroIndicatorStyle) var pomodoroIndicatorStyle
    @ObservedObject private var focusSession = FocusSessionModel.shared
    @State private var moduleRenderID = UUID()

    // Shared interactive spring for movement/resizing to avoid conflicting animations
    private let animationSpring = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    // Copia exacta de upstream/boring.notch (con `cornerRadiusScaling`)
    private var topCornerRadius: CGFloat {
        ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
            ? cornerRadiusInsets.opened.top
            : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var horizontalCornerInset: CGFloat {
        vm.notchState == .open
            ? (Defaults[.cornerRadiusScaling] ? cornerRadiusInsets.opened.top : cornerRadiusInsets.opened.bottom)
            : cornerRadiusInsets.closed.bottom
    }

    private var pomodoroRingActive: Bool {
        pomodoroIndicatorStyle == .ring && showTimerModule && focusSession.isRunning && focusSession.remainingFraction > 0
    }

    private var pomodoroDotActive: Bool {
        pomodoroIndicatorStyle == .dot && showTimerModule && focusSession.isRunning && focusSession.remainingFraction > 0
    }

    private var currentNotchOpenBorderShape: NotchOpenBorderShape {
        NotchOpenBorderShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: vm.notchState == .open
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if vm.notchState == .closed && !vm.hideOnClosed
            && Defaults[.enableAirPodsWidget]
            && airPodsManager.showSneakActivity
            && airPodsManager.state != nil
        {
            // AirPods activity uses wider 3D + ring tiles than music does,
            // so the chin needs proportionally more horizontal room.
            let slot = max(0, vm.effectiveClosedNotchHeight - 4)
            let artWidth = slot * 1.4
            let ringWidth = (slot - 4) + 12
            chinWidth += (artWidth + ringWidth + 24)
        } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music)
            && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled && showMusicModule && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace]
            && !vm.hideOnClosed
        {
            chinWidth += (2 * max(0, vm.effectiveClosedNotchHeight - 12) + 20)
        }

        return chinWidth
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .id(moduleRenderID)
                    .frame(
                        height: vm.notchState == .open ? openNotchSize.height - 12 : nil,
                        alignment: .top
                    )
                    .padding(
                        .horizontal,
                        horizontalCornerInset
                    )
                    .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentNotchShape)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(.black)
                            .frame(height: 1)
                            .padding(.horizontal, topCornerRadius)
                    }
                    .overlay {
                        if pomodoroRingActive {
                            currentNotchOpenBorderShape
                                .trim(from: 0, to: CGFloat(focusSession.remainingFraction))
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 1.00, green: 0.78, blue: 0.20),
                                            Color(red: 1.00, green: 0.48, blue: 0.20),
                                            Color(red: 1.00, green: 0.30, blue: 0.40)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                                )
                                .animation(.linear(duration: 0.18), value: focusSession.remainingFraction)
                                .allowsHitTesting(false)
                        }
                    }
                    .shadow(
                        color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: Defaults[.cornerRadiusScaling] ? 6 : 4
                    )
                    .padding(
                        .bottom,
                        vm.effectiveClosedNotchHeight == 0 ? 10 : 0
                    )
                
                mainLayout
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
                        let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
                        
                        return view
                            .animation(vm.notchState == .open ? openAnimation : closeAnimation, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.enableHorizontalMediaGestures] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .left) { translation, phase in
                                handleNextTrackGesture(translation: translation, phase: phase)
                            }
                            .panGesture(direction: .right) { translation, phase in
                                handlePreviousTrackGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive && !vm.isAudioPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !self.vm.isAudioPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.isAudioPopoverActive) {
                        if !vm.isAudioPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isAudioPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .contextMenu {
                        Button("Settings") {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .scaleEffect(
            x: vm.isPerformingHideAnimation ? 0.01 : 1.0,
            y: vm.isPerformingHideAnimation ? 0.01 : 1.0,
            anchor: .top
        )
        .animation(.spring(response: 0.3, dampingFraction: 1.0, blendDuration: 0), value: vm.isPerformingHideAnimation)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
        .onChange(of: showTimerModule) { _, enabled in
            if !enabled && coordinator.currentView == .focus {
                coordinator.currentView = .home
            }
            refreshModuleLayout()
        }
        .onChange(of: showShelfModule) { _, enabled in
            if !enabled && coordinator.currentView == .shelf {
                coordinator.currentView = .home
            }
            refreshModuleLayout()
        }
        .onChange(of: showMusicModule) { _, enabled in
            if !enabled {
                if coordinator.sneakPeek.type == .music {
                    coordinator.sneakPeek.show = false
                }
                if coordinator.expandingView.type == .music {
                    coordinator.expandingView.show = false
                }
            }
            refreshModuleLayout()
        }
        .onChange(of: showCalendarModule) {
            refreshModuleLayout()
        }
        .onChange(of: showBatteryModule) {
            refreshModuleLayout()
        }
        .onReceive(capsLockManager.pulse) { _ in
            showCapsLockHUD()
        }
    }

    private func showCapsLockHUD() {
        guard Defaults[.showCapsLockHUD] else { return }
        capsLockHUDDismissTask?.cancel()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
            capsLockHUDVisible = true
        }
        capsLockHUDDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                capsLockHUDVisible = false
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if coordinator.helloAnimationRunning {
                    Spacer()
                    HelloAnimation(onFinish: {
                        vm.closeHello()
                    }).frame(
                        width: getClosedNotchSize().width,
                        height: 80
                    )
                    .padding(.top, 40)
                    Spacer()
                } else {
                    if coordinator.expandingView.type == .battery && coordinator.expandingView.show
                        && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
                    {
                        HStack(spacing: 0) {
                            HStack {
                                Text(batteryModel.statusText)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }

                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.closedNotchSize.width + 10)

                            HStack {
                                BoringBatteryView(
                                    batteryWidth: 30,
                                    isCharging: batteryModel.isCharging,
                                    isInLowPowerMode: batteryModel.isInLowPowerMode,
                                    isPluggedIn: batteryModel.isPluggedIn,
                                    levelBattery: batteryModel.levelBattery,
                                    isForNotification: true
                                )
                            }
                            .frame(width: 76, alignment: .trailing)
                        }
                        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
                      } else if coordinator.sneakPeek.show && Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && vm.notchState == .closed {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(.opacity)
                      } else if capsLockHUDVisible && Defaults[.showCapsLockHUD] && vm.notchState == .closed && !coordinator.sneakPeek.show && !vm.hideOnClosed {
                          CapsLockIndicatorView(isOn: capsLockManager.isOn)
                              .transition(.opacity.combined(with: .scale(scale: 0.92)))
                      } else if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.enableAirPodsWidget] && airPodsManager.showSneakActivity && airPodsManager.state != nil {
                          AirPodsLiveActivity()
                              .transition(
                                  .asymmetric(
                                      insertion: .scale(scale: 0.55, anchor: .center)
                                          .combined(with: .opacity),
                                      removal: .scale(scale: 0.85, anchor: .center)
                                          .combined(with: .opacity)
                                  )
                              )
                      } else if (!coordinator.expandingView.show || coordinator.expandingView.type == .music) && vm.notchState == .closed && (musicManager.isPlaying || !musicManager.isPlayerIdle) && coordinator.musicLiveActivityEnabled && showMusicModule && !vm.hideOnClosed {
                          MusicLiveActivity()
                              .frame(alignment: .center)
                      } else if !coordinator.expandingView.show && vm.notchState == .closed && (!musicManager.isPlaying && musicManager.isPlayerIdle) && Defaults[.showNotHumanFace] && !vm.hideOnClosed  {
                          BoringFaceAnimation()
                       } else if vm.notchState == .open {
                           BoringHeader()
                               .frame(height: max(24, vm.effectiveClosedNotchHeight))
                               .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
                       } else {
                           Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.effectiveClosedNotchHeight)
                       }

                      if coordinator.sneakPeek.show {
                          if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && !Defaults[.inlineHUD] && vm.notchState == .closed {
                              SystemEventIndicatorModifier(
                                  eventType: $coordinator.sneakPeek.type,
                                  value: $coordinator.sneakPeek.value,
                                  icon: $coordinator.sneakPeek.icon,
                                  sendEventBack: { newVal in
                                      switch coordinator.sneakPeek.type {
                                      case .volume:
                                          VolumeManager.shared.setAbsolute(Float32(newVal))
                                      case .brightness:
                                          BrightnessManager.shared.setAbsolute(value: Float32(newVal))
                                      default:
                                          break
                                      }
                                  }
                              )
                              .padding(.bottom, 10)
                              .padding(.leading, 4)
                              .padding(.trailing, 8)
                          }
                          // Old sneak peek music — centered banner with title + primary artist
                          else if coordinator.sneakPeek.type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  VStack(spacing: 0) {
                                      Text(musicManager.songTitle)
                                          .font(.system(size: 11, weight: .semibold))
                                          .foregroundStyle(.white)
                                          .lineLimit(1)
                                          .truncationMode(.tail)
                                      Text(musicManager.artistName.primaryArtistName)
                                          .font(.system(size: 9, weight: .medium))
                                          .foregroundStyle(.white.opacity(0.62))
                                          .lineLimit(1)
                                          .truncationMode(.tail)
                                  }
                                  .padding(.horizontal, 14)
                                  .frame(maxWidth: .infinity, alignment: .center)
                                  .padding(.bottom, 10)
                              }
                          }
                      }
                  }
              }
              .conditionalModifier((coordinator.sneakPeek.show && (coordinator.sneakPeek.type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
            if vm.notchState == .open {
                openNotchPage()
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    private func openNotchPage() -> some View {
        VStack {
            switch coordinator.currentView {
            case .home:
                NotchHomeView(
                    albumArtNamespace: albumArtNamespace,
                    horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                    isHoveringMusicArea: $isHoveringMusicArea
                )
            case .shelf:
                if showShelfModule {
                    ShelfView()
                } else {
                    // Fallback a Home si el módulo Shelf está apagado para no quedar en negro
                    NotchHomeView(
                    albumArtNamespace: albumArtNamespace,
                    horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                    isHoveringMusicArea: $isHoveringMusicArea
                )
                        .onAppear { coordinator.currentView = .home }
                }
            case .focus:
                if showTimerModule {
                    FocusDashboardView()
                } else {
                    NotchHomeView(
                    albumArtNamespace: albumArtNamespace,
                    horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                    isHoveringMusicArea: $isHoveringMusicArea
                )
                        .onAppear { coordinator.currentView = .home }
                }
            case .airpods:
                if Defaults[.enableAirPodsWidget] {
                    AirPodsDashboardView()
                } else {
                    NotchHomeView(
                        albumArtNamespace: albumArtNamespace,
                        horizontalMediaGestureFeedback: horizontalMediaGestureFeedback,
                        isHoveringMusicArea: $isHoveringMusicArea
                    )
                    .onAppear { coordinator.currentView = .home }
                }
            }
        }
        .transition(
            .scale(scale: 0.8, anchor: .top)
            .combined(with: .opacity)
            .animation(.smooth(duration: 0.35))
        )
        .zIndex(1)
        .allowsHitTesting(vm.notchState == .open)
        .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
    }

    private func refreshModuleLayout() {
        withAnimation(animationSpring) {
            moduleRenderID = UUID()
        }

        if vm.notchState == .closed {
            vm.close()
        }
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(0, vm.effectiveClosedNotchHeight - 12),
                        height: max(0, vm.effectiveClosedNotchHeight - 12)
                    )
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                MinimalFaceFeatures()
            }
        }.frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        let baseArtSize = max(0, vm.effectiveClosedNotchHeight - 12)
        let scaledArtSize = baseArtSize * max(0.5, min(1.5, liveActivityAlbumArtSize))
        let cornerRadius = MusicPlayerImageSizes.cornerRadiusInset.closed
            * max(0.0, min(2.0, liveActivityAlbumArtCornerRadius))
        HStack {
            currentAlbumArtImage
                .resizable()
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(width: scaledArtSize, height: scaledArtSize)
                .shadow(
                    color: liveActivityAlbumArtShadow ? .black.opacity(0.45) : .clear,
                    radius: liveActivityAlbumArtShadow ? 4 : 0,
                    x: 0,
                    y: liveActivityAlbumArtShadow ? 2 : 0
                )
                .opacity(albumArtDisplayMode == .fade ? albumArtOpacity : 1.0)

            Rectangle()
                .fill(.black)
                .overlay(
                    HStack(alignment: .top) {
                        if coordinator.expandingView.show
                            && coordinator.expandingView.type == .music
                        {
                            MarqueeText(
                                .constant(musicManager.songTitle),
                                textColor: Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity(
                                (coordinator.expandingView.show
                                    && Defaults[.sneakPeekStyles] == .inline)
                                    ? 1 : 0
                            )
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(
                                    Defaults[.coloredSpectrogram]
                                        ? Color(nsColor: musicManager.avgColor)
                                        : Color.gray
                                )
                                .opacity(
                                    (coordinator.expandingView.show
                                        && coordinator.expandingView.type == .music
                                        && Defaults[.sneakPeekStyles] == .inline)
                                        ? 1 : 0
                                )
                        }
                    }
                )
                .frame(
                    width: (coordinator.expandingView.show
                        && coordinator.expandingView.type == .music
                        && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : vm.closedNotchSize.width
                            + -cornerRadiusInsets.closed.top
                )

            HStack {
                if pomodoroDotActive {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.23), lineWidth: 2)
                        Circle()
                            .trim(from: 0, to: CGFloat(focusSession.remainingFraction))
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.00, green: 0.78, blue: 0.20),
                                        Color(red: 1.00, green: 0.48, blue: 0.20),
                                        Color(red: 1.00, green: 0.30, blue: 0.40),
                                        Color(red: 1.00, green: 0.78, blue: 0.20)
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(0),
                                    endAngle: .degrees(360)
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.18), value: focusSession.remainingFraction)
                    }
                    .padding(2)
                } else if pomodoroRingActive {
                    Color.clear
                } else if useMusicVisualizer {
                    Rectangle()
                        .fill(
                            Defaults[.coloredSpectrogram]
                                ? Color(nsColor: musicManager.avgColor).gradient
                                : Color.gray.gradient
                        )
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 18, height: 14)
                        }
                } else {
                    LottieAnimationContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    vm.effectiveClosedNotchHeight - 12
                ),
                alignment: .center
            )
        }
        .frame(
            height: vm.effectiveClosedNotchHeight,
            alignment: .center
        )
        .onAppear { refreshAlbumArtFade() }
        .onChange(of: musicManager.songTitle) { _, _ in refreshAlbumArtFade() }
        .onChange(of: vm.notchState) { _, _ in refreshAlbumArtFade() }
        .onChange(of: isHovering) { _, _ in refreshAlbumArtFade() }
        .onChange(of: albumArtDisplayMode) { _, _ in refreshAlbumArtFade() }
    }

    private var currentAlbumArtImage: Image {
        if albumArtDisplayMode == .appIcon,
           let bundleID = musicManager.bundleIdentifier,
           !bundleID.isEmpty {
            return AppIcon(for: bundleID)
        }
        return Image(nsImage: musicManager.albumArt)
    }

    private func refreshAlbumArtFade() {
        guard albumArtDisplayMode == .fade else {
            albumArtFadeTask?.cancel()
            albumArtFadeTask = nil
            if albumArtOpacity != 1.0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    albumArtOpacity = 1.0
                }
            }
            return
        }

        if vm.notchState != .closed || isHovering {
            albumArtFadeTask?.cancel()
            albumArtFadeTask = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                albumArtOpacity = 1.0
            }
            return
        }

        scheduleAlbumArtFade()
    }

    private func scheduleAlbumArtFade() {
        albumArtFadeTask?.cancel()
        withAnimation(.easeInOut(duration: 0.3)) {
            albumArtOpacity = 1.0
        }
        albumArtFadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 1.0)) {
                albumArtOpacity = 0.0
            }
        }
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(
                    of: [.fileURL, .url, .utf8PlainText, .plainText, .data],
                    isTargeted: $vm.dragDetectorTargeting
                ) { providers in
                    vm.dropEvent = true
                    ShelfStateViewModel.shared.load(providers)
                    return true
                }
        } else {
            EmptyView()
        }
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !self.vm.isAudioPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }
        guard coordinator.currentView != .shelf else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose {
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }

    private func handleNextTrackGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleHorizontalMediaGesture(translation: translation, phase: phase, feedback: -1) {
            musicManager.nextTrack()
        }
    }

    private func handlePreviousTrackGesture(translation: CGFloat, phase: NSEvent.Phase) {
        handleHorizontalMediaGesture(translation: translation, phase: phase, feedback: 1) {
            musicManager.previousTrack()
        }
    }

    private func handleHorizontalMediaGesture(
        translation: CGFloat,
        phase: NSEvent.Phase,
        feedback: CGFloat,
        action: () -> Void
    ) {
        guard isHorizontalMediaGestureContext else {
            resetHorizontalMediaGesture()
            return
        }
        guard phase != .ended else {
            resetHorizontalMediaGesture()
            return
        }
        guard !horizontalMediaGestureTriggered else { return }
        guard translation > Defaults[.gestureSensitivity] else { return }

        horizontalMediaGestureTriggered = true
        triggerHorizontalMediaFeedback(feedback)
        action()

        if Defaults[.enableHaptics] {
            haptics.toggle()
        }
    }

    private func resetHorizontalMediaGesture() {
        horizontalMediaGestureTriggered = false
    }

    private func triggerHorizontalMediaFeedback(_ feedback: CGFloat) {
        withAnimation(.interactiveSpring(response: 0.18, dampingFraction: 0.62)) {
            horizontalMediaGestureFeedback = feedback
            if vm.notchState == .closed {
                gestureProgress = 2
            }
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            withAnimation(animationSpring) {
                horizontalMediaGestureFeedback = .zero
                if vm.notchState == .closed {
                    gestureProgress = .zero
                }
            }
        }
    }

    private var isHorizontalMediaGestureContext: Bool {
        switch vm.notchState {
        case .closed:
            guard !vm.hideOnClosed else { return false }

            if coordinator.sneakPeek.show {
                return coordinator.sneakPeek.type == .music
            }

            guard !coordinator.expandingView.show || coordinator.expandingView.type == .music else {
                return false
            }

            return coordinator.musicLiveActivityEnabled
                && showMusicModule
                && (musicManager.isPlaying || !musicManager.isPlayerIdle)

        case .open:
            return coordinator.currentView == .home
                && !musicManager.isPlayerIdle
                && isHoveringMusicArea
        }
    }
}

private extension String {
    var primaryArtistName: String {
        let separators = [",", " feat. ", " ft. ", " featuring ", " & ", " x ", " y "]
        for separator in separators {
            if let range = range(of: separator, options: [.caseInsensitive]) {
                let primary = self[..<range.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                if !primary.isEmpty { return primary }
            }
        }
        return trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}
