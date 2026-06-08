import Combine
import Defaults
import SwiftUI

/// Apple Music-style lock screen widget: album art + glassy player capsule,
/// optionally with a karaoke lyrics column to the right when synced lyrics
/// are available.
struct LockScreenMusicView: View {
    /// Frame of the interactive widget in window-local coords, reported back
    /// to the hosting window so click-through outside it can pass to lock UI.
    var interactiveFrameSink: (CGRect) -> Void

    @ObservedObject private var music = MusicManager.shared
    @Default(.lockScreenMusicShowLyrics) private var showLyrics

    // Held metadata — what the view actually renders. We freeze these while
    // MusicManager is showing the player's app-icon fallback (real album art
    // not yet downloaded). When real artwork lands these are refreshed, which
    // also drives the animation crossfade. A 3s safety timer flushes the
    // freeze if no real artwork ever arrives (offline / source w/o metadata).
    @State private var heldTitle: String = ""
    @State private var heldArtist: String = ""
    @State private var heldAlbum: String = ""
    @State private var heldArtwork: NSImage = NSImage()
    @State private var heldColor: NSColor = .white
    @State private var heldSyncedLyrics: [(time: Double, text: String)] = []
    @State private var hasInitialised: Bool = false
    @State private var fallbackTimeoutTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: music.isPlaying ? 0.25 : 1.0)) { timeline in
                let lyricsAvailable = showLyrics && !heldSyncedLyrics.isEmpty
                let safeBottom = max(geometry.size.height * 0.18, 120)

                ZStack(alignment: .bottom) {
                    // Crossfading color veil. We avoid SwiftUI's default RGB
                    // interpolation (which crawls through muddy midpoints) by
                    // rendering each color as its own layer and crossfading
                    // them via `.id(...)` + `.transition(.opacity)`.
                    LockScreenVeilLayer(
                        color: veilColor,
                        screenSize: geometry.size
                    )
                    .opacity(music.isPlayerIdle ? 0 : 1)
                    .animation(.easeInOut(duration: 0.5), value: music.isPlayerIdle)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    if !music.isPlayerIdle {
                        widget(
                            lyricsAvailable: lyricsAvailable,
                            now: timeline.date,
                            screenSize: geometry.size
                        )
                        .padding(.bottom, safeBottom)
                        .padding(.horizontal, max(40, geometry.size.width * 0.05))
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: InteractiveFrameKey.self,
                                    value: proxy.frame(in: .global)
                                )
                            }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(.easeInOut(duration: 0.35), value: music.isPlayerIdle)
                .animation(.easeInOut(duration: 0.4), value: heldTitle)
                .onPreferenceChange(InteractiveFrameKey.self) { frame in
                    interactiveFrameSink(frame)
                }
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .onAppear {
            // Initial sync. If artwork is already real at lock time, flush
            // immediately so the user doesn't see a blank widget. Otherwise
            // start the 3s timeout — eventually we'll accept whatever's there.
            if !hasInitialised {
                hasInitialised = true
                if shouldAcceptCurrentArtwork {
                    flushHeldFromMusicManager()
                } else {
                    armFallbackTimeout()
                }
            }
        }
        .onDisappear {
            fallbackTimeoutTask?.cancel()
            fallbackTimeoutTask = nil
        }
        .onChange(of: music.usingAppIconForArtwork) { _, fallbackActive in
            if fallbackActive {
                armFallbackTimeout()
            } else {
                fallbackTimeoutTask?.cancel()
                fallbackTimeoutTask = nil
                flushHeldFromMusicManager()
            }
        }
        .onChange(of: music.albumArt) { _, _ in
            // Catches the case where art changes from one real image to
            // another (next song, art lands while we're already showing).
            if shouldAcceptCurrentArtwork {
                flushHeldFromMusicManager()
            }
        }
        .onChange(of: music.syncedLyrics.count) { _, _ in
            // Lyrics arrive async on their own track. Keep them in sync as
            // long as the rest of the metadata is real.
            if shouldAcceptCurrentArtwork {
                heldSyncedLyrics = music.syncedLyrics
            }
        }
    }

    /// True when MusicManager has a non-fallback album art ready for the
    /// currently playing track. We use it both as a "ready to flush" predicate
    /// and as the live-sync gate for things like lyrics.
    private var shouldAcceptCurrentArtwork: Bool {
        !music.usingAppIconForArtwork
            && music.albumArt !== defaultImage
            && !music.songTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func flushHeldFromMusicManager() {
        heldTitle = music.songTitle
        heldArtist = music.artistName
        heldAlbum = music.album
        heldArtwork = music.albumArt
        heldColor = music.avgColor
        heldSyncedLyrics = music.syncedLyrics
    }

    private func armFallbackTimeout() {
        fallbackTimeoutTask?.cancel()
        fallbackTimeoutTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            // 3s elapsed and the player still has no real art — accept
            // whatever's current so the UI doesn't stay frozen on the old
            // song's metadata forever.
            flushHeldFromMusicManager()
        }
    }

    /// Song color flattened to sRGB and dimmed to ~55%, matching the dimming
    /// applied by `LockScreenWallpaperManager` so the veil sits on top of a
    /// consistent tone.
    private var veilColor: Color {
        let srgb = heldColor.usingColorSpace(.sRGB) ?? heldColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        let dim: CGFloat = 0.55
        return Color(.sRGB, red: Double(r * dim), green: Double(g * dim), blue: Double(b * dim), opacity: 1)
    }

    /// Single HStack that grows / shrinks based on whether the lyrics column
    /// should appear. SwiftUI's spring on `lyricsAvailable` handles the layout
    /// resize: art shrinks slightly, capsule slides, lyrics fade-slide in from
    /// the trailing edge. When lyrics go away, the widget recenters.
    @ViewBuilder
    private func widget(lyricsAvailable: Bool, now: Date, screenSize: CGSize) -> some View {
        HStack(alignment: .center, spacing: lyricsAvailable ? max(40, screenSize.width * 0.04) : 0) {
            VStack(spacing: 22) {
                artwork(dimension: artworkDimension(for: screenSize, twoColumn: lyricsAvailable))
                playerCapsule(now: now)
                    .frame(maxWidth: lyricsAvailable ? 420 : 460)
            }

            if lyricsAvailable {
                lyricsColumn(now: now)
                    .frame(maxWidth: 500, maxHeight: 460)
                    .transition(.asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .trailing))
                            .combined(with: .scale(scale: 0.92, anchor: .leading)),
                        removal: .opacity
                            .combined(with: .move(edge: .trailing))
                            .combined(with: .scale(scale: 0.94, anchor: .leading))
                    ))
            }
        }
        .frame(maxWidth: 1100)
        .animation(.spring(response: 0.65, dampingFraction: 0.85), value: lyricsAvailable)
    }

    private func artworkDimension(for size: CGSize, twoColumn: Bool) -> CGFloat {
        let cap = twoColumn ? min(size.width * 0.30, size.height * 0.55)
                            : min(size.width * 0.32, size.height * 0.50)
        return min(twoColumn ? 420 : 400, cap)
    }

    private func artwork(dimension: CGFloat) -> some View {
        Image(nsImage: heldArtwork)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: dimension, height: dimension)
            .clipShape(RoundedRectangle(cornerRadius: dimension * 0.08, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: dimension * 0.08, style: .continuous)
                    .stroke(.white.opacity(0.10), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.50), radius: 30, y: 18)
            .id(heldArtwork)
            .transition(.opacity)
    }

    private func playerCapsule(now: Date) -> some View {
        let progress = estimatedProgress(at: now)
        let fraction = music.songDuration > 0
            ? min(max(progress / music.songDuration, 0), 1)
            : 0
        let remaining = max(0, music.songDuration - progress)

        return VStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(heldTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(heldArtist)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            VStack(spacing: 4) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.16))
                        Capsule()
                            .fill(.white.opacity(0.88))
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 4)

                HStack {
                    Text(timeString(progress))
                    Spacer()
                    Text("-" + timeString(remaining))
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
            }

            controls()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.black.opacity(0.28))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 28, y: 18)
        )
    }

    private func controls() -> some View {
        // Controls are wired but lock-screen click delivery is best-effort;
        // macOS may not forward events to non-key panels during the secure
        // login window session.
        HStack(spacing: 26) {
            controlButton(systemImage: "backward.fill", size: 17) {
                MusicManager.shared.previousTrack()
            }
            controlButton(
                systemImage: music.isPlaying ? "pause.fill" : "play.fill",
                size: 22,
                prominent: true
            ) {
                MusicManager.shared.togglePlay()
            }
            controlButton(systemImage: "forward.fill", size: 17) {
                MusicManager.shared.nextTrack()
            }
        }
        .padding(.top, 2)
    }

    private func controlButton(
        systemImage: String,
        size: CGFloat,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: prominent ? 40 : 32, height: prominent ? 40 : 32)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func lyricsColumn(now: Date) -> some View {
        let elapsed = estimatedProgress(at: now)
        let active = activeLyricsWindow(elapsed: elapsed, context: 2)
        // Pair the parent's .animation modifier to the active line position so
        // line transitions (insert/remove) and style changes fire together.
        let activeMarker = active.first(where: { $0.isActive })?.index ?? -1

        VStack(alignment: .leading, spacing: 18) {
            ForEach(active, id: \.index) { item in
                lyricLine(item)
                    .id(item.index)
                    .transition(.asymmetric(
                        insertion: .opacity
                            .combined(with: .move(edge: .bottom))
                            .combined(with: .scale(scale: 0.92, anchor: .leading)),
                        removal: .opacity
                            .combined(with: .move(edge: .top))
                            .combined(with: .scale(scale: 0.94, anchor: .leading))
                    ))
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.85), value: activeMarker)
    }

    /// Single lyric line styled like Apple Music's iOS lock-screen lyrics:
    /// active is large + bold + bright, past dimmer/blurred/scaled-down, future
    /// medium. Style changes within an existing line animate via the inner
    /// spring on `item.isActive`.
    private func lyricLine(_ item: LyricsItem) -> some View {
        Text(item.text)
            .font(.system(
                size: item.isActive ? 30 : 19,
                weight: item.isActive ? .bold : .medium,
                design: .default
            ))
            .foregroundStyle(.white.opacity(
                item.isActive ? 0.98 :
                item.isPast ? 0.22 : 0.58
            ))
            .blur(radius: item.isActive ? 0 : item.isPast ? 0.7 : 0.35)
            .scaleEffect(item.isActive ? 1.0 : 0.93, anchor: .leading)
            .lineLimit(3)
            .minimumScaleFactor(0.65)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: item.isActive)
    }

    // MARK: - Helpers

    private func estimatedProgress(at date: Date) -> TimeInterval {
        let base = music.elapsedTime
        let duration = music.songDuration
        guard duration > 0 else { return max(0, base) }
        guard music.isPlaying else { return min(max(base, 0), duration) }
        let delta = date.timeIntervalSince(music.timestampDate) * music.playbackRate
        return min(max(base + delta, 0), duration)
    }

    private struct LyricsItem {
        let index: Int
        let text: String
        let isActive: Bool
        let isPast: Bool
    }

    /// Karaoke services time their lines for when the singer hits the word,
    /// but the now-playing pipeline (MR adapter → MusicManager → view) adds
    /// ~300-500ms of latency. Advancing the cursor compensates so the active
    /// line lights up slightly before the audio, matching Apple Music's feel.
    private static let lyricsLeadTime: TimeInterval = 0.4

    private func activeLyricsWindow(elapsed: TimeInterval, context: Int) -> [LyricsItem] {
        let lines = heldSyncedLyrics
        guard !lines.isEmpty else { return [] }

        let cursor = elapsed + Self.lyricsLeadTime

        var activeIdx = 0
        for (i, line) in lines.enumerated() where line.time <= cursor {
            activeIdx = i
        }

        let lower = max(0, activeIdx - context)
        let upper = min(lines.count - 1, activeIdx + context)
        return (lower...upper).map { i in
            LyricsItem(
                index: i,
                text: lines[i].text,
                isActive: i == activeIdx,
                isPast: i < activeIdx
            )
        }
    }

    private func timeString(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }
}

