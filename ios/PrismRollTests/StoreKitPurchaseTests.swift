#if canImport(UIKit)
import Combine
import StoreKit
import StoreKitTest
import XCTest
@testable import PrismRoll

@MainActor
final class StoreKitPurchaseTests: XCTestCase {
    func testVerifiedPurchaseRestorationRevocationAndAdSuppression() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let purchases = PurchaseService()
        await purchases.load()
        let product = try XCTUnwrap(purchases.product)
        XCTAssertEqual(product.id, "com.jonluca.prismroll.removeads")
        XCTAssertEqual(product.price, Decimal(string: "2.99"))
        XCTAssertFalse(purchases.removesAds)
        await purchases.purchase()
        XCTAssertTrue(purchases.removesAds, "Only a verified local StoreKit transaction can activate No Ads")

        let ads = AdService()
        ads.interstitialsDisabled = purchases.removesAds
        XCTAssertTrue(ads.interstitialsDisabled)
        var continuations = 0
        for _ in 0..<8 { ads.presentInterstitial { continuations += 1 } }
        XCTAssertEqual(continuations, 8, "No Ads must immediately continue through every eligible transition")
        XCTAssertFalse(ads.isPresenting)

        let restored = PurchaseService()
        await restored.restore()
        XCTAssertTrue(restored.removesAds)
        XCTAssertEqual(restored.status, "No Ads restored.")

        let revoked = expectation(description: "StoreKit update revokes the actual entitlement")
        let subscription = restored.$removesAds.filter { !$0 }.prefix(1).sink { _ in revoked.fulfill() }
        defer { subscription.cancel() }
        let transaction = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == "com.jonluca.prismroll.removeads"
        })
        try session.refundTransaction(identifier: transaction.identifier)
        await fulfillment(of: [revoked], timeout: 15)
        XCTAssertFalse(restored.removesAds)
        ads.interstitialsDisabled = restored.removesAds
        XCTAssertFalse(ads.interstitialsDisabled)
        await restored.restore()
        XCTAssertFalse(restored.removesAds, "Restore must not resurrect a revoked purchase")
    }

    func testAskToBuyDoesNotUnlockUntilApproved() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        let purchases = PurchaseService()
        await purchases.load()
        XCTAssertNotNil(purchases.product)
        await purchases.purchase()
        XCTAssertFalse(purchases.removesAds)
        XCTAssertEqual(purchases.status, "Your purchase is awaiting approval.")
        let approved = expectation(description: "Verified approval enables the entitlement")
        let subscription = purchases.$removesAds.filter { $0 }.prefix(1).sink { _ in approved.fulfill() }
        defer { subscription.cancel() }
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        await fulfillment(of: [approved], timeout: 15)
        XCTAssertTrue(purchases.removesAds)
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }
}
#endif
