#if canImport(UIKit)
import Foundation
import XCTest
@testable import PrismRoll

@MainActor
final class CoinWalletTests: XCTestCase {
    func testVerifiedDeliveryAndSpendingSurviveRelaunchWithoutDuplicateCredit() throws {
        let suite = "CoinWalletTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let directory = FileManager.default.temporaryDirectory.appending(path: suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "progress.json")
        let purchase = CoinPurchase(transactionID: "verified-1", productID: "com.jonluca.prismroll.coins.15000", quantity: 1)
        let store = GameStore(defaults: defaults, progressFileURL: url)
        XCTAssertEqual(try store.deliverCoinPurchase(purchase), .credited(15_000))
        store.selectSkin(try XCTUnwrap(BallSkin.catalog.first { $0.id == "mint" }))
        XCTAssertEqual(store.progress.points, 14_500)

        // Simulate a stale asynchronous run snapshot. The durable wallet takes priority.
        defaults.removeObject(forKey: "prism.snapshot.v2")
        let resumed = GameStore(defaults: defaults, progressFileURL: url)
        XCTAssertEqual(resumed.progress.points, 14_500)
        XCTAssertTrue(resumed.progress.ownedSkinIDs.contains("mint"))
        XCTAssertEqual(try resumed.deliverCoinPurchase(purchase), .alreadyDelivered)
        XCTAssertEqual(resumed.progress.points, 14_500)
        XCTAssertEqual(try resumed.deliverCoinPurchase(CoinPurchase(transactionID: "verified-2", productID: purchase.productID, quantity: 2)), .credited(30_000))
        XCTAssertEqual(resumed.progress.points, 44_500)
    }

    func testFailedAtomicWriteDoesNotCreditOrMarkReceiptDelivered() throws {
        let suite = "CoinWalletFailure.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let blocker = FileManager.default.temporaryDirectory.appending(path: suite)
        try Data("not a directory".utf8).write(to: blocker)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: blocker) }
        let store = GameStore(defaults: defaults, progressFileURL: blocker.appending(path: "progress.json"))
        let purchase = CoinPurchase(transactionID: "uncommitted", productID: "com.jonluca.prismroll.coins.1000", quantity: 1)
        XCTAssertThrowsError(try store.deliverCoinPurchase(purchase))
        XCTAssertEqual(store.progress.points, 0)
        XCTAssertFalse(store.progress.receivedCoinTransactionIDs.contains("uncommitted"))
    }

    func testCorruptWalletIsPreservedAndCannotAcknowledgePurchases() throws {
        let suite = "CoinWalletCorrupt.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory.appending(path: suite)
        let corrupt = Data("incomplete wallet".utf8)
        try corrupt.write(to: url)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        let store = GameStore(defaults: defaults, progressFileURL: url)
        XCTAssertThrowsError(try store.deliverCoinPurchase(CoinPurchase(transactionID: "retry-later", productID: "com.jonluca.prismroll.coins.1000", quantity: 1)))
        store.setHaptics(false)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
        XCTAssertEqual(store.progress.points, 0)
    }

    func testInvalidProductAndOverflowCannotChangeWallet() throws {
        let suite = "CoinWalletInvalid.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory.appending(path: suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        let store = GameStore(defaults: defaults, progressFileURL: url)
        for purchase in [
            CoinPurchase(transactionID: "unknown", productID: "unknown", quantity: 1),
            CoinPurchase(transactionID: "zero", productID: "com.jonluca.prismroll.coins.1000", quantity: 0),
            CoinPurchase(transactionID: "overflow", productID: "com.jonluca.prismroll.coins.1000", quantity: Int.max)
        ] { XCTAssertThrowsError(try store.deliverCoinPurchase(purchase)) }
        XCTAssertEqual(store.progress.points, 0)
        XCTAssertTrue(store.progress.receivedCoinTransactionIDs.isEmpty)
    }

    func testVideoRewardsRequireCurrentEarnedCallbackAndCanRepeat() throws {
        let suite = "CoinVideoReward.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.claimCoinReward(UUID()), 0)
        let cancelled = try XCTUnwrap(store.beginCoinReward())
        XCTAssertNil(store.beginCoinReward())
        store.finishReward()
        XCTAssertEqual(store.claimCoinReward(cancelled), 0)
        XCTAssertEqual(store.progress.points, 0)
        let first = try XCTUnwrap(store.beginCoinReward())
        XCTAssertEqual(store.claimCoinReward(first), 50)
        XCTAssertEqual(store.claimCoinReward(first), 0)
        store.finishReward()
        let second = try XCTUnwrap(store.beginCoinReward())
        XCTAssertEqual(store.claimCoinReward(first), 0)
        XCTAssertEqual(store.claimCoinReward(second), 50)
        store.finishReward()
        XCTAssertEqual(store.progress.points, 100)
        XCTAssertEqual(GameStore(defaults: defaults).progress.points, 100)
    }
}
#endif
