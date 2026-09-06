enum GameMode: String, CaseIterable, Codable, Sendable {
    case endless, challenge, timed

    var title: String {
        switch self {
        case .endless: "Endless"
        case .challenge: "Challenge"
        case .timed: "Time Rush"
        }
    }
}
