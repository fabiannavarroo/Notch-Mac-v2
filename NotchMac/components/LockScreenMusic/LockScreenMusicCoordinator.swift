import AppKit
import Combine
import Defaults
import SwiftUI

/// Orchestrates the lock-screen music feature lifecycle:
/// - reacts to lock/unlock notifications coming from `AppDelegate`
/// - shows/hides the overlay window
/// - swaps the wallpaper to match the currently playing track
/// - restores the wallpaper on unlock
@MainActor
final class LockScreenMusicCoordinator {
    static let shared = LockScreenMusicCoordinator()

    private var overlayWindow: LockScreenMusicOverlayWindow?
    private weak var hitTestView: LockScreenMusicHitTestView?
    private var artworkFallbackTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var isStarted = false
    private var isScreenLocked = false
    private var lastAppliedSongKey: String?

    private init() {}

    /// Master kill-switch: Lock Screen Music is hidden while the feature is
    /// in development. It must gate *every* entry point — `start()` alone is
    /// not enough because `AppDelegate` calls `screenLocked()` directly,
    /// which re-activated the feature for users whose (now-hidden) toggle
    /// was left flipped in Defaults. Set to `true` to re-enable, and restore
    /// the sidebar item in SettingsView.
    static let isFeatureEnabled = false

