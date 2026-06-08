//
//  BoringNotchWindow.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 06/08/24.
//

import Cocoa

/// A notch panel that can be temporarily allowed to become the key window so
/// embedded text fields (e.g. the PDF chat input) can receive focus and typing.
/// The notch is normally non-key to avoid stealing focus on hover; views opt in
/// by flipping `allowsKeyboardActivation` only while they need keyboard input.
protocol KeyboardActivatablePanel: NSPanel {
    var allowsKeyboardActivation: Bool { get set }
}

class BoringNotchWindow: NSPanel, KeyboardActivatablePanel {
    var allowsKeyboardActivation: Bool = false

    override init(
        contentRect: NSRect,
        styleMask: NSWindow.StyleMask,
        backing: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: backing,
            defer: flag
        )
        
        isFloatingPanel = true
        isOpaque = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        backgroundColor = .clear
        isMovable = false
        
        collectionBehavior = [
            .fullScreenAuxiliary,
            .stationary,
            .canJoinAllSpaces,
            .ignoresCycle,
        ]
        
        isReleasedWhenClosed = false
        level = .mainMenu + 3
        hasShadow = false
    }
    
    override var canBecomeKey: Bool {
        allowsKeyboardActivation
    }

    override var canBecomeMain: Bool {
        false
    }
}
