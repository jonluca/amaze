import XCTest

final class PrismRollUITests: XCTestCase {
    @MainActor
    func testPlayProgressionShopAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        capture(app, name: "01-first-level")
        solve(app)
        XCTAssertTrue(app.staticTexts["Beautifully done."].exists)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("50"))
        capture(app, name: "02-completed")
        app.buttons["nextLevel"].tap()
        solve(app)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("100"))
        app.buttons["tab_collection"].tap()
        XCTAssertTrue(app.staticTexts["Find your color."].waitForExistence(timeout: 3))
        capture(app, name: "03-collection")
        let affordableSkin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'skin_' AND label CONTAINS '100 coins'")).firstMatch
        XCTAssertTrue(affordableSkin.exists)
        affordableSkin.tap()
        app.alerts.buttons["Got it"].tap()
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("0"))
        app.terminate()
        app.launchArguments = ["--no-ads", "--ui-hints"]
        app.launch()
        app.buttons["tab_collection"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'skin_' AND label CONTAINS 'equipped'")).count, 1)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("0"))
        app.buttons["tab_journey"].tap()
        XCTAssertTrue(app.staticTexts["journeyHeading"].waitForExistence(timeout: 3))
        capture(app, name: "04-journey")
        app.buttons["Level 1, unlocked"].tap()
        solve(app)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("0"), "Replay must not farm points")
    }

    @MainActor
    func testChallengeAndSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["mode_challenge"].tap()
        XCTAssertTrue(app.otherElements["movesRemaining"].exists)
        capture(app, name: "05-challenge")
        solve(app)
        XCTAssertTrue(app.staticTexts["Beautifully done."].exists)
        capture(app, name: "06-challenge-complete")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Gentle haptics"].exists)
        app.switches["Gentle haptics"].tap()
        app.buttons["Done"].tap()
    }

    @MainActor
    private func solve(_ app: XCUIApplication) {
        let board = app.otherElements["mazeBoard"]
        for _ in 0..<80 {
            if app.buttons["nextLevel"].exists { return }
            app.buttons["Show hint"].tap()
            let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Swipe '")).firstMatch.label
            switch hint {
            case "Swipe up": board.swipeUp(velocity: .slow)
            case "Swipe down": board.swipeDown(velocity: .slow)
            case "Swipe left": board.swipeLeft(velocity: .slow)
            case "Swipe right": board.swipeRight(velocity: .slow)
            default: XCTFail("No useful hint: \(hint)"); return
            }
        }
        XCTFail("Did not finish in 80 swipes")
    }

    @MainActor
    func testChallengeFailureAndRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["mode_challenge"].tap()
        let budgetLabel = app.otherElements["movesRemaining"].label
        let budget = Int(budgetLabel.split(separator: " ")[0]) ?? 0
        XCTAssertGreaterThan(budget, 0)
        app.buttons["Show hint"].tap()
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Swipe '")).firstMatch.label
        let board = app.otherElements["mazeBoard"]
        for index in 0..<budget {
            let outward = index.isMultiple(of: 2)
            switch hint {
            case "Swipe up": outward ? board.swipeUp() : board.swipeDown()
            case "Swipe down": outward ? board.swipeDown() : board.swipeUp()
            case "Swipe left": outward ? board.swipeLeft() : board.swipeRight()
            case "Swipe right": outward ? board.swipeRight() : board.swipeLeft()
            default: XCTFail("Invalid first hint"); return
            }
        }
        XCTAssertTrue(app.buttons["retryLevel"].exists)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("0"))
        app.buttons["retryLevel"].tap()
        XCTAssertEqual(app.otherElements["movesRemaining"].label, budgetLabel)
        XCTAssertFalse(app.buttons["retryLevel"].exists)
        XCTAssertTrue(board.exists)
    }

    @MainActor
    func testTimeRushExpiresAndRetries() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--short-timer"]
        app.launch()
        app.buttons["mode_timed"].tap()
        XCTAssertEqual(app.staticTexts["timeRemaining"].label, "00:02")
        capture(app, name: "07-time-rush")
        app.buttons["Show hint"].tap()
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Swipe '")).firstMatch.label
        let board = app.otherElements["mazeBoard"]
        switch hint {
        case "Swipe up": board.swipeUp()
        case "Swipe down": board.swipeDown()
        case "Swipe left": board.swipeLeft()
        case "Swipe right": board.swipeRight()
        default: XCTFail("Missing hint"); return
        }
        XCTAssertTrue(app.staticTexts["Out of time."].waitForExistence(timeout: 6))
        XCTAssertTrue(app.buttons["reward_extraTime"].exists)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("0"))
        capture(app, name: "08-time-expired")
        app.buttons["retryLevel"].tap()
        XCTAssertEqual(app.staticTexts["timeRemaining"].label, "00:02")
    }

    @MainActor
    func testDailyRewardsThemesAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tab_challenges"].tap()
        XCTAssertTrue(app.buttons["claimDaily"].isEnabled)
        capture(app, name: "09-daily-challenges")
        app.buttons["claimDaily"].tap()
        app.alerts.buttons["Got it"].tap()
        XCTAssertFalse(app.buttons["claimDaily"].isEnabled)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("25"))
        app.buttons["playDaily"].tap()
        XCTAssertTrue(app.staticTexts["Today’s maze"].exists)
        XCTAssertTrue(app.otherElements["movesRemaining"].exists)
        capture(app, name: "10-daily-maze")
        app.buttons["tab_collection"].tap()
        app.buttons["theme_timber"].tap()
        app.buttons["tab_play"].tap()
        capture(app, name: "11-timber-theme")
        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today’s maze"].exists)
        app.buttons["tab_challenges"].tap()
        XCTAssertFalse(app.buttons["claimDaily"].isEnabled)
        XCTAssertTrue(app.otherElements["pointsBalance"].label.contains("25"))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
