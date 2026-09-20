import StoreKit

/// Receives only verified, active StoreKit purchases after entitlement or wallet delivery.
@MainActor
protocol PurchaseAnalyticsRecording {
    func recordVerifiedPurchase(_ transaction: Transaction)
}
