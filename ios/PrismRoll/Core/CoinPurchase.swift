import Foundation

/// Created only from a verified, active StoreKit consumable transaction.
struct CoinPurchase: Equatable, Sendable {
    let transactionID: String
    let productID: String
    let quantity: Int

    var coins: Int? {
        guard !transactionID.isEmpty, quantity > 0,
              let pack = CoinPack.catalog.first(where: { $0.id == productID }) else { return nil }
        let amount = pack.coins.multipliedReportingOverflow(by: quantity)
        return amount.overflow ? nil : amount.partialValue
    }
}
