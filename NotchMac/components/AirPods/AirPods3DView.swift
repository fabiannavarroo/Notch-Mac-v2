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

    @ObservedObject private var loader = AirPodsAssetLoader.shared

    var body: some View {
        ZStack {
            if let url = loader.cachedURL(for: variant) {
                AirPods3DSceneView(
                    url: url,
                    rotationSpeed: rotationSpeed,
                    hideCase: hideCase,
                    tightCrop: tightCrop
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
            // Once the case is hidden the model is tiny, so zoom hard.
            let target: CGFloat = tightCrop ? 1.85 : (hideCase ? 1.55 : 1.7)
            let scale = target / CGFloat(largest)
            pivot.scale = SCNVector3(scale, scale, scale)
        }

        // Camera
        let camNode = SCNNode()
        let cam = SCNCamera()
        cam.usesOrthographicProjection = false
        cam.fieldOfView = 28
        camNode.camera = cam
        camNode.position = SCNVector3(0, 0.05, 3.2)
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

    /// Walks the imported hierarchy and hides geometry that belongs to the
    /// charging case. Two passes:
    ///   1. Y-position: drop any mesh whose bbox center sits in the bottom
    ///      portion of the model (45 % default, 62 % when `tight`).
    ///   2. Y-extent: drop meshes whose vertical span exceeds ~35 % of the
    ///      whole model — the case body + lid are tall, the buds are small.
    /// Combined this guarantees only the earbud meshes survive for closed-
    /// notch live activities, where any lid sliver looks awful at 22 pt.
    private static func hideCaseMeshes(in root: SCNNode, tight: Bool) {
        let leaves = collectGeometryLeaves(root)
        guard !leaves.isEmpty else { return }

        struct Entry {
            let node: SCNNode
            let centerY: CGFloat
            let extentY: CGFloat
        }

        let entries: [Entry] = leaves.compactMap { node in
            let (lo, hi) = node.boundingBox
            let local = SCNVector3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
            let worldCenter = node.convertPosition(local, to: root)
            // Approximate worldspace Y extent by transforming the bbox edges.
            let bottomLocal = SCNVector3((lo.x + hi.x) / 2, lo.y, (lo.z + hi.z) / 2)
            let topLocal    = SCNVector3((lo.x + hi.x) / 2, hi.y, (lo.z + hi.z) / 2)
            let bottomWorld = node.convertPosition(bottomLocal, to: root)
            let topWorld    = node.convertPosition(topLocal, to: root)
            let extent = abs(CGFloat(topWorld.y) - CGFloat(bottomWorld.y))
            return Entry(node: node, centerY: CGFloat(worldCenter.y), extentY: extent)
        }

        let ys = entries.map { $0.centerY }
        guard let minY = ys.min(), let maxY = ys.max(), maxY > minY else { return }
        let totalRange = maxY - minY
        // Closed-notch (tight) drops the bottom 70 % outright and limits any
        // surviving mesh to ≤ 22 % vertical span — buds are tiny, case body
        // + lid + hinge all sit above that.
        let positionCut = minY + totalRange * (tight ? 0.70 : 0.45)
        let extentLimit = totalRange * (tight ? 0.22 : 0.45)

        for entry in entries {
            // Bottom-half meshes → case body.
            if entry.centerY < positionCut {
                entry.node.isHidden = true
                continue
            }
            // Tall meshes (vertical span dominates) → case lid / hinge that
            // extends from the case all the way up to bud height.
            if entry.extentY > extentLimit {
                entry.node.isHidden = true
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