private struct InteractiveFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// Background color veil with a soft radial gradient (denser center, fading
/// to the edges) and a true crossfade between colors. Two `Rectangle`s are
/// stacked: the active one keyed by the color hex via `.id(...)`. When the
/// color changes, SwiftUI builds a fresh view for the new color and runs the
/// `.opacity` transition — old view fades out, new view fades in, both
/// visible during the overlap so no RGB midpoint mud.
private struct LockScreenVeilLayer: View {
    let color: Color
    let screenSize: CGSize

    var body: some View {
        ZStack {
            Rectangle()
                .fill(gradient(for: color))
                .id(colorIdentity(color))
                .transition(.opacity)
        }
        // Slow, soft spring. Long response so the crossfade feels deliberate
        // rather than reactive; damping near 1 prevents bounce on a value
        // that shouldn't oscillate.
        .animation(.interpolatingSpring(stiffness: 7, damping: 14), value: colorIdentity(color))
    }

    private func gradient(for color: Color) -> RadialGradient {
        let radius = max(screenSize.height, screenSize.width) * 0.7
        return RadialGradient(
            gradient: Gradient(stops: [
                .init(color: color.opacity(0.55), location: 0),
                .init(color: color.opacity(0.40), location: 0.45),
                .init(color: color.opacity(0.22), location: 0.85),
                .init(color: color.opacity(0.10), location: 1)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: radius
        )
    }

    /// Stable hash of the displayed color so identical colors don't trigger a
    /// pointless re-mount. We round each channel to 1/64 — coarse enough to
    /// dedupe near-identical album shades, fine enough to feel responsive.
    private func colorIdentity(_ color: Color) -> Int {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? .black
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        let q = { (c: CGFloat) -> Int in Int(round(c * 64)) }
        return q(r) << 16 | q(g) << 8 | q(b)
    }
}
