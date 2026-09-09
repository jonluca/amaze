import Foundation

enum CoinDeliveryError: Error {
    case invalidPurchase
    case balanceLimit
    case storageUnavailable
}
