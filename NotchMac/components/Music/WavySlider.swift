//
//  WavySlider.swift
//  NotchMac
//
//  Ported from upstream PR TheBoredTeam/boring.notch#1136.
//  Played portion = animated sine wave; unplayed portion = flat line.
//  Wave amplitude collapses to 0 when playback is paused.
//

import SwiftUI

struct WavyTrackShape: Shape {
    var progress: CGFloat
    var amplitude: CGFloat
    var wavelength: CGFloat
    var phase: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(progress, amplitude), phase) }
        set {
            progress = newValue.first.first
            amplitude = newValue.first.second
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let progressWidth = max(0, min(rect.width, rect.width * progress))
        guard progressWidth > 0 else { return path }

        path.move(to: CGPoint(x: 0, y: midY))

        let wavelengthClamped = max(wavelength, 1)
        let step: CGFloat = 1.5
        var x: CGFloat = 0
        while x <= progressWidth {
            let fadeIn = min(x / 14.0, 1.0)
            let fadeOut = min(max(0, progressWidth - x) / 10.0, 1.0)
            let localAmp = amplitude * fadeIn * fadeOut
            let y = midY + sin((x / wavelengthClamped) * .pi * 2 + phase) * localAmp
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return path
    }
}

struct WavyUnplayedTrackShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let startX = max(0, min(rect.width, rect.width * progress))
        guard startX < rect.width else { return path }
        path.move(to: CGPoint(x: startX, y: midY))
        path.addLine(to: CGPoint(x: rect.width, y: midY))
        return path
    }
}

struct WavySlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let isPlaying: Bool

    var color: Color = .white
    var dragging: Binding<Bool>? = nil
    var lastDragged: Binding<Date>? = nil
    var onValueChange: ((Double) -> Void)? = nil
    var onDragChange: ((Double) -> Void)? = nil

    @State private var internalDragging: Bool = false

    private let baseAmplitude: CGFloat = 2.0
    private let dragAmplitude: CGFloat = 3.5
    private let wavelength: CGFloat = 24.0
    private let cyclesPerSecond: Double = 1.5

    private var isDragging: Bool {
        dragging?.wrappedValue ?? internalDragging
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height / 2
            let rangeSpan = range.upperBound - range.lowerBound
            let rawProgress = rangeSpan == .zero
                ? 0
                : CGFloat((value - range.lowerBound) / rangeSpan)
            let progress = max(0, min(1, rawProgress))

            let targetAmplitude: CGFloat = {
                if isDragging { return dragAmplitude }
                return isPlaying ? baseAmplitude : 0
            }()

            TimelineView(.animation) { timeline in
                let phase = phaseFor(time: timeline.date)
                ZStack {
                    WavyUnplayedTrackShape(progress: progress)
                        .stroke(Color.gray.opacity(0.3), style: StrokeStyle(
                            lineWidth: isDragging ? 4 : 3,
                            lineCap: .round
                        ))

                    WavyTrackShape(
                        progress: progress,
                        amplitude: targetAmplitude,
                        wavelength: wavelength,
                        phase: phase
                    )
                    .stroke(color, style: StrokeStyle(
                        lineWidth: isDragging ? 4 : 3,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .animation(.easeOut(duration: 0.35), value: targetAmplitude)

                    Circle()
                        .fill(color)
                        .frame(width: isDragging ? 10 : 6, height: isDragging ? 10 : 6)
                        .position(x: progress * width, y: midY)
                        .shadow(color: color.opacity(0.4), radius: isDragging ? 4 : 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setDragging(true)
                        let newValue = range.lowerBound + Double(gesture.location.x / max(width, 1)) * rangeSpan
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        onDragChange?(value)
                    }
                    .onEnded { _ in
                        onValueChange?(value)
                        setDragging(false)
                        lastDragged?.wrappedValue = Date()
                    }
            )
        }
    }

    private func setDragging(_ value: Bool) {
        if let dragging {
            dragging.wrappedValue = value
        } else {
            internalDragging = value
        }
    }

    private func phaseFor(time: Date) -> CGFloat {
        let period = 1.0 / cyclesPerSecond
        let t = time.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return CGFloat(t / period) * .pi * 2
    }
}
