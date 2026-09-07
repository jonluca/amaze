enum BoardTheme: String, CaseIterable, Codable, Identifiable {
    case aurora
    case timber
    case porcelain
    case midnight

    var id: String { rawValue }
    var name: String {
        switch self {
        case .aurora: return "Aurora"
        case .timber: return "Timber"
        case .porcelain: return "Porcelain"
        case .midnight: return "Midnight"
        }
    }
    var subtitle: String {
        switch self {
        case .aurora: return "Violet skies. Neon paths."
        case .timber: return "Warm grain. Classic arcade."
        case .porcelain: return "Cool ceramic. Pure focus."
        case .midnight: return "Dark chrome. Neon after hours."
        }
    }
    var previewHex: String {
        switch self {
        case .aurora: return "B0A0FF"
        case .timber: return "BD8551"
        case .porcelain: return "E6F2F4"
        case .midnight: return "344263"
        }
    }
    var topHex: String {
        switch self {
        case .aurora: return "E6BBFF"
        case .timber: return "CA945A"
        case .porcelain: return "F5FCFF"
        case .midnight: return "435370"
        }
    }
    var sideHex: String {
        switch self {
        case .aurora: return "710BB5"
        case .timber: return "73401F"
        case .porcelain: return "91B5C4"
        case .midnight: return "1C2841"
        }
    }
    var pathHex: String {
        switch self {
        case .aurora: return "171831"
        case .timber: return "63391F"
        case .porcelain: return "B9CFD8"
        case .midnight: return "0E1526"
        }
    }

    var edgeHex: String {
        switch self {
        case .aurora: return "F256DB"
        case .timber: return "E7BA7E"
        case .porcelain: return "D8F8FF"
        case .midnight: return "8D80FF"
        }
    }

    var gridHex: String {
        switch self {
        case .aurora: return "545078"
        case .timber: return "A57950"
        case .porcelain: return "7A9DAC"
        case .midnight: return "404E77"
        }
    }
}
