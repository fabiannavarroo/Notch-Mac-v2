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
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 18) {
                AirPods3DView(variant: s.variant, size: 118, rotationSpeed: 7, hideCase: false)
                    .frame(width: 118, height: 118)

                VStack(alignment: .leading, spacing: 6) {
                    Text(s.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(statusLine(for: s))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)

                    HStack(spacing: 14) {
                        BatteryRing(label: "L", level: s.left ?? s.single)
                        BatteryRing(label: "R", level: s.right ?? s.single)
                        if s.case_ != nil {
                            BatteryRing(label: "Case", level: s.case_, isCase: true)
                        }
                    }
                    .padding(.top, 4)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
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

    @State private var animatedFraction: Double = 0

    private var targetFraction: Double {
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
                    .trim(from: 0, to: max(0.001, animatedFraction))
                    .stroke(
                        AngularGradient(colors: [color.opacity(0.7), color, color.opacity(0.7)], center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.35), radius: 3)
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
        .onAppear {
            animatedFraction = 0
            withAnimation(.easeOut(duration: 0.9).delay(0.05)) {
                animatedFraction = targetFraction
            }
        }
        .onChange(of: targetFraction) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedFraction = newValue
            }
        }
    }
}

/// Closed-notch live activity. Mirrors the music live activity layout:
/// left slot holds a small rotating 3D buds-only model (case mesh hidden);
/// right slot a tiny battery ring with the average pod %. Sized to slot
/// into the same chin geometry the music activity uses.
struct AirPodsLiveActivity: View {
    @ObservedObject private var manager = AirPodsManager.shared
    @EnvironmentObject var vm: BoringViewModel

    // MARK: Tuneables (edit these to taste)

    /// Width multiplier for the 3D tile relative to the chin height. Bigger
    /// number = wider slot for the model. The physical MacBook notch sits
    /// in the middle and hides the centre band, so each side needs room.
    private let artWidthMultiplier: CGFloat = 1.9
    /// Outer diameter of the battery ring (pt). Smaller looks tidier.
    private let ringDiameter: CGFloat = 22
    /// Stroke width of the battery ring (pt). Higher = thicker / chunkier.
    private let ringStrokeWidth: CGFloat = 2
    /// Extra horizontal padding around the ring tile (pt). Bumps the chin
    /// width so the indicator doesn't hug the corner of the live activity.
    private let ringSidePadding: CGFloat = 14
    /// Extra horizontal padding around the 3D tile (pt). Same idea.
    private let artSidePadding: CGFloat = 10
    /// Visual shift applied to the 3D buds. Negative = move further left,
    /// away from the physical MacBook notch that sits at the centre.
    private let artLeftShift: CGFloat = -14

    // MARK: Layout

    private var slotHeight: CGFloat {
        max(0, vm.effectiveClosedNotchHeight - 4)
    }

    private var artWidth: CGFloat { slotHeight * artWidthMultiplier }
    private var ringTileWidth: CGFloat { ringDiameter + ringSidePadding * 2 }
    private var artTileWidth: CGFloat { artWidth + artSidePadding * 2 }

    var body: some View {
        if let s = manager.state {
            HStack(spacing: 0) {
                AirPods3DView(
                    variant: s.variant,
                    size: artWidth,
                    rotationSpeed: 5,
                    hideCase: true,
                    tightCrop: true
                )
                .frame(width: artTileWidth, height: slotHeight)
                .offset(x: artLeftShift)

                // Black filler matching the physical notch — same trick the
                // music live activity uses to avoid drawing behind the
                // hardware notch on real MacBooks.
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)

                AirPodsMiniBatteryRing(
                    level: s.averagePodLevel,
                    diameter: ringDiameter,
                    strokeWidth: ringStrokeWidth
                )
                .frame(width: ringTileWidth, height: slotHeight)
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        }
    }

    static let defaultArtTileWidth: CGFloat = (32 - 4) * 1.9 + 10 * 2
    static let defaultRingTileWidth: CGFloat = 22 + 14 * 2
}

private struct AirPodsMiniBatteryRing: View {
    let level: Int?
    /// Outer diameter in points. Configured by the parent.
    let diameter: CGFloat
    /// Stroke thickness in points. Higher = chunkier ring.
    let strokeWidth: CGFloat

    @State private var animatedFraction: Double = 0
    @State private var animatedLevel: Int = 0

    private var targetFraction: Double {
        Double(level ?? 0) / 100.0
    }

    private var color: Color {
        guard let level else { return .white.opacity(0.25) }
        if level <= Defaults[.airPodsThresholdCritical] { return .red }
        if level <= Defaults[.airPodsThresholdLow] { return .orange }
        return Color(red: 0.18, green: 0.85, blue: 0.40)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: strokeWidth)
            Circle()
                .trim(from: 0, to: max(0.001, animatedFraction))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.7), color, color.opacity(0.7)], center: .center),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.45), radius: 2)
            if level != nil {
                // Font scales with the ring so the digit always reads cleanly.
                Text("\(animatedLevel)")
                    .font(.system(size: diameter * 0.42, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            animatedFraction = 0
            animatedLevel = 0
            withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
                animatedFraction = targetFraction
                animatedLevel = level ?? 0
            }
        }
        .onChange(of: targetFraction) { _, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedFraction = newValue
                animatedLevel = level ?? 0
            }
        }
    }
}
