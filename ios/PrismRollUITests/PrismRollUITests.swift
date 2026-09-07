import XCTest

final class PrismRollUITests: XCTestCase {
    @MainActor
    func testAccessibilityTextKeepsBoardAndControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let controls = app.scrollViews["accessiblePlayControls"]
        XCTAssertTrue(controls.waitForExistence(timeout: 15), "Use the actual accessibility text-size layout")
        let board = app.otherElements["mazeBoard"]
        XCTAssertTrue(board.exists)
        XCTAssertGreaterThan(board.frame.height, 100)
        XCTAssertTrue(app.segmentedControls["modePicker"].isHittable)
        let restart = app.buttons["Restart level"]
        for _ in 0..<4 where !restart.isHittable { controls.swipeUp() }
        XCTAssertTrue(restart.isHittable)
        restart.tap()
        let hint = app.buttons["reward_hint"]
        for _ in 0..<12 where !hint.isHittable {
            let start = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = controls.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
        XCTAssertTrue(hint.isHittable)
        hint.tap()
        XCTAssertTrue(board.isHittable, "Scrolling controls must leave the board available for swipes")
        capture(app, name: "13-accessibility-text")
    }

    @MainActor
    func testShortFlicksOutsideBoardAndNativeControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["levelTitle"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["Play"].exists)
        XCTAssertTrue(app.segmentedControls["modePicker"].exists)
        app.buttons["reward_hint"].tap()
        let hint = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Swipe '")).firstMatch.label
        let title = app.staticTexts["levelTitle"]
        XCTAssertTrue(title.exists)
        let origin = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let vector: CGVector
        switch hint {
        case "Swipe up": vector = CGVector(dx: 0, dy: -24)
        case "Swipe down": vector = CGVector(dx: 0, dy: 24)
        case "Swipe left": vector = CGVector(dx: -24, dy: 0)
        case "Swipe right": vector = CGVector(dx: 24, dy: 0)
        default: XCTFail("No initial direction: \(hint)"); return
        }
        for index in 0..<10 {
            let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let end = origin.withOffset(CGVector(dx: vector.dx * sign, dy: vector.dy * sign))
            origin.press(forDuration: 0.01, thenDragTo: end,
                         withVelocity: XCUIGestureVelocity(rawValue: 1_500), thenHoldForDuration: 0)
        }
        XCTAssertEqual(app.staticTexts["moveCount"].label, "10 moves", "Short flicks on the heading must register once each")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["hapticsToggle"].waitForExistence(timeout: 3))
        app.swipeUp()
        app.buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "10 moves", "Settings scrolling must not move the ball")
        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.buttons["worldPicker"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Play"].tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "10 moves")
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        XCTAssertTrue(app.staticTexts["timeRemaining"].exists)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves", "A native picker tap must not also swipe the maze")
        capture(app, name: "12-native-play")
    }

    @MainActor
    func testPlayProgressionShopAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        capture(app, name: "01-first-level")
        solve(app)
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level 002")
        XCTAssertFalse(app.buttons["Keep rolling"].exists)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("50"))
        capture(app, name: "02-completed")
        solve(app)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("100"))
        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.buttons["worldPicker"].waitForExistence(timeout: 3))
        capture(app, name: "03-collection")
        let affordableSkin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'skin_' AND label CONTAINS '100 coins'")).firstMatch
        XCTAssertTrue(affordableSkin.exists)
        affordableSkin.tap()
        app.alerts.buttons.matching(identifier: "confirmSkinUnlock").firstMatch.tap()
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("0"))
        app.terminate()
        app.launchArguments = ["--no-ads", "--ui-hints"]
        app.launch()
        app.tabBars.buttons["Collection"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'skin_' AND label CONTAINS 'equipped'")).count, 1)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("0"))
        app.tabBars.buttons["Levels"].tap()
        XCTAssertTrue(app.staticTexts["journeyHeading"].waitForExistence(timeout: 3))
        capture(app, name: "04-journey")
        app.buttons["journeyLevel_1"].tap()
        solve(app)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("0"), "Replay must not farm points")
    }

    @MainActor
    func testChallengeAndSettings() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.segmentedControls["modePicker"].buttons["Limited Moves"].tap()
        XCTAssertTrue(app.otherElements["movesRemaining"].exists)
        capture(app, name: "05-challenge")
        solve(app)
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level 002")
        XCTAssertFalse(app.buttons["Keep rolling"].exists)
        capture(app, name: "06-challenge-complete")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["hapticsToggle"].exists)
        app.switches["hapticsToggle"].tap()
        app.buttons["Done"].tap()
    }

    @MainActor
    private func solve(_ app: XCUIApplication) {
        let board = app.otherElements["mazeBoard"]
        let initialLevel = app.staticTexts["levelTitle"].label
        for _ in 0..<80 {
            if app.waitForMazeAdvanceAfterCompletion(from: initialLevel) { return }
            if app.staticTexts["levelTitle"].label != initialLevel { return }
            app.buttons["reward_hint"].tap()
            if app.waitForMazeAdvanceAfterCompletion(from: initialLevel) { return }
            if app.staticTexts["levelTitle"].label != initialLevel { return }
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
        app.segmentedControls["modePicker"].buttons["Limited Moves"].tap()
        let budgetLabel = app.otherElements["movesRemaining"].label
        let budget = Int(budgetLabel.split(separator: " ")[0]) ?? 0
        XCTAssertGreaterThan(budget, 0)
        app.buttons["reward_hint"].tap()
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
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("0"))
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
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        XCTAssertEqual(app.staticTexts["timeRemaining"].label, "00:02")
        capture(app, name: "07-time-rush")
        app.buttons["reward_hint"].tap()
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
        XCTAssertFalse(app.buttons["reward_extraTime"].exists)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("0"))
        capture(app, name: "08-time-expired")
        app.buttons["retryLevel"].tap()
        XCTAssertEqual(app.staticTexts["timeRemaining"].label, "00:02")
    }

    @MainActor
    func testDailyRewardsThemesAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.tabBars.buttons["Challenges"].tap()
        XCTAssertTrue(app.buttons["claimDaily"].isEnabled)
        capture(app, name: "09-daily-challenges")
        app.buttons["claimDaily"].tap()
        app.alerts.buttons["Got it"].tap()
        XCTAssertFalse(app.buttons["claimDaily"].isEnabled)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("25"))
        app.buttons["playDaily"].tap()
        XCTAssertTrue(app.staticTexts["Today’s maze"].exists)
        XCTAssertTrue(app.otherElements["movesRemaining"].exists)
        capture(app, name: "10-daily-maze")
        app.tabBars.buttons["Collection"].tap()
        app.buttons["worldPicker"].tap()
        app.buttons["theme_timber"].tap()
        if !app.buttons["worldPicker"].exists {
            app.navigationBars.buttons["Collection"].tap()
        }
        app.tabBars.buttons["Play"].tap()
        capture(app, name: "11-timber-theme")
        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today’s maze"].exists)
        app.tabBars.buttons["Challenges"].tap()
        XCTAssertFalse(app.buttons["claimDaily"].isEnabled)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("25"))
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
