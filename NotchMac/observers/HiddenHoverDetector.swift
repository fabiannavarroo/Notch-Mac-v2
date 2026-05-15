//
//  HiddenHoverDetector.swift
//  NotchMac
//
//  Detecta el cursor entrando en la zona del notch mientras la isla está
//  oculta (Opt+X o auto-hide) para reaparecer y abrirla en modo expandido.
//

import Cocoa

final class HiddenHoverDetector {
    typealias VoidCallback = () -> Void

    var onHover: VoidCallback?

    private let region: CGRect
    private var monitor: Any?
    private var armed: Bool = false

    init(notchRegion: CGRect) {
        self.region = notchRegion
    }

    func start() {
        stop()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            if self.region.contains(mouse) {
                if !self.armed {
                    self.armed = true
                    self.onHover?()
                }
            } else {
                self.armed = false
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        armed = false
    }

    deinit { stop() }
}
