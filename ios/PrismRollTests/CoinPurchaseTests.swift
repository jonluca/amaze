import XCTest
@testable import PrismRoll

final class CoinPurchaseTests: XCTestCase {
    func testCatalogMapsVerifiedProductQuantityToCurrency() {
        XCTAssertEqual(Set(CoinPack.catalog.map(\.id)).count, 3)
        XCTAssertEqual(CoinPack.catalog.map(\.coins), [1_000, 5_500, 15_000])
        for pack in CoinPack.catalog {
            XCTAssertEqual(CoinPurchase(transactionID: "1234", productID: pack.id, quantity: 2).coins, pack.coins * 2)
        }
    }

    func testInvalidTransactionProductQuantityAndOverflowCannotCreditCoins() {
        let id = CoinPack.catalog[0].id
        XCTAssertNil(CoinPurchase(transactionID: "", productID: id, quantity: 1).coins)
        XCTAssertNil(CoinPurchase(transactionID: "1234", productID: "unknown", quantity: 1).coins)
        XCTAssertNil(CoinPurchase(transactionID: "1234", productID: "com.jonluca.prismroll.removeads", quantity: 1).coins)
        XCTAssertNil(CoinPurchase(transactionID: "1234", productID: id, quantity: 0).coins)
        XCTAssertNil(CoinPurchase(transactionID: "1234", productID: id, quantity: -1).coins)
        XCTAssertNil(CoinPurchase(transactionID: "1234", productID: id, quantity: Int.max).coins)
    }
}
