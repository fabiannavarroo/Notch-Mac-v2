//
//  MusicVisualizer.swift
//  NotchMac
//
//  Created by Harsh Vardhan  Goswami  on 02/08/24.
//
import AppKit
import Cocoa
import Defaults
import SwiftUI

class AudioSpectrum: NSView, AudioCaptureLevelsConsumer {
    private var barLayers: [CAShapeLayer] = []
    private var isPlaying = false
    private var useRealtime = false
    private var tintColor: NSColor = .white
    private var lastTintColor: NSColor?

    private weak var attachedManager: AudioCaptureManager?
    private var lastAppliedLevels: [Float]
    private static let levelChangeThreshold: Float = 0.005
    private static let minBarScale: CGFloat = 0.12
    private static let idleBarScale: CGFloat = 0.35
    private static let animationKey = "scaleAnimation"

    private let barWidth: CGFloat = 2
    private let barCount = AudioCaptureManager.barCount
    private let spacing: CGFloat = 1
    private let totalHeight: CGFloat = 14

    override init(frame frameRect: NSRect) {
        self.lastAppliedLevels = [Float](repeating: 0, count: AudioCaptureManager.barCount)
        super.init(frame: frameRect)
        wantsLayer = true
        setupBars()
    }

    required init?(coder: NSCoder) {
        self.lastAppliedLevels = [Float](repeating: 0, count: AudioCaptureManager.barCount)
        super.init(coder: coder)
        wantsLayer = true
        setupBars()
    }

    deinit {
        attachedManager?.clearLevelsConsumer(self)
    }

