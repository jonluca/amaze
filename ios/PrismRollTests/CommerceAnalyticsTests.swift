#if canImport(UIKit)
import StoreKit
import StoreKitTest
import XCTest
@testable import PrismRoll

@MainActor
final class CommerceAnalyticsTests: XCTestCase {
    private let smallPack = "com.jonluca.prismroll.coins.1000"

    func testCancelledAndFailedCoinPurchasesHaveOneResultPerAttempt() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let recorder = Recorder()
        let purchases = PurchaseService(analytics: recorder) { _ in
            XCTFail("A cancelled or failed purchase must not credit coins")
            return .credited(1_000)
        }
        await purchases.load()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await purchases.purchaseCoins(productID: smallPack)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await purchases.purchaseCoins(productID: smallPack)

        XCTAssertEqual(recorder.events.map(\.name), [
            "purchase_started", "purchase_result", "purchase_started", "purchase_result"
        ])
        XCTAssertEqual(recorder.events.compactMap { $0.parameters["result"] as? String }, ["cancelled", "failed"])
        XCTAssertTrue(recorder.events.allSatisfy { $0.parameters["product_id"] as? String == smallPack })
        XCTAssertTrue(recorder.events.allSatisfy { Set($0.parameters.keys).isSubset(of: ["product_id", "result"]) })
    }

    func testVerifiedCoinPurchaseIsCountedOnceAcrossRecoveryAndRestore() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let recorder = Recorder()
        var deliveredIDs: Set<String> = []
        let purchases = PurchaseService(analytics: recorder) { purchase in
            guard deliveredIDs.insert(purchase.transactionID).inserted else { return .alreadyDelivered }
            return .credited(1_000)
        }
        await purchases.load()
        await purchases.purchaseCoins(productID: smallPack)
        await purchases.recoverUnfinishedPurchases()
        await purchases.restore()

        XCTAssertEqual(deliveredIDs.count, 1)
        XCTAssertEqual(recorder.events.map(\.name), ["purchase_started", "purchase_result"])
        XCTAssertEqual(recorder.events.last?.parameters["result"] as? String, "success")
        XCTAssertFalse(recorder.events.contains { $0.name == "in_app_purchase" })
    }

    func testPendingNoAdsIsAnAttemptResultWithoutRevenue() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let recorder = Recorder()
        let purchases = PurchaseService(analytics: recorder)
        await purchases.load()
        await purchases.purchase()

        XCTAssertFalse(purchases.removesAds)
        XCTAssertEqual(recorder.events.map(\.name), ["purchase_started", "purchase_result"])
        XCTAssertEqual(recorder.events.last?.parameters["result"] as? String, "pending")
    }

    func testUnavailableCatalogPurchaseIsCountedButUnknownInputIsNotSent() async {
        let recorder = Recorder()
        let purchases = PurchaseService(analytics: recorder)
        await purchases.purchaseCoins(productID: "arbitrary-input-is-not-a-product")
        XCTAssertTrue(recorder.events.isEmpty)
        await purchases.purchaseCoins(productID: smallPack)
        XCTAssertEqual(recorder.events.map(\.name), ["purchase_started", "purchase_result"])
        XCTAssertEqual(recorder.events.last?.parameters["result"] as? String, "unavailable")
    }

    func testUnavailableRewardAdsNeverReportAnImpressionOrReward() {
        let recorder = Recorder()
        let ads = AdService(configuration: nil, analytics: recorder)
        var rewards = 0
        var dismissals = 0
        for _ in 0..<2 {
            ads.presentRewarded(placement: .coinShop, onReward: { rewards += 1 }, onDismiss: { dismissals += 1 })
        }

        XCTAssertEqual(rewards, 0)
        XCTAssertEqual(dismissals, 2)
        XCTAssertEqual(recorder.events.map(\.name), ["ad_requested", "ad_failed", "ad_requested", "ad_failed"])
        XCTAssertTrue(recorder.events.allSatisfy { $0.parameters["ad_format"] as? String == "rewarded" })
        XCTAssertTrue(recorder.events.allSatisfy { $0.parameters["placement"] as? String == "coin_shop" })
        XCTAssertEqual(recorder.events.compactMap { $0.parameters["reason"] as? String }, ["unavailable", "unavailable"])
        XCTAssertTrue(recorder.events.allSatisfy { Set($0.parameters.keys).isSubset(of: ["ad_format", "placement", "reason"]) })
    }

    func testUnconfiguredInterstitialsDoNotCreateAdRequests() {
        let recorder = Recorder()
        let ads = AdService(configuration: nil, analytics: recorder)
        var continued = 0
        for _ in 0..<8 { ads.presentInterstitial { continued += 1 } }
        XCTAssertEqual(continued, 8)
        XCTAssertTrue(recorder.events.isEmpty)
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private final class Recorder: AnalyticsRecording {
        var events: [(name: String, parameters: [String: Any])] = []

        func record(_ name: String, parameters: [String: Any]) {
            events.append((name, parameters))
        }
    }
}
#endif
