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
    /// Optional override state used by the Settings preview to force a
    /// specific variant. When nil the view reads the live manager + the
    /// debug always-show fallback.
    var override: AirPodsState? = nil

    @ObservedObject private var manager = AirPodsManager.shared
    @ObservedObject private var tuningCenter = AirPodsTuningCenter.shared

    /// Real device state wins. The `override` parameter lets the Settings
    /// preview force a specific variant + mock state without affecting
    /// the live notch UI.
    private var resolvedState: AirPodsState? {
        override ?? manager.state
    }

    private func tuning(for variant: AirPodsModelVariant) -> AirPodsTuning {
        tuningCenter.tuning(for: variant)
    }

    var body: some View {
        Group {
            if let s = resolvedState {
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
        let t = tuning(for: s.variant)
        let tileSize = CGFloat(t.dashboardTileSize)
        return HStack(spacing: 0) {
            Spacer(minLength: 0)

            HStack(spacing: 18) {
                AirPods3DView(
                    variant: s.variant,
                    size: tileSize,
                    config: AirPodsRenderConfig.dashboard(t)
                )
                .frame(width: tileSize, height: tileSize)

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
    /// Optional injected state — when nil we read from the live manager.
    /// The debug settings panel uses this to feed fake data into a preview.
    var override: AirPodsState? = nil
    /// Overrides the chin height for the preview. Real activity reads from vm.
    var heightOverride: CGFloat? = nil

    @ObservedObject private var manager = AirPodsManager.shared
    @ObservedObject private var tuningCenter = AirPodsTuningCenter.shared
    @EnvironmentObject var vm: BoringViewModel

    private func tuning(for variant: AirPodsModelVariant) -> AirPodsTuning {
        tuningCenter.tuning(for: variant)
    }

    // MARK: Layout

    private var resolvedState: AirPodsState? {
        // Real device state wins. The `override` parameter is what the
        // Settings preview uses to render with a mock state; the live
        // notch view never falls back to mock data anymore.
        override ?? manager.state
    }

    /// Fake AirPods state used when the user has the debug-always-show
    /// toggle on but no real AirPods are connected.
    static let mockState = mockState(for: .airPodsPro)

    static func mockState(for variant: AirPodsModelVariant) -> AirPodsState {
        switch variant {
        case .airPods:
            return AirPodsState(name: "AirPods (debug)", variant: .airPods,
                                left: 92, right: 88, case_: 70, single: nil)
        case .airPodsANC:
            return AirPodsState(name: "AirPods 4 ANC (debug)", variant: .airPodsANC,
                                left: 90, right: 87, case_: 65, single: nil)
        case .airPodsPro:
            return AirPodsState(name: "AirPods Pro (debug)", variant: .airPodsPro,
                                left: 85, right: 82, case_: 60, single: nil)
        case .airPodsMax:
            return AirPodsState(name: "AirPods Max (debug)", variant: .airPodsMax,
                                left: nil, right: nil, case_: nil, single: 78)
        }
    }

    private var chinHeight: CGFloat {
        heightOverride ?? vm.effectiveClosedNotchHeight
    }

    private var slotHeight: CGFloat {
        max(0, chinHeight - 4)
    }

    private var notchWidth: CGFloat {
        override != nil ? 200 : vm.closedNotchSize.width - 20
    }

    var body: some View {
        if let s = resolvedState {
            let t = tuning(for: s.variant)
            let artWidth = slotHeight * CGFloat(t.artWidthMultiplier)
            let artTileWidth = artWidth + CGFloat(t.artSidePadding) * 2
            let ringTileWidth = CGFloat(t.ringDiameter) + CGFloat(t.ringSidePadding) * 2

            HStack(spacing: 0) {
                AirPods3DView(
                    variant: s.variant,
                    size: artWidth,
                    rotationSpeed: 5,
                    hideCase: true,
                    tightCrop: true,
                    zoomOverride: CGFloat(t.modelZoom)
                )
                .frame(width: artTileWidth, height: slotHeight)
                .offset(x: CGFloat(t.artLeftShift))

                Rectangle()
                    .fill(.black)
                    .frame(width: notchWidth)

                AirPodsMiniBatteryRing(
                    level: s.averagePodLevel,
                    diameter: CGFloat(t.ringDiameter),
                    strokeWidth: CGFloat(t.ringStrokeWidth),
                    textScale: CGFloat(t.ringTextScale)
                )
                .frame(width: ringTileWidth, height: slotHeight)
            }
            .frame(height: chinHeight, alignment: .center)
        }
    }
}

private struct AirPodsMiniBatteryRing: View {
    let level: Int?
    /// Outer diameter in points. Configured by the parent.
    let diameter: CGFloat
    /// Stroke thickness in points. Higher = chunkier ring.
    let strokeWidth: CGFloat
    /// Font size relative to diameter (0.4 = 40 % of diameter).
    var textScale: CGFloat = 0.42

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
                    .font(.system(size: diameter * textScale, weight: .semibold, design: .rounded))
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
