struct BallSkin: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let price: Int
    let rarity: BallRarity
    let hex: String
    let accentHex: String
    let pattern: String

    static let catalog: [BallSkin] = [
        BallSkin(id: "coral", name: "Coral", price: 0, rarity: .common, hex: "FF795F", accentHex: "FFD5A8", pattern: "plain"),
        BallSkin(id: "mint", name: "Mint", price: 500, rarity: .common, hex: "55D8B1", accentHex: "CCFFE9", pattern: "plain"),
        BallSkin(id: "sunset", name: "Sunset", price: 900, rarity: .common, hex: "FFA45E", accentHex: "F46399", pattern: "stripe"),
        BallSkin(id: "tidal", name: "Tidal", price: 1_500, rarity: .uncommon, hex: "5297F5", accentHex: "C7EEFF", pattern: "marble"),
        BallSkin(id: "galaxy", name: "Galaxy", price: 2_200, rarity: .uncommon, hex: "9675ED", accentHex: "E8CAFF", pattern: "speckle"),
        BallSkin(id: "orbit", name: "Orbit", price: 3_200, rarity: .uncommon, hex: "334B66", accentHex: "F7C974", pattern: "rings"),
        BallSkin(id: "ember", name: "Ember", price: 5_000, rarity: .rare, hex: "E04D43", accentHex: "FFD05C", pattern: "marble"),
        BallSkin(id: "frost", name: "Frost", price: 7_000, rarity: .rare, hex: "C1E7F5", accentHex: "FFFFFF", pattern: "speckle"),
        BallSkin(id: "jade", name: "Jade", price: 9_500, rarity: .rare, hex: "217A62", accentHex: "B5F5A0", pattern: "rings"),
        BallSkin(id: "nova", name: "Nova", price: 13_000, rarity: .epic, hex: "ED58A5", accentHex: "FFD66A", pattern: "stripe"),
        BallSkin(id: "aurora", name: "Aurora", price: 17_000, rarity: .epic, hex: "38CEC3", accentHex: "BB83FF", pattern: "marble"),
        BallSkin(id: "midnight", name: "Midnight", price: 22_000, rarity: .epic, hex: "172A4B", accentHex: "FCE6A4", pattern: "speckle"),
        BallSkin(id: "solar-flare", name: "Solar Flare", price: 30_000, rarity: .legendary, hex: "FFA51F", accentHex: "FFF1A6", pattern: "solar"),
        BallSkin(id: "plasma", name: "Plasma", price: 40_000, rarity: .legendary, hex: "5423B8", accentHex: "63FFF3", pattern: "plasma"),
        BallSkin(id: "supernova", name: "Supernova", price: 55_000, rarity: .legendary, hex: "D62D82", accentHex: "FFF5C4", pattern: "supernova"),
        BallSkin(id: "singularity", name: "Singularity", price: 75_000, rarity: .mythic, hex: "090C26", accentHex: "DCA5FF", pattern: "singularity"),
        BallSkin(id: "tesseract", name: "Tesseract", price: 100_000, rarity: .mythic, hex: "122C63", accentHex: "64FFE2", pattern: "tesseract"),
        BallSkin(id: "genesis", name: "Genesis", price: 150_000, rarity: .mythic, hex: "481485", accentHex: "FFDB8A", pattern: "genesis")
    ]
}
