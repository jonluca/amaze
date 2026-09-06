import StoreKitTest
import XCTest

@MainActor
final class StoreKitPurchaseUITests: XCTestCase {
    func testNoAdsOfferPurchaseRestoreAndRefundWithLocalStoreKit() throws {
        continueAfterFailure = false
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let app = XCUIApplication()
        // Keep network ad/consent requests out of this isolated purchase-UI test.
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        let purchase = app.buttons["purchaseNoAds"]
        scrollTo(purchase, in: app)
        XCTAssertTrue(purchase.waitForExistence(timeout: 15))
        XCTAssertTrue(purchase.label.contains("2.99"), "The displayed amount must come from the local fixture")
        attach(app, name: "No Ads offer - simulated USD 2.99 - not production pricing")
        purchase.tap()
        XCTAssertTrue(app.staticTexts["No Ads is active"].waitForExistence(timeout: 15))
        attach(app, name: "No Ads active - verified local StoreKit purchase")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        let restore = app.buttons["restorePurchases"]
        scrollTo(restore, in: app)
        XCTAssertTrue(restore.waitForExistence(timeout: 15))
        restore.tap()
        XCTAssertTrue(app.staticTexts["No Ads is active"].waitForExistence(timeout: 15))
        let restoredStatus = NSPredicate(format: "label == %@", "No Ads restored.")
        expectation(for: restoredStatus, evaluatedWith: app.staticTexts["purchaseStatus"])
        waitForExpectations(timeout: 15)
        attach(app, name: "No Ads restored after relaunch - local StoreKit")

        let transaction = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == "com.jonluca.prismroll.removeads"
        })
        try session.refundTransaction(identifier: transaction.identifier)
        XCTAssertTrue(app.buttons["purchaseNoAds"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.staticTexts["No Ads is active"].exists)
        attach(app, name: "No Ads revoked - local StoreKit refund")
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            // XCTest can consider a row near the bottom edge hittable even when
            // the screenshot clips its content. Leave room for the disclosure.
            if element.isHittable, element.frame.midY < app.frame.height * 0.6 { return }
            app.swipeUp()
        }
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
