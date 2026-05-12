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
            // logo = white minimal toolbar logo (tool-bar.png) engrosado, template para tinte sistema.
            if let logo = NSImage(named: "logo") {
                let h: CGFloat = 20
                let ratio = logo.size.width / max(logo.size.height, 1)
                let resized = NSImage(size: NSSize(width: h * ratio, height: h))
                resized.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                logo.draw(
                    in: NSRect(origin: .zero, size: resized.size),
                    from: .zero, operation: .sourceOver, fraction: 1.0
                )
                resized.unlockFocus()
                resized.isTemplate = true
                button.image = resized
            } else {
                button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "NotchMac")
            }
        }

        let menu = NSMenu()
        let toggle = menu.addItem(withTitle: "Abrir / cerrar notch", action: #selector(toggleNotch), keyEquivalent: "")
        toggle.target = self
        menu.addItem(.separator())
        let settings = menu.addItem(withTitle: "Preferencias…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        let restart = menu.addItem(withTitle: "Reiniciar NotchMac", action: #selector(restart), keyEquivalent: "")
        restart.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Salir", action: #selector(self.quit), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    @objc private func toggleNotch() {
        NotificationCenter.default.post(name: .nmToggleNotchFromMenu, object: nil)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.showWindow()
    }

    @objc private func restart() {
        ApplicationRelauncher.restart()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let nmToggleNotchFromMenu = Notification.Name("nm.toggleNotchFromMenu")
}
