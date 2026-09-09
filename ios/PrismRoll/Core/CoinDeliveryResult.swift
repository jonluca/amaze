enum CoinDeliveryResult: Equatable, Sendable {
    case credited(Int)
    case alreadyDelivered
}
