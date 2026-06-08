import AppKit
import CoreImage
import Foundation

/// Persistent cache mapping wallpaper file URL → dominant RGB color.
/// Avoids re-decoding every wallpaper image on every lock.
@MainActor
final class LockScreenColorCache {
    static let shared = LockScreenColorCache()

    private struct Entry: Codable {
        let path: String
        let mtime: TimeInterval
        let r: Double
        let g: Double
        let b: Double
    }

    private var entries: [String: Entry] = [:]
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])
    private let cacheURL: URL?

    private init() {
        let fm = FileManager.default
        let support = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support?.appendingPathComponent("NotchMac", isDirectory: true)
        if let dir {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        cacheURL = dir?.appendingPathComponent("lockscreen-wallpaper-colors.json")
        load()
    }

    func color(for url: URL) -> NSColor? {
        let key = url.path
        let mtime = (try? FileManager.default.attributesOfItem(atPath: key)[.modificationDate] as? Date)?
            .timeIntervalSince1970 ?? 0

        if let cached = entries[key], abs(cached.mtime - mtime) < 0.5 {
            return NSColor(srgbRed: cached.r, green: cached.g, blue: cached.b, alpha: 1)
        }

        guard let computed = computeDominantColor(at: url) else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        computed.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)

        entries[key] = Entry(
            path: key,
            mtime: mtime,
            r: Double(r),
            g: Double(g),
            b: Double(b)
        )
        save()
        return computed
    }

    private func computeDominantColor(at url: URL) -> NSColor? {
        guard let ciImage = CIImage(contentsOf: url) else { return nil }
        let extent = ciImage.extent
        guard extent.width > 0, extent.height > 0 else { return nil }

        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: extent)
        ])
        guard let output = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
        )

        return NSColor(
            srgbRed: CGFloat(bitmap[0]) / 255.0,
            green: CGFloat(bitmap[1]) / 255.0,
            blue: CGFloat(bitmap[2]) / 255.0,
            alpha: 1
        )
    }

    private func load() {
        guard let cacheURL,
              let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = Dictionary(uniqueKeysWithValues: decoded.map { ($0.path, $0) })
    }

    private func save() {
        guard let cacheURL else { return }
        let array = Array(entries.values)
        if let data = try? JSONEncoder().encode(array) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}

/// CIE LAB distance helpers for picking nearest wallpaper by perceptual color.
enum LockScreenColorDistance {
    static func deltaE(_ lhs: NSColor, _ rhs: NSColor) -> Double {
        let a = lab(lhs)
        let b = lab(rhs)
        let dL = a.l - b.l
        let dA = a.a - b.a
        let dB = a.b - b.b
        return (dL * dL + dA * dA + dB * dB).squareRoot()
    }

    private static func lab(_ color: NSColor) -> (l: Double, a: Double, b: Double) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return (0, 0, 0) }
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, _a: CGFloat = 0
        srgb.getRed(&r, green: &g, blue: &bl, alpha: &_a)

        // sRGB → linear
        let lr = linearize(Double(r))
        let lg = linearize(Double(g))
        let lb = linearize(Double(bl))

        // linear → XYZ (D65)
        let x = lr * 0.4124564 + lg * 0.3575761 + lb * 0.1804375
        let y = lr * 0.2126729 + lg * 0.7151522 + lb * 0.0721750
        let z = lr * 0.0193339 + lg * 0.1191920 + lb * 0.9503041

        // normalize to D65 white
        let xn = x / 0.95047
        let yn = y / 1.0
        let zn = z / 1.08883

        let fx = labF(xn)
        let fy = labF(yn)
        let fz = labF(zn)

        let l = 116.0 * fy - 16.0
        let aa = 500.0 * (fx - fy)
        let bb = 200.0 * (fy - fz)
        return (l, aa, bb)
    }

    private static func linearize(_ c: Double) -> Double {
        c > 0.04045 ? pow((c + 0.055) / 1.055, 2.4) : c / 12.92
    }

    private static func labF(_ t: Double) -> Double {
        let delta = 6.0 / 29.0
        return t > pow(delta, 3) ? pow(t, 1.0 / 3.0) : (t / (3 * delta * delta) + 4.0 / 29.0)
    }
}
