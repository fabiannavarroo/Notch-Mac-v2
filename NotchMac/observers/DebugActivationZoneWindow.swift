//
//  DebugActivationZoneWindow.swift
//  NotchMac
//
//  Ventana transparente click-through que muestra la zona de activación
//  del hover oculto. Solo visible cuando showHiddenZoneDebug == true.
//

import Cocoa
import SwiftUI

final class DebugActivationZoneWindow: NSWindow {

    init(region: CGRect) {
        super.init(
            contentRect: region,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isReleasedWhenClosed = false

        let host = NSHostingView(rootView: DebugZoneOverlayView())
        host.frame = CGRect(origin: .zero, size: region.size)
        contentView = host
    }

    // Call this to reposition when width/height settings change.
    @MainActor
    func reposition(to region: CGRect) {
        setFrame(region, display: true)
        contentView?.frame = CGRect(origin: .zero, size: region.size)
    }
}

private struct DebugZoneOverlayView: View {
    var body: some View {
        ZStack {
            // Semi-transparent fill
            Color.orange.opacity(0.25)
            // Dashed border
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .foregroundColor(.orange)
            // Label
            VStack(spacing: 2) {
                Text("Zona activación oculto")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(.orange)
            }
        }
    }
}
