import XCTest

final class GameCenterUITests: XCTestCase {
    @MainActor
    func testSignedOutGameCenterShowsProgressAndKeepsSoloPlayAvailable() {
        let app = launch(state: "offline")
        let originalMoves = app.staticTexts["moveCount"].label
        app.buttons["Settings"].tap()
        let entry = app.buttons["openGameCenter"]
        for _ in 0..<8 where !entry.isHittable { app.swipeUp() }
        XCTAssertTrue(entry.isHittable)
        entry.tap()
        XCTAssertTrue(app.buttons["signInGameCenter"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["gameCenterStatus"].label.contains("solo progress is saved"))
        XCTAssertTrue(app.buttons["gameCenterLeaderboards"].exists)
        app.buttons["signInGameCenter"].tap()
        XCTAssertTrue(app.buttons["gameCenterLeaderboards"].exists)
        capture(app, "Game Center signed out")
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["moveCount"].label, originalMoves)
    }

    @MainActor
    func testDashboardOpensAndDismissesFromBothDestinations() {
        let app = launch(state: "authenticated")
        app.tabBars.buttons["Challenges"].tap()
        app.buttons["openGameCenter"].tap()
        XCTAssertTrue(app.buttons["gameCenterLeaderboards"].waitForExistence(timeout: 5))
        app.buttons["gameCenterLeaderboards"].tap()
        XCTAssertTrue(app.buttons["gameCenterDashboardDone"].waitForExistence(timeout: 5))
        app.buttons["gameCenterDashboardDone"].tap()
        let achievements = app.buttons["gameCenterAchievements"]
        for _ in 0..<6 where !achievements.isHittable { app.swipeUp() }
        XCTAssertTrue(achievements.isHittable)
        achievements.tap()
        XCTAssertTrue(app.buttons["gameCenterDashboardDone"].waitForExistence(timeout: 5))
        app.buttons["gameCenterDashboardDone"].tap()
        XCTAssertTrue(achievements.waitForExistence(timeout: 5))
        capture(app, "Game Center achievements")
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testGameCenterSupportsAccessibilityText() {
        let app = launch(state: "offline", largeText: true)
        app.tabBars.buttons["Challenges"].tap()
        let entry = app.buttons["openGameCenter"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        entry.tap()
        let signIn = app.buttons["signInGameCenter"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        for _ in 0..<4 where !signIn.isHittable { app.swipeUp() }
        XCTAssertTrue(signIn.isHittable)
        capture(app, "Game Center accessibility text")
        let achievements = app.buttons["gameCenterAchievements"]
        for _ in 0..<10 where !achievements.isHittable { app.swipeUp() }
        XCTAssertTrue(achievements.isHittable)
        capture(app, "Game Center accessibility achievements")
    }

    @MainActor
    private func launch(state: String, largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment["PRISM_GAME_CENTER_STATE"] = state
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 25))
        return app
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ title: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = title
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
