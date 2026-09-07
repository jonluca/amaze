import XCTest

final class UXPlaytestUITests: XCTestCase {
    @MainActor
    func testJourneyContinuesAndRestartProtectsPaintedPaths() {
        let app = launch()
        moveWithHint(app)
        let board = app.otherElements["mazeBoard"]
        let painted = board.value as? String
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")

        app.tabBars.buttons["Levels"].tap()
        app.buttons["journeyLevel_1"].tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(board.value as? String, painted)

        app.buttons["Restart level"].tap()
        XCTAssertTrue(app.alerts.buttons.matching(identifier: "cancelRestart").firstMatch.waitForExistence(timeout: 3))
        app.alerts.buttons.matching(identifier: "cancelRestart").firstMatch.tap()
        XCTAssertEqual(board.value as? String, painted)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")

        app.buttons["Restart level"].tap()
        app.alerts.buttons.matching(identifier: "confirmRestart").firstMatch.tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        XCTAssertNotEqual(board.value as? String, painted)
        moveWithHint(app)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        capture(app, "journey-resume-and-restart")
    }

    @MainActor
    func testRestartPromptPausesTimeRush() {
        let app = launch()
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        moveWithHint(app)
        app.buttons["Restart round"].tap()
        XCTAssertTrue(app.alerts.buttons.matching(identifier: "cancelRestart").firstMatch.waitForExistence(timeout: 3))
        let remaining = app.staticTexts["timeRemaining"].label
        let paused = NSPredicate { _, _ in app.staticTexts["timeRemaining"].label != remaining }
        let noCountdown = XCTNSPredicateExpectation(predicate: paused, object: nil)
        noCountdown.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [noCountdown], timeout: 2), .completed)
        app.alerts.buttons.matching(identifier: "cancelRestart").firstMatch.tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        let counting = XCTNSPredicateExpectation(predicate: paused, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [counting], timeout: 3), .completed)
    }

    @MainActor
    func testDailyReplayStartsANewRunWithoutPayingTwice() {
        let app = launch()
        app.tabBars.buttons["Challenges"].tap()
        app.buttons["playDaily"].tap()
        solve(app)
        let coins = app.otherElements.matching(identifier: "pointsBalance").firstMatch.label
        XCTAssertTrue(coins.contains("100"))
        app.tabBars.buttons["Challenges"].tap()
        XCTAssertEqual(app.buttons["playDaily"].label, "Replay daily maze")
        app.buttons["playDaily"].tap()
        XCTAssertFalse(app.buttons["nextLevel"].exists)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        solve(app)
        XCTAssertEqual(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label, coins)
        capture(app, "daily-replayed-without-duplicate-coins")
    }

    @MainActor
    func testSkinPurchaseCancellationAndEquippingStayInCollection() {
        let app = launch()
        solve(app)
        solve(app)
        app.tabBars.buttons["Collection"].tap()
        let skin = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'skin_' AND label CONTAINS '100 coins'")).firstMatch
        XCTAssertTrue(skin.waitForExistence(timeout: 3))
        let wallet = app.otherElements.matching(identifier: "pointsBalance").firstMatch
        skin.tap()
        app.alerts.buttons.matching(identifier: "cancelSkinUnlock").firstMatch.tap()
        XCTAssertTrue(wallet.label.contains("100"))
        skin.tap()
        app.alerts.buttons.matching(identifier: "confirmSkinUnlock").firstMatch.tap()
        XCTAssertTrue(wallet.label.contains("0"))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        let firstBall = app.buttons["skin_coral"]
        XCTAssertTrue(firstBall.exists)
        firstBall.tap()
        XCTAssertTrue(firstBall.label.contains("equipped"))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(wallet.label.contains("0"))
        capture(app, "collection-unlock-and-equip")
    }

    @MainActor
    func testLargeTextKeepsAllModesPlayableAndUnavailableRewardsHidden() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
        let board = app.otherElements["mazeBoard"]
        XCTAssertGreaterThan(board.frame.height, 100)
        for mode in ["Classic", "Time Rush", "Limited Moves"] {
            let controls = app.scrollViews["accessiblePlayControls"]
            if controls.exists {
                for _ in 0..<4 where !app.segmentedControls["modePicker"].isHittable { controls.swipeDown() }
            }
            app.segmentedControls["modePicker"].buttons[mode].tap()
            let hint = app.buttons["reward_hint"]
            if controls.exists {
                for _ in 0..<4 where !hint.isHittable { controls.swipeUp() }
            }
            XCTAssertTrue(hint.isHittable)
            XCTAssertTrue(hint.label.lowercased().contains(mode == "Classic" ? "free hint" : "watch ad"))
            let secondID = mode == "Classic" ? "reward_skip" : mode == "Time Rush" ? "reward_extraTime" : "reward_extraMoves"
            XCTAssertFalse(app.buttons[secondID].exists)
            moveWithHint(app)
            XCTAssertTrue(board.isHittable)
        }
        capture(app, "large-text-play")
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"] + extra
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        return app
    }

    @MainActor
    private func moveWithHint(_ app: XCUIApplication) {
        app.buttons["reward_hint"].tap()
        let direction = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Swipe '")).firstMatch.label
        let board = app.otherElements["mazeBoard"]
        switch direction {
        case "Swipe up": board.swipeUp(velocity: .fast)
        case "Swipe down": board.swipeDown(velocity: .fast)
        case "Swipe left": board.swipeLeft(velocity: .fast)
        case "Swipe right": board.swipeRight(velocity: .fast)
        default: XCTFail("No direction available: \(direction)")
        }
    }

    @MainActor
    private func solve(_ app: XCUIApplication) {
        let initialLevel = app.staticTexts["levelTitle"].label
        for _ in 0..<80 {
            if app.waitForMazeAdvanceAfterCompletion(from: initialLevel) { return }
            if app.staticTexts["levelTitle"].label != initialLevel { return }
            moveWithHint(app)
        }
        XCTFail("Maze did not finish")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
