import StoreKitTest
import XCTest

@MainActor
final class CoinShopUITests: XCTestCase {
    func testCoinPackPurchaseSpendAndRelaunchPreserveBalance() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let wallet = app.buttons["pointsBalance"]
        XCTAssertTrue(wallet.waitForExistence(timeout: 15))
        wallet.tap()
        let purchase = app.buttons["buyCoins_1000"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.label.contains("0.99"))
        capture(app, "coin-shop-offers-local-storekit")
        purchase.tap()
        let balance = app.descendants(matching: .any).matching(identifier: "coinShopBalance").firstMatch
        expectation(for: NSPredicate(format: "label == %@", "1,000 coins"), evaluatedWith: balance)
        waitForExpectations(timeout: 15)
        capture(app, "coin-shop-purchased-local-storekit")
        app.buttons["coinShopDone"].tap()
        app.tabBars.buttons["Collection"].tap()
        let mint = app.buttons["skin_mint"]
        for _ in 0..<4 where !mint.isHittable { app.swipeUp() }
        XCTAssertTrue(mint.isHittable)
        mint.tap()
        app.alerts.buttons.matching(identifier: "confirmSkinUnlock").firstMatch.tap()
        XCTAssertEqual(wallet.label, "500 coins")

        app.terminate()
        app.launchArguments = ["--no-ads", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(wallet.waitForExistence(timeout: 15))
        XCTAssertEqual(wallet.label, "500 coins")
        wallet.tap()
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        purchase.tap()
        expectation(for: NSPredicate(format: "label == %@", "1,500 coins"), evaluatedWith: balance)
        waitForExpectations(timeout: 15)
        XCTAssertEqual(session.allTransactions().filter { $0.productIdentifier == "com.jonluca.prismroll.coins.1000" }.count, 2)
    }

    func testCoinShopOffersFitLargestTextAndCollectionEntry() throws {
        let session = try makeSession()
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--ui-test-coins", "150000", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["pointsBalance"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Collection"].tap()
        let getCoins = app.buttons["collectionGetCoins"]
        for _ in 0..<5 where !getCoins.isHittable { app.swipeUp() }
        XCTAssertTrue(getCoins.isHittable)
        getCoins.tap()
        XCTAssertTrue(app.buttons["coinShopDone"].waitForExistence(timeout: 10))
        for count in [1000, 5500, 15000] {
            let offer = app.buttons["buyCoins_\(count)"]
            for _ in 0..<12 {
                if offer.isHittable, offer.frame.maxY < app.frame.maxY - 80 { break }
                app.swipeUp()
            }
            XCTAssertTrue(offer.isHittable)
            XCTAssertGreaterThanOrEqual(offer.frame.minX, 0)
            XCTAssertLessThanOrEqual(offer.frame.maxX, app.frame.maxX)
            capture(app, "coin-shop-accessibility-\(count)")
        }
        app.buttons["coinShopDone"].tap()
    }

    private func makeSession() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
