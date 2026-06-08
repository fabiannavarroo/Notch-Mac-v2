import AppKit
import Foundation
import os

private let lswpLog = Logger(subsystem: "com.fabiannavarrofonte.notchmac", category: "LockScreenWallpaper")

/// Generates a solid-color PNG from the playing track's average color and sets
/// it as the desktop image. Works like the "Colores" section of System
/// Settings → Wallpaper but the color is picked per-song from
/// `MusicManager.avgColor`. Original wallpaper is saved at lock and restored
/// on unlock.
@MainActor
final class LockScreenWallpaperManager {
    static let shared = LockScreenWallpaperManager()

    private var originalWallpaperURL: URL?
    private var lastAppliedColorKey: String?
    private let storageDir: URL = {
        let fm = FileManager.default
        let support = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = support.appendingPathComponent("NotchMac/SongColorWallpapers", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {}

    /// No-op now — kept so the coordinator's existing call site stays valid.
    /// Color wallpapers are generated on demand, no catalog to scan.
    func prewarmCatalog() {}

    func snapshotOriginalIfNeeded() {
        guard originalWallpaperURL == nil, let screen = NSScreen.main else { return }
        let current = NSWorkspace.shared.desktopImageURL(for: screen)
        // Don't snapshot one of our own generated PNGs as "original".
        if let current, current.path.hasPrefix(storageDir.path) {
            lswpLog.notice("snapshot skipped: current is our own generated wallpaper")
            return
        }
        originalWallpaperURL = current
        lswpLog.notice("snapshot original: \(current?.path ?? "nil", privacy: .public)")
    }

    /// Render a solid-color PNG for `color` and set it as the desktop image.
    /// Idempotent on identical color (quantised to 1/255 per channel).
    func applyMatchingWallpaper(for color: NSColor) {
        guard let screen = NSScreen.main else {
            lswpLog.error("apply: NSScreen.main = nil")
            return
        }

        let key = colorKey(color)
        guard key != lastAppliedColorKey else {
            lswpLog.notice("apply: color \(key, privacy: .public) already applied")
            return
        }

        let pixelSize = pixelSizeForScreen(screen)
        let fileURL = storageDir.appendingPathComponent("song-color-\(key).png")

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            guard renderSolidPNG(color: color, size: pixelSize, to: fileURL) else {
                lswpLog.error("apply: failed to render PNG for \(key, privacy: .public)")
                return
            }
        }

        do {
            try NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [:])
            lastAppliedColorKey = key
            lswpLog.notice("APPLIED color \(key, privacy: .public) -> \(fileURL.path, privacy: .public)")
        } catch {
            lswpLog.error("setDesktopImageURL failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func restoreOriginal() {
        defer {
            originalWallpaperURL = nil
            lastAppliedColorKey = nil
        }
        guard let originalWallpaperURL, let screen = NSScreen.main else {
            lswpLog.notice("restore: no original snapshot")
            return
        }
        do {
            try NSWorkspace.shared.setDesktopImageURL(originalWallpaperURL, for: screen, options: [:])
            lswpLog.notice("restore: \(originalWallpaperURL.path, privacy: .public)")
        } catch {
            lswpLog.error("restore failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    /// Stable, filesystem-safe identifier for a color: 6-char hex of sRGB
    /// 8-bit components. Means two songs with identical dominant color reuse
    /// the same generated PNG (no flicker, no duplicate files).
    private func colorKey(_ color: NSColor) -> String {
        guard let srgb = color.usingColorSpace(.sRGB) else { return "ffffff" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }

    /// Pick a sensible pixel size for the screen — backing scale * points,
    /// capped so we don't allocate huge bitmaps.
    private func pixelSizeForScreen(_ screen: NSScreen) -> CGSize {
        let scale = screen.backingScaleFactor
        let w = min(screen.frame.width * scale, 3840)
        let h = min(screen.frame.height * scale, 2400)
        return CGSize(width: w, height: h)
    }

    /// Render a solid-color PNG file at `url`. Uses CGContext directly so the
    /// resulting file's color space is sRGB and matches what wallpaper
    /// rendering expects.
    private func renderSolidPNG(color: NSColor, size: CGSize, to url: URL) -> Bool {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else { return false }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return false }

        let srgb = color.usingColorSpace(.sRGB) ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        // Dim the raw avgColor so the wallpaper reads as a muted, moody tone
        // rather than a vivid color block. 0.55× keeps the hue identifiable
        // while killing the eye-watering saturation.
        let dim: CGFloat = 0.55
        ctx.setFillColor(red: r * dim, green: g * dim, blue: b * dim, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let cgImage = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(
                url as CFURL,
                "public.png" as CFString,
                1,
                nil
              ) else { return false }

        CGImageDestinationAddImage(dest, cgImage, nil)
        return CGImageDestinationFinalize(dest)
    }
}
