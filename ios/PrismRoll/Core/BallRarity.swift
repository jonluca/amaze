enum BallRarity: String, CaseIterable, Codable, Identifiable, Sendable {
    case common, uncommon, rare, epic, legendary, mythic

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var hex: String {
        switch self {
        case .common: return "AAB7CC"
        case .uncommon: return "79DEAB"
        case .rare: return "73BBFF"
        case .epic: return "C29AFF"
        case .legendary: return "FFD16E"
        case .mythic: return "FF8EC5"
        }
    }

    var symbol: String {
        switch self {
        case .common: return "circle.fill"
        case .uncommon: return "leaf.fill"
        case .rare: return "diamond.fill"
        case .epic: return "sparkles"
        case .legendary: return "crown.fill"
        case .mythic: return "sparkle"
        }
    }
}
