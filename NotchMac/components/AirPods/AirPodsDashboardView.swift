//
//  AirPodsDashboardView.swift
//  NotchMac
//
//  Expanded AirPods card shown inside the open notch: rotating 3D model on
//  the left, battery rings on the right (left pod, right pod, case). Mirrors
//  the Pomodoro dashboard layout so the visual language stays consistent.
//

import Defaults
import SwiftUI

struct AirPodsDashboardView: View {
    @ObservedObject private var manager = AirPodsManager.shared

    var body: some View {
        Group {
            if let s = manager.state {
                content(for: s)
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: "airpods")
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
            Text("Sin AirPods conectados")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func content(for s: AirPodsState) -> some View {
        HStack(spacing: 18) {
            AirPods3DView(variant: s.variant, size: 92, rotationSpeed: 7)
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(s.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(statusLine(for: s))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    BatteryRing(label: "L", level: s.left ?? s.single)
                    BatteryRing(label: "R", level: s.right ?? s.single)
                    BatteryRing(label: "Case", level: s.case_, isCase: true)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func statusLine(for s: AirPodsState) -> String {
        if let lo = s.lowestPodLevel {
            return "Batería más baja \(lo)%"
        }
        return "Sin información de batería"
    }
}

struct BatteryRing: View {
    let label: String
    let level: Int?
    var isCase: Bool = false

    private var fraction: Double {
        Double(level ?? 0) / 100.0
    }

    private var color: Color {
        guard let level else { return .white.opacity(0.18) }
        if level <= Defaults[.airPodsThresholdCritical] { return .red }
        if level <= Defaults[.airPodsThresholdLow] { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: max(0.001, fraction))
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.7), color, color.opacity(0.7)], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.35), radius: 3)
                    .animation(.easeInOut(duration: 0.4), value: fraction)
                Image(systemName: isCase ? "briefcase.fill" : "earbuds")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 34, height: 34)

            Text(level.map { "\($0)%" } ?? "—")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 44)
    }
}

/// Compact closed-notch indicator: the lowest-pod battery ring beside the
/// AirPods symbol. Used as a sneak peek when the notch is closed.
struct AirPodsClosedNotchIndicator: View {
    @ObservedObject private var manager = AirPodsManager.shared

    var body: some View {
        if let s = manager.state, let lo = s.lowestPodLevel {
            HStack(spacing: 4) {
                Image(systemName: s.variant.sfSymbolName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: max(0.001, Double(lo) / 100.0))
                        .stroke(color(for: lo), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 12, height: 12)
                Text("\(lo)%")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .monospacedDigit()
            }
        }
    }

    private func color(for level: Int) -> Color {
        if level <= Defaults[.airPodsThresholdCritical] { return .red }
        if level <= Defaults[.airPodsThresholdLow] { return .orange }
        return .green
    }
}
