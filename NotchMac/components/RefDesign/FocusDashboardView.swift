//
//  FocusDashboardView.swift
//  NotchMac
//
//  Ref-design ref3: media compacto + Focus timer circular + Next class card
//  + fila inferior de 4 quick actions (Mute / DND / Clipboard / Calendar).
//

import AppKit
import Defaults
import SwiftUI

private let focusTotalSeconds: TimeInterval = 25 * 60

@MainActor
final class FocusSessionModel: ObservableObject {
    static let shared = FocusSessionModel()
    @Published var remaining: TimeInterval = focusTotalSeconds
    @Published var isRunning: Bool = false
    private var timer: Timer?

    func toggle() {
        if isRunning { pause() } else { start() }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remaining = max(0, self.remaining - 1)
                if self.remaining == 0 { self.pause() }
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func endSession() {
        pause()
        remaining = focusTotalSeconds
    }

    var progress: Double {
        1 - (remaining / focusTotalSeconds)
    }

    var timeString: String {
        let total = Int(remaining)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct FocusDashboardView: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var session = FocusSessionModel.shared
    @ObservedObject private var calendarManager = CalendarManager.shared
    @State private var now: Date = Date()
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            topRow
            quickActionsRow
        }
        .padding(8)
        .onReceive(tick) { now = $0 }
    }

    // MARK: - Top row
    private var topRow: some View {
        HStack(spacing: 8) {
            mediaCard
            focusCard
            nextClassCard
        }
        .frame(height: 92)
    }

    private var mediaCard: some View {
        HStack(spacing: 6) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(musicManager.songTitle.isEmpty ? "—" : musicManager.songTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(musicManager.artistName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    transportButton("backward.fill") { musicManager.previousTrack() }
                    transportButton(musicManager.isPlaying ? "pause.fill" : "play.fill") {
                        musicManager.togglePlay()
                    }
                    transportButton("forward.fill") { musicManager.nextTrack() }
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func transportButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
    }

    private var focusCard: some View {
        VStack(spacing: 4) {
            Text("Focus Session")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(
                        Color.purple,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(session.timeString)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .frame(width: 56, height: 56)
            HStack(spacing: 6) {
                Button(action: { session.toggle() }) {
                    Text(session.isRunning ? "Pause" : "Start")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                Button(action: { session.endSession() }) {
                    Text("End")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.25))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var nextClassCard: some View {
        let next = nextEvent
        return VStack(alignment: .leading, spacing: 2) {
            Text("Next class in")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(next.map { minutesUntilString($0.start) } ?? "—")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(next?.title ?? "Sin eventos")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if let n = next {
                Text(rangeString(n))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var nextEvent: EventModel? {
        calendarManager.events
            .filter { $0.start >= now && !$0.isAllDay && $0.type.isEvent }
            .sorted { $0.start < $1.start }
            .first
    }

    private func minutesUntilString(_ date: Date) -> String {
        let mins = max(0, Int(date.timeIntervalSince(now) / 60))
        if mins >= 60 { return String(format: "%dh %dm", mins / 60, mins % 60) }
        return "\(mins) min"
    }

    private func rangeString(_ ev: EventModel) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return "\(f.string(from: ev.start)) – \(f.string(from: ev.end))"
    }

    // MARK: - Quick actions
    private var quickActionsRow: some View {
        HStack(spacing: 6) {
            quickAction(icon: "speaker.slash.fill", title: "Mute", subtitle: muteSubtitle) {
                toggleMute()
            }
            quickAction(icon: "moon.fill", title: "Do Not Disturb", subtitle: "Focus modes") {
                openURL("x-apple.systempreferences:com.apple.Focus-Settings.extension")
            }
            quickAction(icon: "doc.on.clipboard", title: "Clipboard", subtitle: clipboardSubtitle) {
                openURL("raycast://extensions/raycast/clipboard-history/clipboard-history")
            }
            quickAction(icon: "calendar", title: "Calendar", subtitle: calendarSubtitle) {
                NSWorkspace.shared.open(URL(string: "ical://")!)
            }
        }
        .frame(height: 44)
    }

    private func quickAction(
        icon: String, title: String, subtitle: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    private var muteSubtitle: String {
        let muted = (try? systemMuted()) ?? false
        return muted ? "On" : "Off"
    }

    private var clipboardSubtitle: String {
        let count = NSPasteboard.general.pasteboardItems?.count ?? 0
        return count == 1 ? "1 item" : "\(count) items"
    }

    private var calendarSubtitle: String {
        let today = Calendar.current.startOfDay(for: now)
        let count = calendarManager.events.filter {
            Calendar.current.isDate($0.start, inSameDayAs: today) && $0.type.isEvent
        }.count
        return count == 1 ? "1 event today" : "\(count) events today"
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }

    private func toggleMute() {
        let script = "set volume \(systemMutedOrFalse() ? "without" : "with") output muted"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    private func systemMutedOrFalse() -> Bool { (try? systemMuted()) ?? false }

    private func systemMuted() throws -> Bool {
        let script = "output muted of (get volume settings)"
        var err: NSDictionary?
        let result = NSAppleScript(source: "return \(script)")?.executeAndReturnError(&err)
        return result?.booleanValue ?? false
    }
}
