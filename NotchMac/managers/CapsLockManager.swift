//
//  CapsLockManager.swift
//  NotchMac
//
//  Ported from upstream PR boring.notch#1246 (Lucas Walker, 2026-05-11).
//

import AppKit
import Combine
import Foundation

@MainActor
final class CapsLockManager: ObservableObject {
    static let shared = CapsLockManager()

    @Published private(set) var isOn: Bool = false

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {
        isOn = NSEvent.modifierFlags.contains(.capsLock)

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.update(from: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.update(from: event)
            return event
        }
    }

    nonisolated private func update(from event: NSEvent) {
        let newValue = event.modifierFlags.contains(.capsLock)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.isOn != newValue {
                self.isOn = newValue
            }
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
