//
//  AirPods3DView.swift
//  NotchMac
//
//  SceneKit-backed view that auto-rotates the AirPods USDZ on the Y axis.
//  Renders nothing while the asset is still downloading and falls back to
//  the matching SF Symbol if the download permanently fails.
//
//  Every render-tuning value is exposed through `RenderConfig` so the
//  debug settings panel can drive it from sliders in real time.
//

import Defaults
import SceneKit
import SwiftUI

struct AirPodsRenderConfig: Equatable {
    var rotationSeconds: Double = 5
    var rotationReversed: Bool = false
    var hideCase: Bool = false
    var tightCrop: Bool = false
    var showFullModel: Bool = false
    var zoom: CGFloat = 1.0
    var tiltX: CGFloat = 0
    var yShift: CGFloat = 0
    var cameraZ: CGFloat = 3.2
    var cameraY: CGFloat = 0.05
    var cameraFOV: CGFloat = 28
    var filterPositionCut: CGFloat = 0.5
    var filterAreaCut: CGFloat = 0.3

    static let `default` = AirPodsRenderConfig()

    /// Builds a config from the live @Default values for the closed-notch
    /// mini view. Settings sliders write to these defaults → this method
    /// returns fresh values every render.
    static func liveTuned(
        hideCase: Bool,
        tightCrop: Bool,
        rotationSpeed: Double? = nil
    ) -> AirPodsRenderConfig {
        AirPodsRenderConfig(
            rotationSeconds: rotationSpeed ?? Defaults[.airPodsRotationSeconds],
            rotationReversed: Defaults[.airPodsRotationReversed],
            hideCase: hideCase,
            tightCrop: tightCrop,
            showFullModel: Defaults[.airPodsShowFullModel],
            zoom: CGFloat(Defaults[.airPodsModelZoom]),
            tiltX: CGFloat(Defaults[.airPodsModelTiltX]),
            yShift: CGFloat(Defaults[.airPodsModelYShift]),
            cameraZ: CGFloat(Defaults[.airPodsCameraZ]),
            cameraY: CGFloat(Defaults[.airPodsCameraY]),
            cameraFOV: CGFloat(Defaults[.airPodsCameraFOV]),
            filterPositionCut: CGFloat(Defaults[.airPodsFilterPositionCut]),
            filterAreaCut: CGFloat(Defaults[.airPodsFilterAreaCut])
        )
    }
}

struct AirPods3DView: View {
    let variant: AirPodsModelVariant
    var size: CGFloat = 88
    /// Optional explicit config. When nil the view reads live @Default values.
    var config: AirPodsRenderConfig? = nil

    // Convenience legacy params — only used when `config` is nil.
    var rotationSpeed: Double = 5
    var hideCase: Bool = false
    var tightCrop: Bool = false
    var zoomOverride: CGFloat? = nil

    @ObservedObject private var loader = AirPodsAssetLoader.shared

    // Observe individual @Default keys so SwiftUI re-runs body on slider
    // changes. The values themselves are read inside `resolvedConfig`.
    @Default(.airPodsModelZoom)          private var _modelZoom
    @Default(.airPodsModelTiltX)         private var _tiltX
    @Default(.airPodsModelYShift)        private var _yShift
    @Default(.airPodsCameraZ)            private var _camZ
    @Default(.airPodsCameraY)            private var _camY
    @Default(.airPodsCameraFOV)          private var _camFOV
    @Default(.airPodsRotationSeconds)    private var _rotSec
    @Default(.airPodsRotationReversed)   private var _rotRev
    @Default(.airPodsShowFullModel)      private var _showFull
    @Default(.airPodsFilterPositionCut)  private var _posCut
    @Default(.airPodsFilterAreaCut)      private var _areaCut

    private var resolvedConfig: AirPodsRenderConfig {
        if let c = config { return c }
        var c = AirPodsRenderConfig.liveTuned(
            hideCase: hideCase,
            tightCrop: tightCrop,
            rotationSpeed: rotationSpeed
        )
        if let z = zoomOverride { c.zoom = z }
        return c
    }

