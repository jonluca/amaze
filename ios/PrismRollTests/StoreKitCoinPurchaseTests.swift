#if canImport(UIKit)
import Combine
import StoreKit
import StoreKitTest
import XCTest
@testable import PrismRoll

@MainActor
final class StoreKitCoinPurchaseTests: XCTestCase {
    private let smallPack = "com.jonluca.prismroll.coins.1000"

    func testVerifiedConsumablesAreRepeatableAndDoNotChangeNoAds() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        var delivered: [CoinPurchase] = []
        let purchases = PurchaseService { purchase in
            guard !delivered.contains(where: { $0.transactionID == purchase.transactionID }) else { return .alreadyDelivered }
            delivered.append(purchase)
            return .credited(try XCTUnwrap(purchase.coins))
        }
        await purchases.load()
        XCTAssertEqual(purchases.coinProducts.map(\.id), CoinPack.catalog.map(\.id))
        XCTAssertEqual(purchases.coinProducts.map(\.price), [Decimal(string: "0.99")!, Decimal(string: "4.99")!, Decimal(string: "9.99")!])
        XCTAssertTrue(purchases.coinProducts.allSatisfy { $0.type == .consumable && !$0.displayPrice.isEmpty })
        await purchases.purchase()
        XCTAssertTrue(purchases.removesAds)
        await purchases.purchaseCoins(productID: smallPack)
        await purchases.purchaseCoins(productID: smallPack)
        await purchases.purchaseCoins(productID: CoinPack.catalog[2].id)
        XCTAssertEqual(delivered.compactMap(\.coins), [1_000, 1_000, 15_000])
        XCTAssertEqual(Set(delivered.map(\.transactionID)).count, 3)
        XCTAssertTrue(purchases.removesAds)
        let remaining = await unfinishedCoinIDs()
        XCTAssertEqual(remaining, [])
        await purchases.load()
        await purchases.restore()
        XCTAssertEqual(delivered.count, 3, "Reload and Restore must not replay finished consumables")
        XCTAssertTrue(purchases.removesAds)
    }

    func testPendingCoinsDeliverOnlyAfterApprovalAndRefundDoesNotDeliverAgain() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        session.askToBuyEnabled = true
        var delivered: [CoinPurchase] = []
        let approval = expectation(description: "Approved transaction delivers coins")
        let purchases = PurchaseService { purchase in
            guard !delivered.contains(where: { $0.transactionID == purchase.transactionID }) else { return .alreadyDelivered }
            delivered.append(purchase)
            approval.fulfill()
            return .credited(1_000)
        }
        await purchases.load()
        await purchases.purchaseCoins(productID: smallPack)
        XCTAssertTrue(delivered.isEmpty)
        XCTAssertEqual(purchases.coinStatus, "Your purchase is awaiting approval.")
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        await fulfillment(of: [approval], timeout: 15)
        XCTAssertEqual(delivered.compactMap(\.coins), [1_000])
        try session.refundTransaction(identifier: pending.identifier)
        XCTAssertNotNil(session.allTransactions().first { $0.identifier == pending.identifier }?.cancelDate)
        // Finished consumables are not an active entitlement and need not emit
        // the same refund update as a non-consumable. Restore must not credit it.
        await purchases.restore()
        XCTAssertEqual(delivered.count, 1)
        XCTAssertFalse(purchases.removesAds)
    }

    func testCancellationFailureAndUnverifiedPurchaseNeverDeliverCoins() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        var deliveryCount = 0
        let purchases = PurchaseService { _ in
            deliveryCount += 1
            return .credited(1_000)
        }
        await purchases.load()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await purchases.purchaseCoins(productID: smallPack)
        XCTAssertEqual(purchases.coinStatus, "Purchase cancelled.")
        XCTAssertEqual(deliveryCount, 0)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        await purchases.purchaseCoins(productID: smallPack)
        XCTAssertEqual(deliveryCount, 0)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        let product = try XCTUnwrap(purchases.coinProducts.first { $0.id == smallPack })
        guard case .success(.verified(let transaction)) = try await product.purchase() else {
            return XCTFail("The local fixture must create a transaction for the verification boundary test")
        }
        // Supply an actual local transaction with failed verification, without
        // relying on Xcode's simulated verification error becoming a purchase result.
        await purchases.receiveCoinPurchase(.unverified(transaction, .invalidSignature))
        XCTAssertEqual(purchases.coinStatus, "The purchase could not be verified. No coins were added.")
        XCTAssertEqual(deliveryCount, 0)
        let unfinished = await unfinishedCoinIDs()
        XCTAssertTrue(unfinished.contains(String(transaction.id)), "Failed verification must not finish the transaction")
        XCTAssertFalse(purchases.removesAds)
    }

    func testFailedPersistenceLeavesTransactionForColdStartRecovery() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        var first: PurchaseService? = PurchaseService { _ in
            throw CocoaError(.fileWriteOutOfSpace)
        }
        await first?.load()
        await first?.purchaseCoins(productID: smallPack)
        let unfinished = await unfinishedCoinIDs()
        XCTAssertEqual(unfinished.count, 1, "Persistence failure must not acknowledge the purchase to StoreKit")
        XCTAssertTrue(first?.coinStatus.hasPrefix("Your purchase is saved by the App Store.") == true)
        first = nil
        var deliveredIDs: Set<String> = []
        var balance = 0
        var second: PurchaseService? = PurchaseService { purchase in
            guard deliveredIDs.insert(purchase.transactionID).inserted else { return .alreadyDelivered }
            let coins = try XCTUnwrap(purchase.coins)
            balance += coins
            return .credited(coins)
        }
        await second?.load()
        XCTAssertEqual(balance, 1_000)
        XCTAssertEqual(deliveredIDs, unfinished)
        let remaining = await unfinishedCoinIDs()
        XCTAssertEqual(remaining, [])
        second = nil
        let third = PurchaseService { _ in
            XCTFail("A finished purchase must not be credited after another launch")
            return .alreadyDelivered
        }
        await third.load()
        XCTAssertEqual(balance, 1_000)
    }

    func testMissingWalletAndRevokedUnfinishedPurchaseCannotCreateCoins() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let purchases = PurchaseService()
        await purchases.load()
        let product = try XCTUnwrap(purchases.coinProducts.first { $0.id == smallPack })
        guard case .success(.verified(let transaction)) = try await product.purchase() else {
            return XCTFail("The local fixture must create a verified purchase")
        }
        await purchases.recoverUnfinishedPurchases()
        let unfinished = await unfinishedCoinIDs()
        XCTAssertTrue(unfinished.contains(String(transaction.id)))
        let local = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == smallPack })
        let revoked = expectation(description: "StoreKit delivers the revocation before wallet attachment")
        let subscription = purchases.$coinStatus.filter { $0 == "This purchase is no longer active. No coins were added." }
            .prefix(1).sink { _ in revoked.fulfill() }
        defer { subscription.cancel() }
        try session.refundTransaction(identifier: local.identifier)
        await fulfillment(of: [revoked], timeout: 15)
        XCTAssertNotNil(session.allTransactions().first { $0.identifier == local.identifier }?.cancelDate)
        var delivered = 0
        purchases.configureCoinDelivery { _ in
            delivered += 1
            return .credited(1_000)
        }
        await purchases.recoverUnfinishedPurchases()
        XCTAssertEqual(delivered, 0)
    }

    func testRecoveryAcknowledgesAlreadyPersistedCreditWithoutAddingItAgain() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        var receivedIDs: Set<String> = []
        var balance = 0
        var first: PurchaseService? = PurchaseService { purchase in
            receivedIDs.insert(purchase.transactionID)
            balance += try XCTUnwrap(purchase.coins)
            // Model interruption after the wallet commit but before StoreKit finish.
            throw CocoaError(.fileWriteUnknown)
        }
        await first?.load()
        await first?.purchaseCoins(productID: smallPack)
        XCTAssertEqual(balance, 1_000)
        let unfinished = await unfinishedCoinIDs()
        XCTAssertEqual(unfinished, receivedIDs)
        first = nil
        let recovered = PurchaseService { purchase in
            XCTAssertTrue(receivedIDs.contains(purchase.transactionID))
            return .alreadyDelivered
        }
        await recovered.recoverUnfinishedPurchases()
        XCTAssertEqual(recovered.coinStatus, "This purchase is already in your balance.")
        let remaining = await unfinishedCoinIDs()
        XCTAssertEqual(remaining, [])
        XCTAssertEqual(balance, 1_000)
    }

    func testExternalMultiQuantityPurchaseArrivesThroughUpdates() async throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let received = expectation(description: "External purchase is processed by transaction listener")
        var delivered: CoinPurchase?
        let purchases = PurchaseService { purchase in
            delivered = purchase
            received.fulfill()
            return .credited(try XCTUnwrap(purchase.coins))
        }
        await purchases.load()
        try await session.buyProduct(identifier: smallPack, options: [.quantity(2)])
        await fulfillment(of: [received], timeout: 15)
        XCTAssertEqual(delivered?.quantity, 2)
        XCTAssertEqual(delivered?.coins, 2_000)
        XCTAssertFalse(purchases.removesAds)
    }

    private func unfinishedCoinIDs() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  CoinPack.catalog.contains(where: { $0.id == transaction.productID }) else { continue }
            ids.insert(String(transaction.id))
        }
        return ids
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