    private func setupBars() {
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing
        if frame.width < totalWidth {
            frame.size = CGSize(width: totalWidth, height: totalHeight)
        }
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        for i in 0..<barCount {
            let barLayer = CAShapeLayer()
            barLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            applyFrame(to: barLayer, at: i, height: totalHeight)
            barLayer.fillColor = tintColor.cgColor
            barLayer.backgroundColor = tintColor.cgColor
            barLayer.allowsGroupOpacity = false
            barLayer.masksToBounds = true
            barLayer.contentsScale = scale
            let path = NSBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: barWidth, height: totalHeight),
                xRadius: barWidth / 2,
                yRadius: barWidth / 2
            )
            barLayer.path = path.cgPath
            barLayer.transform = CATransform3DMakeScale(1.0, Self.idleBarScale, 1.0)
            layer?.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
    }

    private func applyFrame(to barLayer: CALayer, at index: Int, height: CGFloat) {
        let x = CGFloat(index) * (barWidth + spacing)
        barLayer.bounds = CGRect(x: 0, y: 0, width: barWidth, height: height)
        barLayer.position = CGPoint(x: x + barWidth / 2, y: totalHeight / 2)
    }

    private func startRandomAnimating() {
        for (index, barLayer) in barLayers.enumerated() {
            animateBar(barLayer, delay: Double(index) * 0.08)
        }
    }

    private func animateBar(_ barLayer: CALayer, delay: TimeInterval) {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale.y")
        animation.duration = 5.0
        animation.repeatCount = .infinity
        animation.beginTime = CACurrentMediaTime() + delay
        var values: [CGFloat] = []
        let numSteps = 50
        let startValue = CGFloat.random(in: 0.3...1.0)
        for i in 0...numSteps {
            if i == 0 || i == numSteps {
                values.append(startValue)
            } else {
                values.append(CGFloat.random(in: 0.3...1.0))
            }
        }
        animation.values = values
        var keyTimes: [NSNumber] = []
        for i in 0...numSteps {
            keyTimes.append(NSNumber(value: Double(i) / Double(numSteps)))
        }
        animation.keyTimes = keyTimes
        animation.calculationMode = .cubic
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        if #available(macOS 13.0, *) {
            animation.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 24, preferred: 24)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barLayer.transform = CATransform3DMakeScale(1.0, startValue, 1.0)
        CATransaction.commit()
        barLayer.add(animation, forKey: Self.animationKey)
    }

    private func stopRandomAnimating() {
        for barLayer in barLayers {
            barLayer.removeAnimation(forKey: Self.animationKey)
        }
    }

    private func resetBarsToIdle(animated: Bool) {
        CATransaction.begin()
        if animated {
            CATransaction.setAnimationDuration(0.3)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        } else {
            CATransaction.setDisableActions(true)
        }
        for barLayer in barLayers {
            barLayer.removeAnimation(forKey: Self.animationKey)
            barLayer.transform = CATransform3DMakeScale(1.0, Self.idleBarScale, 1.0)
        }
        CATransaction.commit()
    }

    func setPlaying(_ playing: Bool) {
        guard isPlaying != playing else { return }
        isPlaying = playing
        if playing {
            if useRealtime {
                stopRandomAnimating()
            } else {
                startRandomAnimating()
            }
        } else {
            resetBarsToIdle(animated: true)
        }
    }

    func setUseRealtime(_ enabled: Bool) {
        guard useRealtime != enabled else { return }
        useRealtime = enabled
        for i in 0..<lastAppliedLevels.count { lastAppliedLevels[i] = -1 }
        guard isPlaying else { return }
        if enabled {
            stopRandomAnimating()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for barLayer in barLayers {
                barLayer.transform = CATransform3DMakeScale(1.0, Self.idleBarScale, 1.0)
            }
            CATransaction.commit()
        } else {
            startRandomAnimating()
        }
    }

    func attach(to manager: AudioCaptureManager) {
        guard attachedManager !== manager else { return }
        attachedManager?.clearLevelsConsumer(self)
        attachedManager = manager
        manager.setLevelsConsumer(self)
    }

    func syncCurrentLevels(from manager: AudioCaptureManager) {
        guard attachedManager === manager,
              let values = manager.latestLevelsSnapshot() else { return }
        applyLevels(values)
    }

    func audioCaptureManager(_ manager: AudioCaptureManager, didProduceLevels values: [Float]) {
        applyLevels(values)
    }

    private func applyLevels(_ values: [Float]) {
        guard isPlaying, useRealtime, values.count == barCount else { return }
        var maxDelta: Float = 0
        for i in 0..<barCount {
            let d = abs(values[i] - lastAppliedLevels[i])
            if d > maxDelta { maxDelta = d }
        }
        guard maxDelta >= Self.levelChangeThreshold else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for i in 0..<barCount {
            let v = values[i]
            lastAppliedLevels[i] = v
            let clamped = max(Self.minBarScale, min(1.0, CGFloat(v)))
            barLayers[i].transform = CATransform3DMakeScale(1.0, clamped, 1.0)
        }
        CATransaction.commit()
    }

    func setTintColor(_ color: NSColor) {
        if let last = lastTintColor, last.isEqual(color) { return }
        lastTintColor = color
        tintColor = color
        for barLayer in barLayers {
            barLayer.fillColor = color.cgColor
            barLayer.backgroundColor = color.cgColor
        }
    }
}

struct AudioSpectrumView: NSViewRepresentable {
    @Binding var isPlaying: Bool
    var tintColor: Color = .white
    @Default(.realtimeAudioWaveform) var realtimeEnabled: Bool
    @ObservedObject private var audioCapture = AudioCaptureManager.shared

    func makeNSView(context: Context) -> AudioSpectrum {
        let spectrum = AudioSpectrum()
        spectrum.setTintColor(NSColor(tintColor))
        spectrum.setUseRealtime(realtimeEnabled && audioCapture.isCapturing)
        spectrum.setPlaying(isPlaying)
        spectrum.attach(to: audioCapture)
        spectrum.syncCurrentLevels(from: audioCapture)
        return spectrum
    }

    func updateNSView(_ nsView: AudioSpectrum, context: Context) {
        nsView.setTintColor(NSColor(tintColor))
        nsView.setUseRealtime(realtimeEnabled && audioCapture.isCapturing)
        nsView.setPlaying(isPlaying)
        nsView.syncCurrentLevels(from: audioCapture)
    }
}

#Preview {
    AudioSpectrumView(isPlaying: .constant(true))
        .frame(width: 20, height: 14)
        .padding()
}