    var body: some View {
        ZStack {
            if let url = loader.cachedURL(for: variant) {
                AirPods3DSceneView(url: url, config: resolvedConfig)
                    .frame(width: size, height: size)
                    .allowsHitTesting(false)
            } else {
                fallback
            }
        }
        .onAppear { loader.prefetch(variant) }
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
    let config: AirPodsRenderConfig

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = .clear
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        configureScene(view, context: context)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        // Any config tweak reconfigures the scene so the user sees changes
        // live as they drag sliders. URL changes also trigger reconfigure.
        if context.coordinator.loadedURL != url || context.coordinator.config != config {
            configureScene(nsView, context: context)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
        var config: AirPodsRenderConfig = .default
    }

    private func configureScene(_ view: SCNView, context: Context) {
        guard let scene = try? SCNScene(url: url, options: [
            .checkConsistency: false,
            .convertToYUp: true
        ]) else {
            return
        }

        let pivot = SCNNode()
        for child in scene.rootNode.childNodes {
            pivot.addChildNode(child)
        }

        // Apply forward/backward tilt. SCNNode.eulerAngles uses
        // platform-native CGFloat; the conversion below keeps it portable.
        pivot.eulerAngles.x = CGFloat(config.tiltX) * .pi / 180

        // Filter case meshes unless `showFullModel` is on.
        if config.hideCase && !config.showFullModel {
            Self.hideCaseMeshes(
                in: pivot,
                tight: config.tightCrop,
                positionCutFrac: config.filterPositionCut,
                areaCutFrac: config.filterAreaCut
            )
        }

        // Re-measure bbox after removal so framing is correct.
        let (minVec, maxVec) = pivot.boundingBox
        let centerX = (minVec.x + maxVec.x) / 2
        let centerY = (minVec.y + maxVec.y) / 2 - CGFloat(config.yShift)
        let centerZ = (minVec.z + maxVec.z) / 2
        pivot.pivot = SCNMatrix4MakeTranslation(centerX, centerY, centerZ)

        let working = SCNScene()
        working.rootNode.addChildNode(pivot)

        let extents = SCNVector3(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )
        let largest = max(extents.x, max(extents.y, extents.z))
        if largest > 0 {
            // Base sizing target — multiplied by config.zoom so the user's
            // slider takes effect.
            let baseTarget: CGFloat = config.tightCrop ? 1.0 : (config.hideCase ? 1.55 : 1.35)
            let scale = (baseTarget * config.zoom) / CGFloat(largest)
            pivot.scale = SCNVector3(scale, scale, scale)
        }

        // Camera
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = false
        cam.fieldOfView = config.cameraFOV
        camNode.camera = cam
        camNode.position = SCNVector3(0, Float(config.cameraY), Float(config.cameraZ))
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

        // Rotation animation.
        let sign: CGFloat = config.rotationReversed ? 1 : -1
        let spin = SCNAction.rotateBy(
            x: 0,
            y: sign * CGFloat.pi * 2,
            z: 0,
            duration: max(0.5, config.rotationSeconds)
        )
        pivot.runAction(SCNAction.repeatForever(spin))

        view.scene = working
        view.pointOfView = camNode

        context.coordinator.loadedURL = url
        context.coordinator.config = config
    }

    /// Removes the charging-case meshes by horizontal footprint, keeping
    /// the bud-and-stem mesh intact. See AirPods3DView documentation for
    /// the full rationale.
    private static func hideCaseMeshes(
        in root: SCNNode,
        tight: Bool,
        positionCutFrac: CGFloat,
        areaCutFrac: CGFloat
    ) {
        let leaves = collectGeometryLeaves(root)
        guard leaves.count > 1 else { return }

        struct Entry {
            let node: SCNNode
            let horizontalArea: CGFloat
            let centerY: CGFloat
        }

        let entries: [Entry] = leaves.compactMap { node in
            let (lo, hi) = node.boundingBox
            let pMin = node.convertPosition(lo, to: root)
            let pMax = node.convertPosition(hi, to: root)
            let extX = abs(CGFloat(pMax.x) - CGFloat(pMin.x))
            let extZ = abs(CGFloat(pMax.z) - CGFloat(pMin.z))
            let centerY = (CGFloat(pMin.y) + CGFloat(pMax.y)) / 2
            return Entry(node: node, horizontalArea: extX * extZ, centerY: centerY)
        }

        guard let maxArea = entries.map(\.horizontalArea).max(), maxArea > 0 else { return }
        let ys = entries.map(\.centerY)
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        let yRange = maxY - minY
        let positionCut = yRange > 0
            ? minY + yRange * positionCutFrac
            : -CGFloat.greatestFiniteMagnitude

        for entry in entries {
            let bulky = entry.horizontalArea >= maxArea * areaCutFrac
            let bottomHeavy = entry.centerY < positionCut
            if bulky && bottomHeavy {
                entry.node.removeFromParentNode()
            }
        }
    }

    private static func collectGeometryLeaves(_ node: SCNNode) -> [SCNNode] {
        var result: [SCNNode] = []
        if node.geometry != nil { result.append(node) }
        for child in node.childNodes {
            result.append(contentsOf: collectGeometryLeaves(child))
        }
        return result
    }
}
