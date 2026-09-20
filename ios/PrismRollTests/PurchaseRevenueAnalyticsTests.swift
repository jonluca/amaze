#if canImport(UIKit)
import StoreKit
import StoreKitTest
import XCTest
@testable import PrismRoll

@MainActor
final class PurchaseRevenueAnalyticsTests: XCTestCase {
    private let smallPack = "com.jonluca.prismroll.coins.1000"

    func testConsentChangesNeverBackfillSuppressedPurchases() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let defaults = makeDefaults()
        let transport = RecordingPurchaseAnalyticsTransport()
        let analytics = makeAnalytics(defaults, transport)
        let first = try await buyTransaction()
        analytics.recordVerifiedPurchase(first)
        XCTAssertTrue(transport.actions.isEmpty)
        XCTAssertTrue(transport.transactions.isEmpty)

        analytics.setEnabled(true)
        analytics.recordVerifiedPurchase(first)
        XCTAssertTrue(transport.transactions.isEmpty)
        let second = try await buyTransaction()
        analytics.recordVerifiedPurchase(second)
        XCTAssertEqual(transport.transactions.map(\.id), [second.id])

        analytics.setEnabled(false)
        let third = try await buyTransaction()
        analytics.recordVerifiedPurchase(third)
        analytics.setEnabled(true)
        analytics.recordVerifiedPurchase(third)
        analytics.recordVerifiedPurchase(second)
        XCTAssertEqual(transport.transactions.map(\.id), [second.id])
    }

    func testRevenueIsDeduplicatedAcrossRecoveryAndServiceRecreation() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let defaults = makeDefaults()
        let firstTransport = RecordingPurchaseAnalyticsTransport()
        let first = makeAnalytics(defaults, firstTransport)
        first.setEnabled(true)
        let transaction = try await buyTransaction()
        first.recordVerifiedPurchase(transaction)
        first.recordVerifiedPurchase(transaction)
        XCTAssertEqual(firstTransport.transactions.map(\.id), [transaction.id])

        let secondTransport = RecordingPurchaseAnalyticsTransport()
        let second = makeAnalytics(defaults, secondTransport)
        second.configure()
        second.recordVerifiedPurchase(transaction)
        XCTAssertTrue(secondTransport.transactions.isEmpty)
        let next = try await buyTransaction()
        second.recordVerifiedPurchase(next)
        XCTAssertEqual(secondTransport.transactions.map(\.id), [next.id])
    }

    func testDebugAndTestsCannotSendPurchaseRevenueEvenWithSavedConsent() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let transaction = try await buyTransaction()
        let runtimes = [
            AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: true),
            AnalyticsRuntime(arguments: ["--uitesting", "--analytics-debug"], environment: [:], isDebugBuild: true),
            AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false, isRunningTests: true)
        ]
        for runtime in runtimes {
            let defaults = makeDefaults()
            defaults.set(true, forKey: AnalyticsService.consentDefaultsKey)
            let transport = RecordingPurchaseAnalyticsTransport()
            let analytics = AnalyticsService(defaults: defaults, transport: transport, runtime: runtime)
            analytics.configure()
            analytics.recordVerifiedPurchase(transaction)
            XCTAssertTrue(transport.actions.isEmpty)
            XCTAssertTrue(transport.transactions.isEmpty)
        }
    }

    func testHistoricalRestoresAndExistingOptInMigrationDoNotBackfillRevenue() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let historicalPurchase = try await buyTransaction()
        for alreadyEnabled in [false, true] {
            let defaults = makeDefaults()
            if alreadyEnabled { defaults.set(true, forKey: AnalyticsService.consentDefaultsKey) }
            let transport = RecordingPurchaseAnalyticsTransport()
            let analytics = AnalyticsService(
                defaults: defaults, transport: transport,
                runtime: AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false),
                dateProvider: { historicalPurchase.purchaseDate.addingTimeInterval(60) }
            )
            if alreadyEnabled { analytics.configure() }
            else { analytics.setEnabled(true) }
            analytics.recordVerifiedPurchase(historicalPurchase)
            XCTAssertTrue(transport.transactions.isEmpty)
        }
    }

    func testVerifiedNoAdsAndCoinsReachSDKOnceWithoutRestoreRevenue() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let transport = RecordingPurchaseAnalyticsTransport()
        let analytics = makeAnalytics(makeDefaults(), transport)
        analytics.setEnabled(true)
        var delivered: Set<String> = []
        let purchases = PurchaseService(analytics: analytics, purchaseAnalytics: analytics) { purchase in
            guard delivered.insert(purchase.transactionID).inserted else { return .alreadyDelivered }
            return .credited(1_000)
        }
        await purchases.load()
        await purchases.purchase()
        await purchases.purchaseCoins(productID: smallPack)
        await purchases.recoverUnfinishedPurchases()
        await purchases.restore()
        await purchases.load()

        XCTAssertTrue(purchases.removesAds)
        XCTAssertEqual(transport.transactions.count, 2)
        XCTAssertEqual(Set(transport.transactions.map(\.id)).count, 2)
        XCTAssertEqual(Set(transport.transactions.map(\.productID)), [smallPack, "com.jonluca.prismroll.removeads"])
        XCTAssertFalse(transport.actions.contains("event:in_app_purchase"), "Only the StoreKit-specific Firebase API owns revenue")
    }

    func testCoinsReportOnlyAfterDurableDeliveryAndNotAgainOnRecovery() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let transport = RecordingPurchaseAnalyticsTransport()
        let analytics = makeAnalytics(makeDefaults(), transport)
        analytics.setEnabled(true)
        var deliveryAllowed = false
        let purchases = PurchaseService(purchaseAnalytics: analytics) { _ in
            guard deliveryAllowed else { throw CocoaError(.fileWriteOutOfSpace) }
            return .credited(1_000)
        }
        await purchases.load()
        await purchases.purchaseCoins(productID: smallPack)
        XCTAssertTrue(transport.transactions.isEmpty)
        deliveryAllowed = true
        await purchases.recoverUnfinishedPurchases()
        await purchases.recoverUnfinishedPurchases()
        await purchases.restore()
        XCTAssertEqual(transport.transactions.count, 1)
    }

    func testCancelledPendingAndUnverifiedPurchasesProduceNoRevenue() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let transport = RecordingPurchaseAnalyticsTransport()
        let analytics = makeAnalytics(makeDefaults(), transport)
        analytics.setEnabled(true)
        let purchases = PurchaseService(purchaseAnalytics: analytics)
        await purchases.load()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await purchases.purchase()
        try await session.setSimulatedError(nil, forAPI: .purchase)
        session.askToBuyEnabled = true
        await purchases.purchase()
        session.askToBuyEnabled = false
        let transaction = try await buyTransaction()
        let outcome = await purchases.receiveCoinPurchase(.unverified(transaction, .invalidSignature))
        XCTAssertEqual(outcome, .unverified)
        XCTAssertTrue(transport.transactions.isEmpty)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "PurchaseRevenueAnalyticsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeAnalytics(_ defaults: UserDefaults, _ transport: RecordingPurchaseAnalyticsTransport) -> AnalyticsService {
        AnalyticsService(defaults: defaults, transport: transport,
                         runtime: AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false))
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private func buyTransaction() async throws -> Transaction {
        let products = try await Product.products(for: [smallPack])
        let product = try XCTUnwrap(products.first)
        guard case .success(.verified(let transaction)) = try await product.purchase() else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        return transaction
    }
}
#endif
