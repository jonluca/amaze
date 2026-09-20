import Foundation

/// Local, prospective revenue reporting. Persist every newly handled ID, including
/// suppressed purchases, so a later consent change cannot replay old purchases.
struct PurchaseRevenuePolicy {
    enum Decision: Equatable {
        case duplicate
        case suppress
        case report
    }

    private(set) var handledTransactionIDs: Set<String>

    init(handledTransactionIDs: Set<String> = []) {
        self.handledTransactionIDs = handledTransactionIDs
    }

    mutating func consume(transactionID: String, purchasedAt: Date,
                          collectionPeriodStart: Date?) -> Decision {
        guard handledTransactionIDs.insert(transactionID).inserted else { return .duplicate }
        guard let collectionPeriodStart, purchasedAt >= collectionPeriodStart else { return .suppress }
        return .report
    }
}
