import XCTest

final class ResearchUXUITests: XCTestCase {
    @MainActor
    func testFirstMazeTipsAndFreeHintsWorkWithoutDebugHintBypass() {
        let app = launch()
        XCTAssertTrue(app.buttons["reward_hint"].label.contains("Free hint"))
        XCTAssertTrue(app.staticTexts["Roll to the wall"].exists)
        app.buttons["hideTutorial"].tap()
        XCTAssertFalse(app.buttons["hideTutorial"].exists)
        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["hideTutorial"].exists)
        app.buttons["reward_hint"].tap()
        let direction = hintDirection(app)
        swipe(app.otherElements["mazeBoard"], direction)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(app.buttons["reward_skip"].exists)
        XCTAssertFalse(app.buttons["reward_hint"].label.lowercased().contains("no ad"))
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        capture(app, "free-first-maze-hint")
        for mode in ["Time Rush", "Limited Moves"] {
            app.segmentedControls["modePicker"].buttons[mode].tap()
            XCTAssertFalse(app.buttons["reward_hint"].exists)
            XCTAssertFalse(app.buttons["reward_extraTime"].exists)
            XCTAssertFalse(app.buttons["reward_extraMoves"].exists)
        }
        capture(app, "unavailable-rewards-hidden")
    }

    @MainActor
    func testSettingsFreezesTimerAndResumesTheSameRun() {
        let app = launch()
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        app.buttons["reward_hint"].tap()
        let board = app.otherElements["mazeBoard"]
        swipe(board, hintDirection(app))
        let paintedBoard = board.value as? String
        let stage = app.staticTexts["timeRushStage"].label
        let beforeSettings = remainingSeconds(app)
        app.buttons["Settings"].tap()
        let done = app.navigationBars["Settings"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        // The underlying clock can be hidden from accessibility while a native
        // sheet is open. Observe that the sheet stays open, then compare budgets.
        let unexpectedlyDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in !done.exists }, object: nil
        )
        unexpectedlyDismissed.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [unexpectedlyDismissed], timeout: 2), .completed)
        capture(app, "settings-freezes-time-rush")
        done.tap()
        let afterSettings = remainingSeconds(app)
        XCTAssertGreaterThanOrEqual(afterSettings, beforeSettings - 1,
                                    "Settings must freeze the budget; allow one second for opening and closing gestures")
        XCTAssertLessThanOrEqual(afterSettings, beforeSettings)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(app.staticTexts["timeRushStage"].label, stage)
        XCTAssertEqual(board.value as? String, paintedBoard)
        let afterSettingsText = String(format: "%02d:%02d", afterSettings / 60, afterSettings % 60)
        let resumes = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", afterSettingsText),
            object: app.staticTexts["timeRemaining"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [resumes], timeout: 3), .completed)
    }

    @MainActor
    func testNativeDirectionButtonsAvoidDoubleMovesAndPersist() {
        let app = launch()
        app.buttons["hideTutorial"].tap()
        app.buttons["reward_hint"].tap()
        let direction = hintDirection(app)
        app.buttons["Settings"].tap()
        let toggle = app.switches["directionButtonsToggle"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["Done"].tap()
        let button = app.buttons["direction_\(direction)"]
        if let controls = visibleControls(app) {
            for _ in 0..<4 where !button.isHittable { controls.swipeUp() }
        }
        button.tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move", "A tap must not also trigger the global swipe handler")
        button.tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(app.staticTexts["playInstructions"].label, "Wall ahead. Try another direction.")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].buttons["Done"].waitForExistence(timeout: 3))
        app.swipeUp()
        app.navigationBars["Settings"].buttons["Done"].tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.buttons["direction_up"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        capture(app, "native-direction-buttons")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["pauseGame"].exists)
        XCTAssertFalse(app.progressIndicators["Maze painted"].exists)
        return app
    }

    @MainActor
    private func remainingSeconds(_ app: XCUIApplication) -> Int {
        let text = app.staticTexts["timeRemaining"].label
        let parts = text.split(separator: ":")
        guard parts.count == 2, let minutes = Int(parts[0]), let seconds = Int(parts[1]) else {
            XCTFail("Unexpected timer text: \(text)")
            return 0
        }
        return minutes * 60 + seconds
    }

    @MainActor
    private func visibleControls(_ app: XCUIApplication) -> XCUIElement? {
        let controls = app.scrollViews["accessiblePlayControls"]
        return controls.exists ? controls : nil
    }

    @MainActor
    private func hintDirection(_ app: XCUIApplication) -> String {
        let instruction = app.staticTexts["playInstructions"].label
        XCTAssertTrue(instruction.hasPrefix("Swipe "))
        return String(instruction.dropFirst(6))
    }

    @MainActor
    private func swipe(_ board: XCUIElement, _ direction: String) {
        switch direction {
        case "up": board.swipeUp(velocity: .fast)
        case "down": board.swipeDown(velocity: .fast)
        case "left": board.swipeLeft(velocity: .fast)
        case "right": board.swipeRight(velocity: .fast)
        default: XCTFail("Missing direction: \(direction)")
        }
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
