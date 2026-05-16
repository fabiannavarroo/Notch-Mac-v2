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
    /// If true, a mesh is dropped if EITHER criterion matches (catches the
    /// LED pill + hinge bar). If false, both must match.
    var filterStrict: Bool = true

    static let `default` = AirPodsRenderConfig()

    /// Builds a config from a variant-specific tuning struct. Settings
    /// sliders write into the variant's tuning, so this returns fresh
    /// values every render automatically.
    static func from(
        _ tuning: AirPodsTuning,
        hideCase: Bool,
        tightCrop: Bool,
        rotationSpeed: Double? = nil
    ) -> AirPodsRenderConfig {
        AirPodsRenderConfig(
            rotationSeconds: rotationSpeed ?? tuning.rotationSeconds,
            rotationReversed: tuning.rotationReversed,
            hideCase: hideCase,
            tightCrop: tightCrop,
            showFullModel: tuning.showFullModel,
            zoom: CGFloat(tuning.modelZoom),
            tiltX: CGFloat(tuning.modelTiltX),
            yShift: CGFloat(tuning.modelYShift),
            cameraZ: CGFloat(tuning.cameraZ),
            cameraY: CGFloat(tuning.cameraY),
            cameraFOV: CGFloat(tuning.cameraFOV),
            filterPositionCut: CGFloat(tuning.filterPositionCut),
            filterAreaCut: CGFloat(tuning.filterAreaCut),
            filterStrict: tuning.filterStrict
        )
    }

    /// Same idea but reads the dashboard-specific tuning fields. The
    /// expanded view shows the full case so `hideCase` defaults to false
    /// (unless the user toggles `dashboardShowFullModel` off, in which
    /// case the case filter applies with the variant's mini settings).
    static func dashboard(_ tuning: AirPodsTuning) -> AirPodsRenderConfig {
        let hideCase = !tuning.dashboardShowFullModel
        return AirPodsRenderConfig(
            rotationSeconds: tuning.dashboardRotationSeconds,
            rotationReversed: tuning.rotationReversed,
            hideCase: hideCase,
            tightCrop: false,
            showFullModel: tuning.dashboardShowFullModel,
            zoom: CGFloat(tuning.dashboardModelZoom),
            tiltX: CGFloat(tuning.dashboardModelTiltX),
            yShift: CGFloat(tuning.modelYShift),
            cameraZ: CGFloat(tuning.dashboardCameraZ),
            cameraY: CGFloat(tuning.dashboardCameraY),
            cameraFOV: CGFloat(tuning.dashboardCameraFOV),
            filterPositionCut: CGFloat(tuning.filterPositionCut),
            filterAreaCut: CGFloat(tuning.filterAreaCut),
            filterStrict: tuning.filterStrict
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

    // Observe every variant's tuning so SwiftUI re-runs body when sliders
    // change anywhere. `resolvedConfig` then picks the right struct.
    @Default(.airPodsTuningRegular) private var tuningRegular
    @Default(.airPodsTuningANC)     private var tuningANC
    @Default(.airPodsTuningPro)     private var tuningPro
    @Default(.airPodsTuningMax)     private var tuningMax

    private var currentTuning: AirPodsTuning {
        switch variant {
        case .airPods:    return tuningRegular
        case .airPodsANC: return tuningANC
        case .airPodsPro: return tuningPro
        case .airPodsMax: return tuningMax
        }
    }

    private var resolvedConfig: AirPodsRenderConfig {
        if let c = config { return c }
        var c = AirPodsRenderConfig.from(
            currentTuning,
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
        let coord = context.coordinator
        let prev = coord.config

        // Geometry-affecting changes require rebuilding the scene because
        // we have to re-import + re-filter meshes. Everything else can be
        // tweaked incrementally on the live scene so the rotation keeps
        // spinning smoothly while the user drags sliders.
        let geometryChanged =
            coord.loadedURL != url
            || prev.hideCase != config.hideCase
            || prev.tightCrop != config.tightCrop
            || prev.showFullModel != config.showFullModel
            || prev.filterPositionCut != config.filterPositionCut
            || prev.filterAreaCut != config.filterAreaCut
            || prev.filterStrict != config.filterStrict

        if geometryChanged || coord.pivotNode == nil {
            configureScene(nsView, context: context)
            return
        }

        if prev != config {
            applyLiveTweaks(coord: coord, oldConfig: prev)
            coord.config = config
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
        var config: AirPodsRenderConfig = .default
        weak var pivotNode: SCNNode?
        weak var cameraNode: SCNNode?
        weak var camera: SCNCamera?
        /// Cached "largest extent" so we can rescale on zoom changes
        /// without re-measuring the bounding box every drag tick.
        var baseLargestExtent: CGFloat = 1
    }

    private func applyLiveTweaks(coord: Coordinator, oldConfig: AirPodsRenderConfig) {
        // Camera
        if let cam = coord.camera, oldConfig.cameraFOV != config.cameraFOV {
            cam.fieldOfView = config.cameraFOV
        }
        if let camNode = coord.cameraNode,
           oldConfig.cameraY != config.cameraY || oldConfig.cameraZ != config.cameraZ {
            camNode.position = SCNVector3(0, Float(config.cameraY), Float(config.cameraZ))
        }
        // Pivot transform (zoom + tilt + Y shift)
        if let pivot = coord.pivotNode {
            if oldConfig.zoom != config.zoom {
                let baseTarget: CGFloat = config.tightCrop ? 1.0 : (config.hideCase ? 1.55 : 1.35)
                let s = (baseTarget * config.zoom) / max(coord.baseLargestExtent, 0.0001)
                pivot.scale = SCNVector3(s, s, s)
            }
            if oldConfig.tiltX != config.tiltX {
                pivot.eulerAngles.x = CGFloat(config.tiltX) * .pi / 180
            }
            if oldConfig.yShift != config.yShift {
                let m = pivot.pivot
                pivot.pivot = SCNMatrix4(
                    m11: m.m11, m12: m.m12, m13: m.m13, m14: m.m14,
                    m21: m.m21, m22: m.m22, m23: m.m23, m24: m.m24,
                    m31: m.m31, m32: m.m32, m33: m.m33, m34: m.m34,
                    m41: m.m41,
                    m42: m.m42 - CGFloat(config.yShift - oldConfig.yShift),
                    m43: m.m43, m44: m.m44
                )
            }
            // Rotation — replace the running action if speed or direction
            // changed; otherwise leave it spinning to avoid jitter.
            if oldConfig.rotationSeconds != config.rotationSeconds
                || oldConfig.rotationReversed != config.rotationReversed
            {
                pivot.removeAllActions()
                let sign: CGFloat = config.rotationReversed ? 1 : -1
                let spin = SCNAction.rotateBy(
                    x: 0,
                    y: sign * CGFloat.pi * 2,
                    z: 0,
                    duration: max(0.5, config.rotationSeconds)
                )
                pivot.runAction(SCNAction.repeatForever(spin))
            }
        }
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
                positionCutFrac: config.filterPositionCut,
                areaCutFrac: config.filterAreaCut,
                strict: config.filterStrict
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
        context.coordinator.baseLargestExtent = CGFloat(largest)

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
        context.coordinator.pivotNode = pivot
        context.coordinator.cameraNode = camNode
        context.coordinator.camera = cam
    }

    /// Removes case meshes. Strict mode drops a mesh if EITHER criterion
    /// matches — that's what catches the small LED pill and the metal
    /// hinge bar that the lenient AND check used to miss. The position
    /// check uses worldspace Y center; the area check compares horizontal
    /// footprint against the bulkiest leaf.
    private static func hideCaseMeshes(
        in root: SCNNode,
        positionCutFrac: CGFloat,
        areaCutFrac: CGFloat,
        strict: Bool
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
            let drop = strict ? (bulky || bottomHeavy) : (bulky && bottomHeavy)
            if drop {
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
