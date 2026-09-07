enum RewardedAdAvailability: Equatable {
    case loading, ready, unavailable

    var caption: String {
        switch self {
        case .loading: "Loading ad…"
        case .ready: "Watch ad"
        case .unavailable: "No ad · retry"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .loading: "An optional ad is loading. You can keep playing."
        case .ready: "Watch a video ad to receive this reward."
        case .unavailable: "No ad is available. Double-tap to check again."
        }
    }
}
