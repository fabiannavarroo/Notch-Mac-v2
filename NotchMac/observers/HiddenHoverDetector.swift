//
//  HiddenHoverDetector.swift
//  NotchMac
//
//  Detecta el cursor entrando en la zona del notch mientras la isla está
//  oculta (Opt+X o auto-hide). Usa un Timer 60Hz contra NSEvent.mouseLocation
//  en vez de un monitor global de eventos (que no recibe mouseMoved fiable
//  sin Accessibility) para que siempre funcione.
//

import Cocoa

final class HiddenHoverDetector {
    typealias VoidCallback = () -> Void

    var onHover: VoidCallback?

    private let region: CGRect
    private var timer: Timer?
    private var armed: Bool = false

    init(notchRegion: CGRect) {
        self.region = notchRegion
    }

    func start() {
        stop()
        // Poll cada ~16ms (60Hz) — barato y no necesita permisos.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            if self.region.contains(mouse) {
                if !self.armed {
                    self.armed = true
                    DispatchQueue.main.async { self.onHover?() }
                }
            } else if !self.region.insetBy(dx: -40, dy: -40).contains(mouse) {
                // Sólo desarmamos cuando salimos con margen, para evitar rebotes.
                self.armed = false
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        armed = false
    }

    deinit { stop() }
}
