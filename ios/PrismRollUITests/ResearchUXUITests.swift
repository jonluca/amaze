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
        app.buttons["reward_skip"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists, "Unavailable ads retry inline without a modal")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        capture(app, "free-first-maze-hint")
    }

    @MainActor
    func testPauseFreezesTimerAndResumesTheSameRun() {
        let app = launch()
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        app.buttons["reward_hint"].tap()
        swipe(app.otherElements["mazeBoard"], hintDirection(app))
        app.buttons["pauseGame"].tap()
        XCTAssertTrue(app.buttons["resumeGame"].waitForExistence(timeout: 3))
        let remaining = app.staticTexts["timeRemaining"].label
        let changes = NSPredicate { _, _ in app.staticTexts["timeRemaining"].label != remaining }
        let paused = XCTNSPredicateExpectation(predicate: changes, object: nil)
        paused.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [paused], timeout: 2), .completed)
        capture(app, "native-pause-guide")
        app.buttons["resumeGame"].tap()
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: changes, object: nil)], timeout: 3), .completed)
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
        let controls = visibleControls(app)
        for _ in 0..<4 where !app.buttons["pauseGame"].isHittable { controls?.swipeDown() }
        app.buttons["pauseGame"].tap()
        app.swipeUp()
        app.navigationBars.buttons["Resume"].tap()
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
        return app
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
