//
//  ParallaxTiltModifier.swift
//  NotchMac
//
//  Ported from upstream PR TheBoredTeam/boring.notch#1136.
//  Tracks the pointer inside the album art and tilts it with a 3D rotation.
//

import SwiftUI

struct ParallaxTiltModifier: ViewModifier {
    var enabled: Bool = true

    private let maxTilt: Double = 10
    private let tiltAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.7)

    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var isHovering = false
    @State private var viewSize: CGSize = .init(width: 90, height: 90)

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { viewSize = geo.size }
                            .onChange(of: geo.size) { _, newValue in viewSize = newValue }
                    }
                )
                .rotation3DEffect(
                    .degrees(rotationX),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.5
                )
                .rotation3DEffect(
                    .degrees(rotationY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .animation(tiltAnimation, value: rotationX)
                .animation(tiltAnimation, value: rotationY)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        isHovering = true
                        let halfW = max(viewSize.width / 2, 1)
                        let halfH = max(viewSize.height / 2, 1)
                        rotationY = Double((location.x - halfW) / halfW) * maxTilt
                        rotationX = Double(-(location.y - halfH) / halfH) * maxTilt
                    case .ended:
                        isHovering = false
                        rotationX = 0
                        rotationY = 0
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    /// Apply a 3D parallax tilt that tracks the cursor inside the view.
    /// Pass `enabled: false` to fully bypass the modifier (no hover tracking).
    func parallaxTilt(enabled: Bool) -> some View {
        modifier(ParallaxTiltModifier(enabled: enabled))
    }
}
