//
//  AirPodsAssetLoader.swift
//  NotchMac
//
//  Downloads Apple's official AR USDZ assets for AirPods variants on first
//  use and caches them under ~/Library/Caches/NotchMac/airpods/. This avoids
//  redistributing Apple-owned assets inside the app bundle while still giving
//  the same model SceneKit can render. URLs are pinned to the public
//  apple.com AR-QuickLook endpoints (last verified Sep 2025).
//

import Foundation

enum AirPodsModelVariant: String, CaseIterable {
    case airPods         // AirPods 4 (entry / no ANC)
    case airPodsANC      // AirPods 4 con ANC
    case airPodsPro      // AirPods Pro 2
    case airPodsMax      // AirPods Max

    var remoteURL: URL {
        switch self {
        case .airPods:
            return URL(string: "https://www.apple.com/105/media/us/airpods-4/2024/62a51629-9227-413a-98ae-ba9e09984c00/ar/airpods-entry.usdz")!
        case .airPodsANC:
            return URL(string: "https://www.apple.com/105/media/us/airpods-4/2024/62a51629-9227-413a-98ae-ba9e09984c00/ar/airpods-mid.usdz")!
        case .airPodsPro:
            return URL(string: "https://www.apple.com/105/media/us/airpods-pro/2025/7acffb13-4adb-40b1-9393-8f1c99bc6c90/ar/airpods-pro.usdz")!
        case .airPodsMax:
            return URL(string: "https://www.apple.com/105/media/us/airpods-max/2024/e8f376d6-82b2-40ca-8a22-5f87de755d6b/ar/airpods-max-midnight.usdz")!
        }
    }

    var cacheFileName: String {
        switch self {
        case .airPods:     return "airpods.usdz"
        case .airPodsANC:  return "airpods-anc.usdz"
        case .airPodsPro:  return "airpods-pro.usdz"
        case .airPodsMax:  return "airpods-max.usdz"
        }
    }
}

@MainActor
final class AirPodsAssetLoader: ObservableObject {
    static let shared = AirPodsAssetLoader()

    @Published private(set) var localURLs: [AirPodsModelVariant: URL] = [:]
    @Published private(set) var inFlight: Set<AirPodsModelVariant> = []

    private let session: URLSession
    private let cacheDir: URL

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: cfg)

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCache = caches.appendingPathComponent("NotchMac/airpods", isDirectory: true)
        try? FileManager.default.createDirectory(at: appCache, withIntermediateDirectories: true)
        self.cacheDir = appCache

        // Pre-populate local URLs for already-cached files so views can render
        // without waiting on a network round trip on every launch.
        for variant in AirPodsModelVariant.allCases {
            let local = cacheDir.appendingPathComponent(variant.cacheFileName)
            if FileManager.default.fileExists(atPath: local.path) {
                localURLs[variant] = local
            }
        }
    }

    func cachedURL(for variant: AirPodsModelVariant) -> URL? {
        localURLs[variant]
    }

    /// Downloads the variant if not yet cached. Idempotent and safe to call
    /// repeatedly — subsequent invocations short-circuit to the cached URL.
    func ensureDownloaded(_ variant: AirPodsModelVariant) async -> URL? {
        if let url = localURLs[variant] { return url }
        if inFlight.contains(variant) { return nil }
        inFlight.insert(variant)
        defer { inFlight.remove(variant) }

        let dest = cacheDir.appendingPathComponent(variant.cacheFileName)
        do {
            let (tmp, response) = try await session.download(from: variant.remoteURL)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                NSLog("[AirPodsAssetLoader] HTTP error fetching \(variant.remoteURL)")
                try? FileManager.default.removeItem(at: tmp)
                return nil
            }
            if FileManager.default.fileExists(atPath: dest.path) {
                try? FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: tmp, to: dest)
            await MainActor.run { self.localURLs[variant] = dest }
            return dest
        } catch {
            NSLog("[AirPodsAssetLoader] download failed for \(variant): \(error)")
            return nil
        }
    }

    /// Convenience used by the 3D view to fire-and-forget while it shows a
    /// placeholder. Once the download completes the view picks up the URL via
    /// @ObservedObject -> localURLs.
    func prefetch(_ variant: AirPodsModelVariant) {
        guard localURLs[variant] == nil, !inFlight.contains(variant) else { return }
        Task { _ = await ensureDownloaded(variant) }
    }
}
