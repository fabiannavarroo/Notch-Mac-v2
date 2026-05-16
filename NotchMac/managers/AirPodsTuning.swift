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

import Combine
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

/// Central observable wrapper around the four per-variant Defaults keys.
///
/// We use this instead of relying on `@Default` directly because the slider
/// Bindings write into Codable structs many times per second, and the
/// default property wrapper occasionally fails to re-publish struct
/// rewrites to nested SwiftUI views (the symptom: visual updates only
/// arrive after re-mounting the view via a tab switch). This singleton
/// republishes every write synchronously through @Published properties,
/// so any view that observes it redraws within the same run-loop tick.
@MainActor
final class AirPodsTuningCenter: ObservableObject {
    static let shared = AirPodsTuningCenter()

    @Published var regular: AirPodsTuning
    @Published var anc:     AirPodsTuning
    @Published var pro:     AirPodsTuning
    @Published var max_:    AirPodsTuning

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        self.regular = Defaults[.airPodsTuningRegular]
        self.anc     = Defaults[.airPodsTuningANC]
        self.pro     = Defaults[.airPodsTuningPro]
        self.max_    = Defaults[.airPodsTuningMax]

        // Mirror external Defaults writes (e.g. import/reset) back into the
        // @Published mirrors so observers stay in sync regardless of who
        // updated the storage.
        Defaults.publisher(.airPodsTuningRegular)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                if self.regular != change.newValue { self.regular = change.newValue }
            }
            .store(in: &cancellables)
        Defaults.publisher(.airPodsTuningANC)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                if self.anc != change.newValue { self.anc = change.newValue }
            }
            .store(in: &cancellables)
        Defaults.publisher(.airPodsTuningPro)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                if self.pro != change.newValue { self.pro = change.newValue }
            }
            .store(in: &cancellables)
        Defaults.publisher(.airPodsTuningMax)
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                guard let self else { return }
                if self.max_ != change.newValue { self.max_ = change.newValue }
            }
            .store(in: &cancellables)
    }

    func tuning(for variant: AirPodsModelVariant) -> AirPodsTuning {
        switch variant {
        case .airPods:    return regular
        case .airPodsANC: return anc
        case .airPodsPro: return pro
        case .airPodsMax: return max_
        }
    }

    func write(_ tuning: AirPodsTuning, for variant: AirPodsModelVariant) {
        switch variant {
        case .airPods:    regular = tuning; Defaults[.airPodsTuningRegular] = tuning
        case .airPodsANC: anc     = tuning; Defaults[.airPodsTuningANC]     = tuning
        case .airPodsPro: pro     = tuning; Defaults[.airPodsTuningPro]     = tuning
        case .airPodsMax: max_    = tuning; Defaults[.airPodsTuningMax]     = tuning
        }
    }

    func reset(_ variant: AirPodsModelVariant) {
        write(AirPodsTuning(), for: variant)
    }
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
        if !Defaults[.airPodsTuningMigratedV1] {
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

        // V2 — before per-variant was a thing, every variant the user
        // selected wrote into the same global keys. After V1 only the Pro
        // slot kept those values; the other three sat at struct defaults
        // and the user lost their work. Seed them from Pro so each variant
        // starts from the same baseline; the user can then re-tune per
        // model without re-doing the common bits from scratch.
        if !Defaults[.airPodsTuningMigratedV2] {
            let pro = Defaults[.airPodsTuningPro]
            let blank = AirPodsTuning()
            if Defaults[.airPodsTuningRegular] == blank { Defaults[.airPodsTuningRegular] = pro }
            if Defaults[.airPodsTuningANC]     == blank { Defaults[.airPodsTuningANC]     = pro }
            if Defaults[.airPodsTuningMax]     == blank { Defaults[.airPodsTuningMax]     = pro }
            Defaults[.airPodsTuningMigratedV2] = true
        }
    }
}
