//
//  AirPodsTuning.swift
//  NotchMac
//
//  Per-variant rendering + layout knobs for the AirPods live activity.
//  Stored as one Defaults key per variant so each AirPods model (regular,
//  ANC, Pro, Max) carries its own visual config. The debug settings panel
//  binds to the struct corresponding to the variant currently being
//  previewed; the closed-notch view picks the struct that matches the
//  variant actually connected.
//

import Defaults
import Foundation

struct AirPodsTuning: Codable, Equatable, Defaults.Serializable {
    // Closed-notch tile layout
    var artWidthMultiplier: Double = 1.9
    var artSidePadding:     Double = 10.0
    var artLeftShift:       Double = -14.0
    var modelZoom:          Double = 0.85

    // Battery ring
    var ringDiameter:       Double = 22.0
    var ringStrokeWidth:    Double = 3.0
    var ringSidePadding:    Double = 14.0
    var ringTextScale:      Double = 0.42

    // 3D render
    var showFullModel:      Bool   = false
    var modelTiltX:         Double = 0.0
    var modelYShift:        Double = 0.0
    var cameraZ:            Double = 3.2
    var cameraY:            Double = 0.05
    var cameraFOV:          Double = 28.0
    var rotationSeconds:    Double = 5.0
    var rotationReversed:   Bool   = false

    // Case filter
    var filterPositionCut:  Double = 0.50
    var filterAreaCut:      Double = 0.30
    var filterStrict:       Bool   = true

    // Dashboard (expanded, open-notch) tuning — independent from the
    // closed-notch mini so each surface can be dialled in separately.
    var dashboardTileSize:        Double = 118.0
    var dashboardModelZoom:       Double = 1.35
    var dashboardModelTiltX:      Double = 0.0
    var dashboardCameraZ:         Double = 3.6
    var dashboardCameraY:         Double = 0.05
    var dashboardCameraFOV:       Double = 28.0
    var dashboardRotationSeconds: Double = 7.0
    var dashboardShowFullModel:   Bool   = true
}

enum AirPodsTuningStore {
    /// Returns the Defaults key for the given variant. The settings panel
    /// uses this to read+write the active variant's struct in place.
    static func key(for variant: AirPodsModelVariant) -> Defaults.Key<AirPodsTuning> {
        switch variant {
        case .airPods:    return .airPodsTuningRegular
        case .airPodsANC: return .airPodsTuningANC
        case .airPodsPro: return .airPodsTuningPro
        case .airPodsMax: return .airPodsTuningMax
        }
    }

    static func tuning(for variant: AirPodsModelVariant) -> AirPodsTuning {
        Defaults[key(for: variant)]
    }

    static func write(_ tuning: AirPodsTuning, for variant: AirPodsModelVariant) {
        Defaults[key(for: variant)] = tuning
    }

    /// Resets a single variant's tuning to the struct defaults.
    static func reset(_ variant: AirPodsModelVariant) {
        Defaults[key(for: variant)] = AirPodsTuning()
    }

    /// One-shot migration from the old global tuning keys into the Pro
    /// variant slot. Anyone who had spent time dialling the previous
    /// debug panel in keeps their settings under "AirPods Pro".
    static func migrateLegacyTuningIfNeeded() {
        guard !Defaults[.airPodsTuningMigratedV1] else { return }

        var pro = Defaults[.airPodsTuningPro]
        pro.artWidthMultiplier = Defaults[.airPodsArtWidthMultiplier]
        pro.artSidePadding     = Defaults[.airPodsArtSidePadding]
        pro.artLeftShift       = Defaults[.airPodsArtLeftShift]
        pro.modelZoom          = Defaults[.airPodsModelZoom]
        pro.ringDiameter       = Defaults[.airPodsRingDiameter]
        pro.ringStrokeWidth    = Defaults[.airPodsRingStrokeWidth]
        pro.ringSidePadding    = Defaults[.airPodsRingSidePadding]
        pro.ringTextScale      = Defaults[.airPodsRingTextScale]
        pro.showFullModel      = Defaults[.airPodsShowFullModel]
        pro.modelTiltX         = Defaults[.airPodsModelTiltX]
        pro.modelYShift        = Defaults[.airPodsModelYShift]
        pro.cameraZ            = Defaults[.airPodsCameraZ]
        pro.cameraY            = Defaults[.airPodsCameraY]
        pro.cameraFOV          = Defaults[.airPodsCameraFOV]
        pro.rotationSeconds    = Defaults[.airPodsRotationSeconds]
        pro.rotationReversed   = Defaults[.airPodsRotationReversed]
        pro.filterPositionCut  = Defaults[.airPodsFilterPositionCut]
        pro.filterAreaCut      = Defaults[.airPodsFilterAreaCut]
        pro.filterStrict       = Defaults[.airPodsFilterStrict]
        Defaults[.airPodsTuningPro] = pro

        Defaults[.airPodsTuningMigratedV1] = true
    }
}
