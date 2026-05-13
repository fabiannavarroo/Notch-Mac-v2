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

    var totalString: String {
        let value = Int(total)
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
        HStack(spacing: 28) {
            sideLabel
            divider
            circularAction(
                session.isRunning ? "pause.fill" : "play.fill",
                title: session.isRunning ? "Pause" : "Start"
            ) {
                session.toggle()
            }
            centerTimer
            circularAction("arrow.clockwise", title: "Reset") {
                session.isBreak ? session.resetToBreakDuration() : session.resetToFocusDuration()
            }
            divider
            settingsButton
        }
        .padding(.horizontal, 34)
        .frame(width: 680, height: 188)
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

    private var sideLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Pomodoro")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 142, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.22))
            .frame(width: 1, height: 78)
    }

    private var centerTimer: some View {
        VStack(spacing: 8) {
            timerRing
            presets
        }
        .frame(width: 146)
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 9)
            Circle()
                .trim(from: 0.04, to: 0.96)
                .stroke(.white.opacity(0.04), style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: session.remainingFraction * 0.92)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .yellow, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .shadow(color: .orange.opacity(0.35), radius: 8)
                .rotationEffect(.degrees(-82))
                .animation(.linear(duration: 0.25), value: session.remainingFraction)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                    Text(session.sessionLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                }
                Text(session.timeString)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("of \(session.totalString)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .monospacedDigit()
            }
        }
        .frame(width: 126, height: 126)
    }

    private func circularAction(_ systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.07))
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                    Image(systemName: systemImage)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 54, height: 54)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(width: 66)
        }
        .buttonStyle(.plain)
    }

    private var presets: some View {
        HStack(spacing: 0) {
            presetButton("Focus", minutes: focusMinutes, isSelected: !session.isBreak) {
                session.resetToFocusDuration()
            }
            presetButton("Break", minutes: breakMinutes, isSelected: session.isBreak) {
                session.resetToBreakDuration()
            }
        }
        .padding(2)
        .frame(width: 126, height: 30)
        .background(
            Capsule()
                .fill(.white.opacity(0.08))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        )
    }

    private func presetButton(
        _ title: String,
        minutes: Int,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .orange : .white.opacity(0.58))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    Capsule().fill(isSelected ? Color.orange.opacity(0.28) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button {
            SettingsWindowController.shared.showWindow()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
    }
}
