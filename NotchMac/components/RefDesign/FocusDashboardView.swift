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

    private static let tickInterval: TimeInterval = 0.1

    func start() {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.remaining = max(0, self.remaining - Self.tickInterval)
                if self.remaining <= 0 {
                    self.remaining = 0
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
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                focusDurationControl
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
            .padding(.horizontal, 18)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private var focusDurationControl: some View {
        VStack(spacing: 6) {
            Text("Focus")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.orange)

            HStack(spacing: 6) {
                durationButton("minus") {
                    updateFocusMinutes(by: -5)
                }

                Text("\(focusMinutes)m")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(width: 34)

                durationButton("plus") {
                    updateFocusMinutes(by: 5)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(0.08))
                    .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            )
        }
        .frame(width: 100)
    }

    private func durationButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 18, height: 18)
                .background(Circle().fill(.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private func updateFocusMinutes(by delta: Int) {
        focusMinutes = min(max(focusMinutes + delta, 5), 120)
        if !session.isBreak && !session.isRunning {
            session.resetToFocusDuration()
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.18))
            .frame(width: 1, height: 56)
    }

    private var centerTimer: some View {
        VStack(spacing: 8) {
            timerRing
            presets
        }
        .frame(width: 108)
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 5)
            Circle()
                .trim(from: 0.04, to: 0.96)
                .stroke(.white.opacity(0.05), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0, to: session.remainingFraction * 0.92)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .yellow, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .shadow(color: .orange.opacity(0.28), radius: 4)
                .rotationEffect(.degrees(-82))
                .animation(.linear(duration: 0.25), value: session.remainingFraction)

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 5, height: 5)
                    Text(session.sessionLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
                Text(session.timeString)
                    .font(.system(size: 23, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                Text("of \(session.totalString)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .monospacedDigit()
            }
        }
        .frame(width: 88, height: 88)
    }

    private func circularAction(_ systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.07))
                    Circle()
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(width: 50)
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
        .frame(width: 104, height: 24)
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
                .font(.system(size: 10, weight: .medium))
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
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 28, height: 40)
        }
        .buttonStyle(.plain)
    }
}
