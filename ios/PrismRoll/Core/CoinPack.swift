import Foundation

/// Currency amounts are fixed by the app; prices come exclusively from StoreKit.
struct CoinPack: Identifiable, Equatable, Sendable {
    let id: String
    let coins: Int

    static let catalog = [
        CoinPack(id: "com.jonluca.prismroll.coins.1000", coins: 1_000),
        CoinPack(id: "com.jonluca.prismroll.coins.5500", coins: 5_500),
        CoinPack(id: "com.jonluca.prismroll.coins.15000", coins: 15_000)
    ]
}
