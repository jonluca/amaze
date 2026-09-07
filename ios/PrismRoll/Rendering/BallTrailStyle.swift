/// Each ball owns a small visual signature and a matching motion profile.
@MainActor
enum BallTrailStyle: String, CaseIterable {
    case coral, mint, sunset, tidal, galaxy, orbit
    case ember, frost, jade, nova, aurora, midnight

    init(skin: BallSkin) {
        self = Self(rawValue: skin.id) ?? .coral
    }

    var spacing: Float {
        switch self {
        case .coral, .mint, .ember, .aurora: return 0.24
        case .sunset, .tidal, .galaxy, .frost, .jade: return 0.30
        case .orbit, .nova, .midnight: return 0.36
        }
    }

    var lifetime: Double {
        switch self {
        case .ember: return 0.38
        case .nova: return 0.44
        case .galaxy, .orbit: return 0.52
        case .coral, .sunset, .frost: return 0.58
        case .mint, .tidal, .jade, .aurora, .midnight: return 0.66
        }
    }

    var size: Float {
        switch self {
        case .coral: return 0.38
        case .mint, .aurora: return 0.35
        case .sunset, .tidal, .orbit, .midnight: return 0.30
        case .galaxy, .frost, .jade, .nova: return 0.29
        case .ember: return 0.25
        }
    }

    var rise: Float {
        switch self {
        case .coral, .mint, .tidal: return 0.28
        case .ember: return 0.48
        case .sunset, .jade: return 0.10
        case .galaxy, .orbit, .frost, .nova, .aurora, .midnight: return 0.18
        }
    }

    var spread: Float {
        switch self {
        case .coral, .mint, .aurora: return 0.19
        case .sunset, .jade: return 0.30
        case .tidal, .frost: return 0.24
        case .galaxy, .orbit, .ember, .nova, .midnight: return 0.14
        }
    }

    var drift: Float {
        switch self {
        case .coral, .mint, .ember: return 0.22
        case .sunset, .jade, .aurora: return 0.14
        case .tidal, .galaxy, .orbit, .frost, .nova, .midnight: return 0.08
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
        }
    }

    var expansion: Float {
        switch self {
        case .coral: return 2.1
        case .mint, .tidal: return 1.7
        case .orbit, .aurora: return 1.45
        case .sunset, .frost, .jade, .midnight: return 1.15
        case .galaxy, .ember, .nova: return 0.55
        }
    }

    var additive: Bool {
        // Alpha blending keeps even the luminous motifs readable on pale boards.
        false
    }
}
