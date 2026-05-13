//
//  FocusDashboardView.swift
//  NotchMac
//
//  Pomodoro-only dashboard for the third notch screen.
//

import Defaults
import SwiftUI

@MainActor
final class FocusSessionModel: ObservableObject {
    static let shared = FocusSessionModel()

    @Published var remaining: TimeInterval
    @Published var total: TimeInterval
    @Published var isRunning: Bool = false
    @Published var isBreak: Bool = false

    private var timer: Timer?

    private init() {
        let seconds = Self.seconds(for: Defaults[.pomodoroFocusMinutes])
        remaining = seconds
        total = seconds
    }

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remaining = max(0, self.remaining - 1)
                if self.remaining == 0 {
                    self.pause()
                }
            }
        }
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func resetToFocusDuration() {
        configure(isBreak: false)
    }

    func resetToBreakDuration() {
        configure(isBreak: true)
    }

    private func configure(isBreak: Bool) {
        pause()
        self.isBreak = isBreak
        let minutes = isBreak ? Defaults[.pomodoroBreakMinutes] : Defaults[.pomodoroFocusMinutes]
        let seconds = Self.seconds(for: minutes)
        total = seconds
        remaining = seconds
    }

    var remainingFraction: Double {
        guard total > 0 else { return 0 }
        return min(max(remaining / total, 0), 1)
    }

    var timeString: String {
        let value = Int(remaining)
        return String(format: "%02d:%02d", value / 60, value % 60)
    }

    var sessionLabel: String {
        isBreak ? "Break" : "Focus"
    }

    private static func seconds(for minutes: Int) -> TimeInterval {
        TimeInterval(max(1, minutes) * 60)
    }
}

struct FocusDashboardView: View {
    @ObservedObject private var session = FocusSessionModel.shared
    @Default(.pomodoroFocusMinutes) private var focusMinutes
    @Default(.pomodoroBreakMinutes) private var breakMinutes

    var body: some View {
        VStack(spacing: 10) {
            header
            timerRing
            controls
            presets
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(width: 520, height: 188)
        .background(Color.black)
        .onChange(of: focusMinutes) { _, _ in
            if !session.isBreak && !session.isRunning {
                session.resetToFocusDuration()
            }
        }
        .onChange(of: breakMinutes) { _, _ in
            if session.isBreak && !session.isRunning {
                session.resetToBreakDuration()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: session.isBreak ? "cup.and.saucer.fill" : "timer.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.orange)
            Text(session.sessionLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text(session.isRunning ? "Running" : "Paused")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(session.isRunning ? .green : .white.opacity(0.45))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.08)))
            Spacer()
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 9)
            Circle()
                .trim(from: 0, to: session.remainingFraction)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .yellow, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: session.remainingFraction)

            VStack(spacing: 2) {
                Text(session.timeString)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("remaining")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: 96, height: 96)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            iconButton(session.isRunning ? "pause.fill" : "play.fill", title: session.isRunning ? "Pause" : "Start") {
                session.toggle()
            }
            iconButton("arrow.counterclockwise", title: "Reset") {
                session.isBreak ? session.resetToBreakDuration() : session.resetToFocusDuration()
            }
        }
    }

    private var presets: some View {
        HStack(spacing: 8) {
            presetButton("Focus", minutes: focusMinutes, isSelected: !session.isBreak) {
                session.resetToFocusDuration()
            }
            presetButton("Break", minutes: breakMinutes, isSelected: session.isBreak) {
                session.resetToBreakDuration()
            }
        }
    }

    private func iconButton(_ systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.09))
                )
        }
        .buttonStyle(.plain)
    }

    private func presetButton(
        _ title: String,
        minutes: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text("\(title) \(minutes)m")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isSelected ? Color.orange : Color.white.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
    }
}
