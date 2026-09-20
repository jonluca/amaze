import Combine
import Foundation
import StoreKit

@MainActor
final class AnalyticsService: ObservableObject, AnalyticsRecording, PurchaseAnalyticsRecording {
    static let shared = AnalyticsService()
    static let consentDefaultsKey = "prismroll.analytics.enabled"
    private static let handledPurchaseDefaultsKey = "prismroll.analytics.handledPurchases.v1"
    private static let purchasePeriodDefaultsKey = "prismroll.analytics.purchasePeriodStart.v1"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var hasMadeChoice: Bool
    @Published private(set) var isAvailable: Bool

    private let defaults: UserDefaults
    private let transport: any AnalyticsTransport
    private let runtime: AnalyticsRuntime
    private let attribution: (any InstallAttributionConsentUpdating)?
    private let dateProvider: () -> Date
    private var isConfigured = false
    private var isCollecting = false
    private var purchaseRevenuePolicy: PurchaseRevenuePolicy
    private var purchasePeriodStart: Date?

    convenience init() {
        self.init(defaults: .standard, transport: FirebaseAnalyticsTransport(), runtime: .current,
                  attribution: AppsFlyerAttributionService.shared)
    }

    init(defaults: UserDefaults, transport: any AnalyticsTransport, runtime: AnalyticsRuntime,
         attribution: (any InstallAttributionConsentUpdating)? = nil,
         dateProvider: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.transport = transport
        self.runtime = runtime
        self.attribution = attribution
        self.dateProvider = dateProvider
        hasMadeChoice = defaults.object(forKey: Self.consentDefaultsKey) != nil
        isEnabled = defaults.bool(forKey: Self.consentDefaultsKey)
        isAvailable = transport.isAvailable
        purchaseRevenuePolicy = PurchaseRevenuePolicy(
            handledTransactionIDs: Set(defaults.stringArray(forKey: Self.handledPurchaseDefaultsKey) ?? [])
        )
        purchasePeriodStart = defaults.object(forKey: Self.purchasePeriodDefaultsKey) as? Date
    }

    /// Called during app startup. The SDK starts only for a saved, explicit opt-in.
    func configure() {
        applyChoice()
    }

    /// Consent lives outside the game save, so resetting progress does not change it.
    func setEnabled(_ enabled: Bool) {
        if enabled, !isEnabled { startPurchasePeriod() }
        defaults.set(enabled, forKey: Self.consentDefaultsKey)
        hasMadeChoice = true
        isEnabled = enabled
        applyChoice()
    }

    func record(_ name: String, parameters: [String: Any] = [:]) {
        guard isEnabled, isCollecting else { return }
        transport.record(name, parameters: parameters)
    }

    func screen(_ name: String) {
        record("screen_view", parameters: ["screen_name": name, "screen_class": "PrismRoll"])
    }

    func recordVerifiedPurchase(_ transaction: Transaction) {
        guard runtime.allowsCollection, transaction.revocationDate == nil, !transaction.isUpgraded else { return }
        // Remember suppressed purchases too: enabling analytics later must not replay
        // a purchase already handled while opted out. This deduplication ledger is local.
        let decision = purchaseRevenuePolicy.consume(
            transactionID: String(transaction.id), purchasedAt: transaction.purchaseDate,
            collectionPeriodStart: isEnabled && isCollecting ? purchasePeriodStart : nil
        )
        guard decision != .duplicate else { return }
        defaults.set(purchaseRevenuePolicy.handledTransactionIDs.sorted(), forKey: Self.handledPurchaseDefaultsKey)
        guard decision == .report else { return }
        transport.recordVerifiedPurchase(transaction)
    }

    private func startPurchasePeriod() {
        purchasePeriodStart = dateProvider()
        defaults.set(purchasePeriodStart, forKey: Self.purchasePeriodDefaultsKey)
    }

    private func applyChoice() {
        // The separate attribution choice never overrides usage consent or a failed
        // Analytics configuration. Every early return also reconciles its gate.
        defer { attribution?.setUsageAnalyticsEnabled(isEnabled && isCollecting) }
        // UI tests and ordinary debug runs cannot initialize the SDK, even after opt-in.
        guard runtime.allowsCollection, isAvailable else { return }

        if isEnabled {
            guard !isCollecting else { return }
            // Existing analytics opt-ins migrate prospectively; never report their
            // historical purchases or fresh-install restores as new revenue.
            if purchasePeriodStart == nil { startPurchasePeriod() }
            if !isConfigured {
                guard transport.configure() else {
                    isAvailable = false
                    return
                }
                isConfigured = true
            }
            transport.setAnalyticsConsent(granted: true)
            transport.setCollectionEnabled(true)
            isCollecting = true
        } else if isConfigured, isCollecting {
            isCollecting = false
            transport.setCollectionEnabled(false)
            transport.setAnalyticsConsent(granted: false)
            transport.resetAnalyticsData()
            // Resetting analytics state must never restore advertising consent.
            transport.setAnalyticsConsent(granted: false)
        }
    }
}
