import XCTest

final class CollectionRarityUITests: XCTestCase {
    @MainActor
    func testRarityFiltersShowPricesAndKeepUnaffordableBallsLocked() {
        let app = launch()
        let mint = app.buttons["skin_mint"]
        XCTAssertTrue(mint.waitForExistence(timeout: 3))
        XCTAssertTrue(mint.label.contains("Common"))
        XCTAssertTrue(mint.label.contains("500 coins"))
        XCTAssertFalse(mint.isEnabled)
        capture(app, "collection-common")

        let tiers: [(String, String, String)] = [
            ("Uncommon", "tidal", "1,500"), ("Rare", "ember", "5,000"),
            ("Epic", "nova", "13,000"), ("Legendary", "solar-flare", "30,000"),
            ("Mythic", "singularity", "75,000")
        ]
        for (rarity, id, price) in tiers {
            select(rarity, in: app)
            let ball = app.buttons["skin_\(id)"]
            XCTAssertTrue(ball.waitForExistence(timeout: 3))
            XCTAssertTrue(ball.label.contains(rarity))
            XCTAssertTrue(ball.label.contains("\(price) coins"))
            XCTAssertFalse(ball.isEnabled)
            XCTAssertFalse(app.buttons["skin_coral"].exists)
            if rarity == "Legendary" || rarity == "Mythic" {
                app.swipeUp()
                capture(app, "collection-\(rarity.lowercased())")
                app.swipeDown()
            }
        }
        select("All rarities", in: app)
        XCTAssertTrue(app.buttons["skin_coral"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testMythicPurchaseConfirmationAndOwnershipSurviveRelaunch() {
        let app = launch(extra: ["--ui-test-coins", "150000"])
        select("Mythic", in: app)
        let genesis = app.buttons["skin_genesis"]
        for _ in 0..<3 where !genesis.isHittable { app.swipeUp() }
        XCTAssertTrue(genesis.isEnabled)
        genesis.tap()
        XCTAssertTrue(app.alerts.staticTexts.matching(NSPredicate(format: "label CONTAINS '150,000' AND label CONTAINS 'mythic'")).firstMatch.exists)
        app.alerts.buttons.matching(identifier: "cancelSkinUnlock").firstMatch.tap()
        XCTAssertTrue(genesis.label.contains("unlock for 150,000 coins"))
        genesis.tap()
        app.alerts.buttons.matching(identifier: "confirmSkinUnlock").firstMatch.tap()
        XCTAssertEqual(genesis.label, "Genesis, Mythic, equipped")
        XCTAssertEqual(wallet(app).label, "0 coins")
        capture(app, "collection-genesis-owned")

        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        capture(app, "genesis-in-game")
        app.tabBars.buttons["Collection"].tap()
        select("Mythic", in: app)
        for _ in 0..<3 where !genesis.isHittable { app.swipeUp() }
        XCTAssertEqual(genesis.label, "Genesis, Mythic, equipped")
        XCTAssertEqual(wallet(app).label, "0 coins")
    }

    @MainActor
    func testMythicPricesRemainReadableAtAccessibilityTextSize() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        select("Mythic", in: app)
        let genesis = app.buttons["skin_genesis"]
        for _ in 0..<10 where !genesis.isHittable { app.swipeUp() }
        XCTAssertTrue(genesis.isHittable)
        XCTAssertTrue(genesis.label.contains("150,000 coins"))
        XCTAssertFalse(genesis.isEnabled)
        app.swipeUp()
        capture(app, "collection-mythic-accessibility")
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.buttons["rarityPicker"].waitForExistence(timeout: 3))
        return app
    }

    @MainActor
    private func select(_ rarity: String, in app: XCUIApplication) {
        let picker = app.buttons["rarityPicker"]
        for _ in 0..<10 where !picker.isHittable { app.swipeDown() }
        picker.tap()
        app.buttons[rarity].tap()
    }

    @MainActor
    private func wallet(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "pointsBalance").firstMatch
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