    func start() {
        guard Self.isFeatureEnabled else {
            // Clear a previously-flipped toggle so no code path can read a
            // stale `true` while the feature is hidden.
            Defaults[.lockScreenMusicEnabled] = false
            return
        }
        guard !isStarted else { return }
        isStarted = true

        LockScreenWallpaperManager.shared.prewarmCatalog()

        // Re-evaluate whenever the master toggle flips so the user gets
        // immediate feedback in settings.
        Defaults.publisher(.lockScreenMusicEnabled)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.reevaluate() }
            }
            .store(in: &cancellables)

        // Wait for real artwork before reacting. `usingAppIconForArtwork` is
        // true while MusicManager is showing the player's app-icon fallback;
        // flipping back to false means avgColor + albumArt now reflect the
        // actual track. Subscribing to that flip avoids triggering the
        // wallpaper swap with stale colours from the previous song.
        MusicManager.shared.$usingAppIconForArtwork
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] fallbackActive in
                Task { @MainActor in
                    if fallbackActive {
                        self?.armArtworkFallbackTimeout()
                    } else {
                        self?.artworkFallbackTask?.cancel()
                        self?.artworkFallbackTask = nil
                        self?.handleMusicChanged()
                    }
                }
            }
            .store(in: &cancellables)

        // Idle ↔ playing transitions: not gated on artwork, since "idle" means
        // there's nothing playing at all. Show/hide the widget accordingly.
        MusicManager.shared.$isPlayerIdle
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.handleMusicChanged() }
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        artworkFallbackTask?.cancel()
        artworkFallbackTask = nil
        hideOverlay(animated: false)
        LockScreenWallpaperManager.shared.restoreOriginal()
        isStarted = false
    }

    // MARK: - Hooks called by AppDelegate

    func screenLocked() {
        guard Self.isFeatureEnabled else { return }
        NSLog("[NotchMac][LockScreenMusic] screenLocked. enabled=\(Defaults[.lockScreenMusicEnabled]) idle=\(MusicManager.shared.isPlayerIdle) title='\(MusicManager.shared.songTitle)'")
        isScreenLocked = true
        // Snapshot the user's wallpaper BEFORE we start swapping. Doing it here
        // (vs. inside `applyMatchingWallpaper`) makes sure we capture the user's
        // own pick, not one of our own previous applications.
        LockScreenWallpaperManager.shared.snapshotOriginalIfNeeded()
        reevaluate()
    }

    func screenUnlocked() {
        NSLog("[NotchMac][LockScreenMusic] screenUnlocked")
        isScreenLocked = false
        hideOverlay(animated: true)
        LockScreenWallpaperManager.shared.restoreOriginal()
        lastAppliedSongKey = nil
    }

    // MARK: - Internal

    private func reevaluate() {
        guard Defaults[.lockScreenMusicEnabled], isScreenLocked else {
            hideOverlay(animated: true)
            LockScreenWallpaperManager.shared.restoreOriginal()
            lastAppliedSongKey = nil
            return
        }

        // Avoid showing widget for an idle/empty player. Wallpaper also stays
        // untouched until something actually plays.
        if MusicManager.shared.isPlayerIdle || MusicManager.shared.songTitle.isEmpty {
            hideOverlay(animated: true)
            return
        }

        showOverlay()
        applyWallpaperForCurrentTrack(force: true)
    }

    private func handleMusicChanged() {
        guard Defaults[.lockScreenMusicEnabled], isScreenLocked else { return }

        if MusicManager.shared.isPlayerIdle || MusicManager.shared.songTitle.isEmpty {
            hideOverlay(animated: true)
            return
        }

        showOverlay()
        applyWallpaperForCurrentTrack(force: false)
    }

    private func applyWallpaperForCurrentTrack(force: Bool) {
        // Skip while MusicManager is still showing the player's app icon
        // fallback — avgColor at this point is the previous song's color (or
        // a generic icon's). The artwork-ready publisher will retrigger us
        // once real art lands.
        guard !MusicManager.shared.usingAppIconForArtwork else { return }

        let key = trackKey()
        // Also re-apply if the avgColor changed for the same title (album art
        // is fetched async so the first paint may have stale color).
        let colorKey = MusicManager.shared.avgColor.description
        let composite = "\(key)|\(colorKey)"
        guard force || composite != lastAppliedSongKey else { return }
        lastAppliedSongKey = composite

        LockScreenWallpaperManager.shared.snapshotOriginalIfNeeded()

        // Delay the wallpaper swap so the SwiftUI veil starts crossfading
        // first. By the time `setDesktopImageURL` causes its brief
        // re-rasterisation, the veil is already opaque enough with the new
        // color to mask any flash.
        let targetColor = MusicManager.shared.avgColor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            LockScreenWallpaperManager.shared.applyMatchingWallpaper(for: targetColor)
        }
    }

    /// 3s safety: if real artwork never arrives (offline, or a track without
    /// embedded artwork), accept whatever's current so the wallpaper still
    /// reacts instead of staying frozen on the previous song's color. We call
    /// the wallpaper API directly here, bypassing the `usingAppIconForArtwork`
    /// gate that normally blocks us during the fallback period.
    private func armArtworkFallbackTimeout() {
        artworkFallbackTask?.cancel()
        artworkFallbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self else { return }
            guard Defaults[.lockScreenMusicEnabled], self.isScreenLocked else { return }
            guard !MusicManager.shared.isPlayerIdle, !MusicManager.shared.songTitle.isEmpty else { return }

            self.showOverlay()
            LockScreenWallpaperManager.shared.snapshotOriginalIfNeeded()
            LockScreenWallpaperManager.shared.applyMatchingWallpaper(for: MusicManager.shared.avgColor)
            self.lastAppliedSongKey = "\(self.trackKey())|\(MusicManager.shared.avgColor.description)"
        }
    }

    private func trackKey() -> String {
        let m = MusicManager.shared
        return "\(m.songTitle)|\(m.artistName)|\(m.album)"
    }

    // MARK: - Overlay window

    private func showOverlay() {
        if overlayWindow != nil { return }
        guard let screen = NSScreen.main else { return }

        let styleMask: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let window = LockScreenMusicOverlayWindow(
            contentRect: screen.frame,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0

        let hitView = LockScreenMusicHitTestView(frame: .init(origin: .zero, size: screen.frame.size))
        hitView.autoresizingMask = [.width, .height]

        let hostingView = NSHostingView(
            rootView: LockScreenMusicView(interactiveFrameSink: { [weak hitView] frame in
                // Frame is reported in SwiftUI's global coords (i.e. window
                // coords with origin at top-left). NSView hitTest uses
                // bottom-left, so flip Y when storing.
                guard let hitView else { return }
                let flipped = CGRect(
                    x: frame.origin.x,
                    y: hitView.bounds.height - frame.origin.y - frame.height,
                    width: frame.width,
                    height: frame.height
                )
                hitView.interactiveRect = flipped
            })
        )
        hostingView.frame = hitView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hitView.addSubview(hostingView)

        window.contentView = hitView
        hitTestView = hitView

        overlayWindow = window
        NotchSpaceManager.shared.notchSpace.windows.insert(window)
        window.enableSkyLight()
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
        }
    }

    private func hideOverlay(animated: Bool) {
        guard let window = overlayWindow else { return }
        overlayWindow = nil

        let teardown = {
            window.disableSkyLight()
            window.close()
            NotchSpaceManager.shared.notchSpace.windows.remove(window)
        }

        guard animated else {
            teardown()
            return
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        }, completionHandler: {
            teardown()
        })
    }
}
