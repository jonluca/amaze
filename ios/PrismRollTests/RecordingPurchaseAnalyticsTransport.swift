#if canImport(UIKit)
import StoreKit
@testable import PrismRoll

@MainActor
final class RecordingPurchaseAnalyticsTransport: AnalyticsTransport {
    var isAvailable = true
    var actions: [String] = []
    var transactions: [Transaction] = []

    func configure() -> Bool { actions.append("configure"); return true }
    func setCollectionEnabled(_ enabled: Bool) { actions.append("collection:\(enabled)") }
    func setAnalyticsConsent(granted: Bool) { actions.append("consent:\(granted)") }
    func resetAnalyticsData() { actions.append("reset") }
    func record(_ name: String, parameters: [String: Any]) { actions.append("event:\(name)") }
    func recordVerifiedPurchase(_ transaction: Transaction) { transactions.append(transaction) }
}
#endif
