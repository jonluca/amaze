import XCTest
@testable import PrismRoll

final class PurchaseRevenuePolicyTests: XCTestCase {
    private let optIn = Date(timeIntervalSince1970: 1_000)

    func testPurchaseObservedWithoutCollectionCannotBeReplayedAfterOptIn() {
        var policy = PurchaseRevenuePolicy()
        let purchaseDate = optIn.addingTimeInterval(5)
        XCTAssertEqual(policy.consume(transactionID: "declined", purchasedAt: purchaseDate,
                                      collectionPeriodStart: nil), .suppress)
        XCTAssertEqual(policy.consume(transactionID: "declined", purchasedAt: purchaseDate,
                                      collectionPeriodStart: optIn), .duplicate)
        XCTAssertEqual(policy.consume(transactionID: "new", purchasedAt: purchaseDate,
                                      collectionPeriodStart: optIn), .report)
    }

    func testPersistedLedgerDeduplicatesDeliveredPurchasesAcrossLaunches() {
        var firstLaunch = PurchaseRevenuePolicy()
        XCTAssertEqual(firstLaunch.consume(transactionID: "paid", purchasedAt: optIn,
                                           collectionPeriodStart: optIn), .report)
        let persistedIDs = firstLaunch.handledTransactionIDs
        var nextLaunch = PurchaseRevenuePolicy(handledTransactionIDs: persistedIDs)
        XCTAssertEqual(nextLaunch.consume(transactionID: "paid", purchasedAt: optIn,
                                          collectionPeriodStart: optIn), .duplicate)
        XCTAssertEqual(nextLaunch.consume(transactionID: "another", purchasedAt: optIn,
                                          collectionPeriodStart: optIn), .report)
        XCTAssertEqual(nextLaunch.handledTransactionIDs, ["paid", "another"])
    }

    func testFreshInstallRestoreAndOptInMigrationExcludeHistoricalRevenue() {
        var policy = PurchaseRevenuePolicy()
        XCTAssertEqual(policy.consume(transactionID: "restored", purchasedAt: optIn.addingTimeInterval(-1),
                                      collectionPeriodStart: optIn), .suppress)
        XCTAssertEqual(policy.consume(transactionID: "current", purchasedAt: optIn,
                                      collectionPeriodStart: optIn), .report)
    }

    func testReenablingCollectionExcludesPurchasesFromEarlierParticipationPeriod() {
        var policy = PurchaseRevenuePolicy()
        let secondOptIn = optIn.addingTimeInterval(100)
        XCTAssertEqual(policy.consume(transactionID: "recovered-old", purchasedAt: optIn,
                                      collectionPeriodStart: secondOptIn), .suppress)
        XCTAssertEqual(policy.consume(transactionID: "recovered-current", purchasedAt: secondOptIn,
                                      collectionPeriodStart: secondOptIn), .report)
    }

    func testSuppressionSurvivesRecreationEvenWhenSDKIdentifierWasReset() {
        var firstLaunch = PurchaseRevenuePolicy()
        XCTAssertEqual(firstLaunch.consume(transactionID: "opted-out", purchasedAt: optIn,
                                           collectionPeriodStart: nil), .suppress)
        var nextLaunch = PurchaseRevenuePolicy(handledTransactionIDs: firstLaunch.handledTransactionIDs)
        XCTAssertEqual(nextLaunch.consume(transactionID: "opted-out", purchasedAt: optIn,
                                          collectionPeriodStart: optIn), .duplicate)
    }
}
