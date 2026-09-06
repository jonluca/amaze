struct BallSkin: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let name: String
    let price: Int
    let hex: String
    let accentHex: String
    let pattern: String

    static let catalog: [BallSkin] = [
        BallSkin(id: "coral", name: "Coral", price: 0, hex: "FF795F", accentHex: "FFD5A8", pattern: "plain"),
        BallSkin(id: "mint", name: "Mint", price: 100, hex: "55D8B1", accentHex: "CCFFE9", pattern: "plain"),
        BallSkin(id: "sunset", name: "Sunset", price: 150, hex: "FFA45E", accentHex: "F46399", pattern: "stripe"),
        BallSkin(id: "tidal", name: "Tidal", price: 225, hex: "5297F5", accentHex: "C7EEFF", pattern: "marble"),
        BallSkin(id: "galaxy", name: "Galaxy", price: 350, hex: "9675ED", accentHex: "E8CAFF", pattern: "speckle"),
        BallSkin(id: "orbit", name: "Orbit", price: 500, hex: "334B66", accentHex: "F7C974", pattern: "rings"),
        BallSkin(id: "ember", name: "Ember", price: 700, hex: "E04D43", accentHex: "FFD05C", pattern: "marble"),
        BallSkin(id: "frost", name: "Frost", price: 950, hex: "C1E7F5", accentHex: "FFFFFF", pattern: "speckle"),
        BallSkin(id: "jade", name: "Jade", price: 1200, hex: "217A62", accentHex: "B5F5A0", pattern: "rings"),
        BallSkin(id: "nova", name: "Nova", price: 1500, hex: "ED58A5", accentHex: "FFD66A", pattern: "stripe"),
        BallSkin(id: "aurora", name: "Aurora", price: 1800, hex: "38CEC3", accentHex: "BB83FF", pattern: "marble"),
        BallSkin(id: "midnight", name: "Midnight", price: 2200, hex: "172A4B", accentHex: "FCE6A4", pattern: "speckle")
    ]
}
