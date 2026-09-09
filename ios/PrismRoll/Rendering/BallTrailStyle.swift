/// Each ball owns a small visual signature and a matching motion profile.
@MainActor
enum BallTrailStyle: String, CaseIterable {
    case coral, mint, sunset, tidal, galaxy, orbit
    case ember, frost, jade, nova, aurora, midnight
    case solarFlare = "solar-flare"
    case plasma, supernova, singularity, tesseract, genesis

    init(skin: BallSkin) {
        self = Self(rawValue: skin.id) ?? .coral
    }

    var spacing: Float {
        switch self {
        case .coral, .mint, .ember, .aurora: return 0.14
        case .sunset, .tidal, .galaxy, .frost, .jade: return 0.17
        case .orbit, .nova, .midnight: return 0.20
        case .solarFlare, .plasma: return 0.17
        case .supernova, .singularity, .tesseract, .genesis: return 0.22
        }
    }

    var lifetime: Double {
        switch self {
        case .ember: return 0.38
        case .nova: return 0.44
        case .galaxy, .orbit: return 0.52
        case .coral, .sunset, .frost: return 0.58
        case .mint, .tidal, .jade, .aurora, .midnight: return 0.66
        case .solarFlare: return 0.48
        case .plasma: return 0.42
        case .supernova: return 0.54
        case .singularity, .tesseract: return 0.62
        case .genesis: return 0.70
        }
    }

    var size: Float {
        switch self {
        case .coral: return 0.38
        case .mint, .aurora: return 0.35
        case .sunset, .tidal, .orbit, .midnight: return 0.30
        case .galaxy, .frost, .jade, .nova: return 0.29
        case .ember: return 0.25
        case .solarFlare, .plasma: return 0.32
        case .supernova, .singularity: return 0.36
        case .tesseract: return 0.38
        case .genesis: return 0.40
        }
    }

    var rise: Float {
        switch self {
        case .coral, .mint, .tidal: return 0.28
        case .ember: return 0.48
        case .sunset, .jade: return 0.10
        case .galaxy, .orbit, .frost, .nova, .aurora, .midnight: return 0.18
        case .solarFlare: return 0.36
        case .plasma, .supernova: return 0.24
        case .singularity: return 0.08
        case .tesseract, .genesis: return 0.16
        }
    }

    var spread: Float {
        switch self {
        case .coral, .mint, .aurora: return 0.19
        case .sunset, .jade: return 0.30
        case .tidal, .frost: return 0.24
        case .galaxy, .orbit, .ember, .nova, .midnight: return 0.14
        case .solarFlare, .plasma, .supernova: return 0.16
        case .singularity, .tesseract, .genesis: return 0.10
        }
    }

    var drift: Float {
        switch self {
        case .coral, .mint, .ember: return 0.22
        case .sunset, .jade, .aurora: return 0.14
        case .tidal, .galaxy, .orbit, .frost, .nova, .midnight: return 0.08
        case .solarFlare, .plasma: return 0.18
        case .supernova: return 0.10
        case .singularity, .tesseract, .genesis: return 0.04
        }
    }

    var spin: Float {
        switch self {
        case .coral, .mint, .tidal: return 0.7
        case .sunset, .jade: return 3.0
        case .galaxy, .nova: return 2.2
        case .orbit, .frost: return 1.5
        case .ember: return 0.4
        case .aurora, .midnight: return 1.0
        case .solarFlare: return 2.6
        case .plasma: return 0.5
        case .supernova: return 1.4
        case .singularity: return 3.4
        case .tesseract: return 1.8
        case .genesis: return 1.2
        }
    }

    var expansion: Float {
        switch self {
        case .coral: return 1.5
        case .mint, .tidal: return 1.4
        case .orbit, .aurora: return 1.3
        case .sunset, .frost, .jade, .midnight: return 1.15
        case .galaxy, .ember, .nova: return 0.55
        case .solarFlare: return 1.25
        case .plasma: return 0.65
        case .supernova: return 1.55
        case .singularity: return 0.35
        case .tesseract: return 0.95
        case .genesis: return 1.35
        }
    }

    var additive: Bool {
        // Alpha blending keeps even the luminous motifs readable on pale boards.
        false
    }
}
