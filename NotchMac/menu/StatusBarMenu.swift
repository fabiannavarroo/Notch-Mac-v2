//
//  StatusBarMenu.swift
//  NotchMac
//
//  Status bar (menubar) controller with NotchMac logo.
//

import Cocoa

final class BoringStatusMenu: NSObject {
    let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            // logo2 = color rainbow icon (ico.png). No template, no tinting.
            if let logo = NSImage(named: "logo2") {
                let h: CGFloat = 20
                let ratio = logo.size.width / max(logo.size.height, 1)
                let resized = NSImage(size: NSSize(width: h * ratio, height: h))
                resized.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                logo.draw(
                    in: NSRect(origin: .zero, size: resized.size),
                    from: .zero, operation: .copy, fraction: 1.0
                )
                resized.unlockFocus()
                resized.isTemplate = false
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchMac")
            }
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Abrir notch", action: #selector(toggleNotch), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func toggleNotch() {
        NotificationCenter.default.post(name: .nmToggleNotchFromMenu, object: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let nmToggleNotchFromMenu = Notification.Name("nm.toggleNotchFromMenu")
}
