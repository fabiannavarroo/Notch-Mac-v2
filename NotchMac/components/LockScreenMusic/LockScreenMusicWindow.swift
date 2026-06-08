import AppKit
import SwiftUI

/// Full-screen, click-through (except over the widget) panel that hosts the
/// lock-screen music UI. Reuses `BoringNotchSkyLightWindow` so the existing
/// SkyLight delegation path makes it visible while macOS is locked.
final class LockScreenMusicOverlayWindow: BoringNotchSkyLightWindow {
    // No additional overrides — the click-through behavior lives in
    // `LockScreenMusicHitTestView` which wraps the SwiftUI hosting view.
}

/// NSView that forwards hit tests only when the point falls inside the
/// reported widget bounds. Lets the password field / Touch ID prompt remain
/// reachable on the rest of the screen because we return nil → AppKit
/// considers our window transparent to the event at that location.
final class LockScreenMusicHitTestView: NSView {
    /// Frame of the interactive widget in this view's coordinate space.
    /// Updated from SwiftUI via a PreferenceKey.
    var interactiveRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard interactiveRect != .zero, interactiveRect.contains(point) else {
            return nil
        }
        return super.hitTest(point)
    }
}
