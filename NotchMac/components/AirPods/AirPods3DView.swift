//
//  AirPods3DView.swift
//  NotchMac
//
//  SceneKit-backed view that auto-rotates the AirPods USDZ on the Y axis.
//  Renders nothing while the asset is still downloading and falls back to
//  the matching SF Symbol if the download permanently fails.
//

import SceneKit
import SwiftUI

struct AirPods3DView: View {
    let variant: AirPodsModelVariant
    var size: CGFloat = 88
    var rotationSpeed: Double = 8 // seconds per full Y rotation

    @ObservedObject private var loader = AirPodsAssetLoader.shared

    var body: some View {
        ZStack {
            if let url = loader.cachedURL(for: variant) {
                AirPods3DSceneView(url: url, rotationSpeed: rotationSpeed)
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
            } else {
                fallback
            }
        }
        .onAppear {
            loader.prefetch(variant)
        }
    }

    private var fallback: some View {
        Image(systemName: variant.sfSymbolName)
            .font(.system(size: size * 0.55, weight: .regular))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: size, height: size)
    }
}

extension AirPodsModelVariant {
    var sfSymbolName: String {
        switch self {
        case .airPodsMax: return "airpodsmax"
        case .airPodsPro: return "airpodspro"
        case .airPods, .airPodsANC: return "airpods"
        }
    }
}

private struct AirPods3DSceneView: NSViewRepresentable {
    let url: URL
    let rotationSpeed: Double

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        configureScene(view)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Swap the model if the URL changes (variant switch).
        if context.coordinator.loadedURL != url {
            configureScene(nsView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
    }

    private func configureScene(_ view: SCNView) {
        guard let scene = try? SCNScene(url: url, options: [
            .checkConsistency: false,
            .convertToYUp: true
        ]) else {
            return
        }

        // Container that we will spin instead of the imported root (USDZ
        // hierarchies often have a non-zero pivot that makes direct
        // rotation wobble).
        let pivot = SCNNode()
        for child in scene.rootNode.childNodes {
            pivot.addChildNode(child)
        }

        // Center + frame model so it fills the SCNView nicely.
        let (minVec, maxVec) = pivot.boundingBox
        let center = SCNVector3(
            (minVec.x + maxVec.x) / 2,
            (minVec.y + maxVec.y) / 2,
            (minVec.z + maxVec.z) / 2
        )
        pivot.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

        let working = SCNScene()
        working.rootNode.addChildNode(pivot)

        // Sized so the largest extent fits ~1.7 units; camera then sits at 3
        // units back. Works for AirPods (small) and Max (large) alike.
        let extents = SCNVector3(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )
        let largest = max(extents.x, max(extents.y, extents.z))
        if largest > 0 {
            let scale = 1.7 / largest
            pivot.scale = SCNVector3(scale, scale, scale)
        }

        // Camera
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = false
        cam.fieldOfView = 28
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0.2, 3.2)
        working.rootNode.addChildNode(camNode)

        // Lighting — soft three-point so the glossy plastic reads well.
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1100
        key.light?.color = NSColor.white
        key.eulerAngles = SCNVector3(-Double.pi / 5, Double.pi / 6, 0)
        working.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 500
        fill.light?.color = NSColor(calibratedWhite: 0.85, alpha: 1)
        fill.eulerAngles = SCNVector3(-Double.pi / 6, -Double.pi / 3, 0)
        working.rootNode.addChildNode(fill)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 350
        ambient.light?.color = NSColor(calibratedWhite: 1, alpha: 1)
        working.rootNode.addChildNode(ambient)

        // Rotation animation (matches iOS connect-popup feel — clockwise
        // when viewed from above).
        let spin = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: rotationSpeed)
        pivot.runAction(SCNAction.repeatForever(spin))

        view.scene = working
        view.pointOfView = camNode
    }
}
