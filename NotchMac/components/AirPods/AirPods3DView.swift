//
//  AirPods3DView.swift
//  NotchMac
//
//  SceneKit-backed view that auto-rotates the AirPods USDZ on the Y axis.
//  Renders nothing while the asset is still downloading and falls back to
//  the matching SF Symbol if the download permanently fails.
//
//  `hideCase` filters out leaf meshes whose worldspace center lies in the
//  bottom portion of the model — works because Apple's AR USDZ for AirPods
//  and AirPods Pro stacks the charging case underneath the buds. Has no
//  visible effect on AirPods Max (no case mesh exists).
//

import SceneKit
import SwiftUI

struct AirPods3DView: View {
    let variant: AirPodsModelVariant
    var size: CGFloat = 88
    var rotationSpeed: Double = 8 // seconds per full Y rotation
    /// When true, drops the charging case mesh so only the earbuds spin.
    var hideCase: Bool = false
    /// Aggressive variant of `hideCase`: tighter Y threshold + filters out
    /// nodes whose vertical extent dominates the model (the case body).
    var tightCrop: Bool = false
    /// Optional zoom override. If nil, the view picks a default based on
    /// `hideCase` / `tightCrop`. Values < 1 zoom out, > 1 zoom in. Pass a
    /// number when you want to fine-tune sizing from the parent view.
    var zoomOverride: CGFloat? = nil

    @ObservedObject private var loader = AirPodsAssetLoader.shared

    var body: some View {
        ZStack {
            if let url = loader.cachedURL(for: variant) {
                AirPods3DSceneView(
                    url: url,
                    rotationSpeed: rotationSpeed,
                    hideCase: hideCase,
                    tightCrop: tightCrop,
                    zoomOverride: zoomOverride
                )
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
    let hideCase: Bool
    let tightCrop: Bool
    let zoomOverride: CGFloat?

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
        // Swap the model if the URL or mode changes.
        if context.coordinator.loadedURL != url
            || context.coordinator.hidCase != hideCase
            || context.coordinator.tight != tightCrop
        {
            configureScene(nsView, context: context)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedURL: URL?
        var hidCase: Bool = false
        var tight: Bool = false
    }

    private func configureScene(_ view: SCNView, context: Context) {
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

        // Optionally drop the charging-case mesh by Y position.
        if hideCase {
            Self.hideCaseMeshes(in: pivot, tight: tightCrop)
        }

        // Re-measure bounding box after hiding so the buds frame nicely.
        let (minVec, maxVec) = pivot.boundingBox
        let center = SCNVector3(
            (minVec.x + maxVec.x) / 2,
            (minVec.y + maxVec.y) / 2,
            (minVec.z + maxVec.z) / 2
        )
        pivot.pivot = SCNMatrix4MakeTranslation(center.x, center.y, center.z)

        let working = SCNScene()
        working.rootNode.addChildNode(pivot)

        let extents = SCNVector3(
            maxVec.x - minVec.x,
            maxVec.y - minVec.y,
            maxVec.z - minVec.z
        )
        let largest = max(extents.x, max(extents.y, extents.z))
        if largest > 0 {
            // Conservative zoom in tightCrop (closed-notch sneak) so the
            // buds never clip on the wide rotation cycles. Other modes can
            // zoom further because they live inside the open notch.
            let defaultTarget: CGFloat = tightCrop ? 0.85 : (hideCase ? 1.55 : 1.35)
            let target = zoomOverride ?? defaultTarget
            let scale = target / CGFloat(largest)
            pivot.scale = SCNVector3(scale, scale, scale)
        }

        // Camera — pulled further back in full-case mode so the lid arc
        // doesn't clip when the model rotates.
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = false
        cam.fieldOfView = 28
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0.05, hideCase ? 3.2 : 3.6)
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

        // Rotation animation (clockwise from above, matches iOS connect popup).
        let spin = SCNAction.rotateBy(x: 0, y: -CGFloat.pi * 2, z: 0, duration: rotationSpeed)
        pivot.runAction(SCNAction.repeatForever(spin))

        view.scene = working
        view.pointOfView = camNode

        context.coordinator.loadedURL = url
        context.coordinator.hidCase = hideCase
        context.coordinator.tight = tightCrop
    }

    /// Removes the charging-case meshes while keeping every bud-and-stem
    /// mesh intact. Apple's AR USDZ encodes AirPods Pro stems as a single
    /// tall narrow mesh per bud — so the previous Y-extent filter dropped
    /// the stem along with the case, which is what the user kept seeing.
    ///
    /// New strategy: rank meshes by *horizontal volume* (extentX × extentZ).
    /// The case body is the only chunky cuboid in the model; buds and stems
    /// are narrow regardless of how tall they are. Drop the meshes whose
    /// horizontal footprint exceeds a fraction of the largest leaf's
    /// footprint. Falls back gracefully if the model is single-mesh.
    private static func hideCaseMeshes(in root: SCNNode, tight: Bool) {
        let leaves = collectGeometryLeaves(root)
        guard leaves.count > 1 else { return }

        struct Entry {
            let node: SCNNode
            /// X × Z extent in root coordinates. Buds + stems are tall but
            /// narrow → small horizontal footprint. Case body is bulky.
            let horizontalArea: CGFloat
            let centerY: CGFloat
        }

        let entries: [Entry] = leaves.compactMap { node in
            let (lo, hi) = node.boundingBox
            // Worldspace bbox corners.
            let pMin = node.convertPosition(lo, to: root)
            let pMax = node.convertPosition(hi, to: root)
            let extX = abs(CGFloat(pMax.x) - CGFloat(pMin.x))
            let extZ = abs(CGFloat(pMax.z) - CGFloat(pMin.z))
            let centerY = (CGFloat(pMin.y) + CGFloat(pMax.y)) / 2
            return Entry(node: node, horizontalArea: extX * extZ, centerY: centerY)
        }

        // The biggest horizontal footprint sets the baseline. Anything
        // close to it is the case.
        guard let maxArea = entries.map(\.horizontalArea).max(), maxArea > 0 else { return }
        // tight mode is more aggressive in case Apple ships an asset that
        // splits the case body into smaller chunks.
        let areaCut: CGFloat = tight ? 0.30 : 0.45

        // Also keep the legacy position cut as a fallback for assets that
        // don't separate case + buds horizontally (e.g. AirPods Max).
        let ys = entries.map(\.centerY)
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        let yRange = maxY - minY
        let positionCut = yRange > 0
            ? minY + yRange * (tight ? 0.50 : 0.25)
            : -CGFloat.greatestFiniteMagnitude

        for entry in entries {
            let bulky = entry.horizontalArea >= maxArea * areaCut
            let bottomHeavy = entry.centerY < positionCut
            // Drop only meshes that are *both* bulky horizontally *and*
            // sit in the lower half. Tall-narrow stems are bulky in Y but
            // narrow in X×Z, so they survive.
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
