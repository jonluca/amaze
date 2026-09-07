import XCTest

final class TimeRushUITests: XCTestCase {
    @MainActor
    func testSharedCountdownAdvancesMazesAndPreservesRoundUntilRestart() {
        let app = XCUIApplication()
        // This existing debug flag resets the save and disables ad/consent requests.
        app.launchArguments = ["--uitesting"]
        app.launch()
        let board = app.otherElements["mazeBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        app.segmentedControls["modePicker"].buttons["Time Rush"].tap()
        assertStage(app, "Maze 1 of 5")
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Round 001")
        let initialBudget = remainingSeconds(app)
        XCTAssertGreaterThan(initialBudget, 60)

        // Executable route from TimeRushCourse.generate(number: 1).levels[0].
        // Real touch input exercises the transition without debug completion or ads.
        let openingRoute = ["left", "down", "right", "left", "down", "right", "up", "down",
                            "left", "up", "right", "down", "right", "down"]
        for direction in openingRoute.dropLast() { flick(board, direction) }
        XCTAssertEqual(app.staticTexts["moveCount"].label, "\(openingRoute.count - 1) moves")
        let secondsBeforeFinalSlide = remainingSeconds(app)
        XCTAssertGreaterThan(secondsBeforeFinalSlide, 0)
        XCTAssertLessThan(secondsBeforeFinalSlide, initialBudget)
        flick(board, openingRoute.last!)

        assertStage(app, "Maze 2 of 5")
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Round 001")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        XCTAssertGreaterThan(remainingSeconds(app), 0)
        XCTAssertLessThanOrEqual(remainingSeconds(app), secondsBeforeFinalSlide,
                                 "The second maze must retain the round's elapsed time")
        XCTAssertFalse(app.buttons["nextLevel"].exists)
        XCTAssertFalse(app.buttons["Keep rolling"].exists)
        XCTAssertFalse(app.buttons["retryLevel"].exists)
        capture(app, "time-rush-second-maze-shared-clock")

        // The next deterministic maze begins with a rightward slide. Leave real paint
        // behind so navigation must preserve both the stage and its current board.
        flick(board, "right")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        let paintedBoard = board.value as? String
        XCTAssertNotNil(paintedBoard)
        app.buttons["pauseGame"].tap()
        let resume = app.buttons["resumeGame"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        let pausedStage = app.descendants(matching: .any)
            .matching(identifier: "pausedTimeRushStage").firstMatch
        XCTAssertTrue(pausedStage.exists)
        XCTAssertTrue(accessibleText(pausedStage).contains("Maze 2 of 5"))
        let pausedClock = app.descendants(matching: .any)
            .matching(identifier: "pausedTimeRemaining").firstMatch
        XCTAssertTrue(pausedClock.exists)
        let frozenTime = accessibleText(pausedClock)
        XCTAssertNotNil(frozenTime.range(of: #"\d{2}:\d{2}"#, options: .regularExpression), "Read the visible native pause clock")
        let tickingWhilePaused = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            ([pausedClock.label, pausedClock.value as? String ?? ""]
                + pausedClock.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ") != frozenTime
        }, object: nil)
        tickingWhilePaused.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [tickingWhilePaused], timeout: 2), .completed)
        capture(app, "time-rush-paused-mid-round")
        resume.tap()

        let secondsBeforeJourney = remainingSeconds(app)
        app.tabBars.buttons["Journey"].tap()
        let sameRound = app.buttons["journeyLevel_1"]
        XCTAssertTrue(sameRound.waitForExistence(timeout: 3))
        XCTAssertEqual(sameRound.label, "Round 1, unlocked")
        sameRound.tap()
        assertStage(app, "Maze 2 of 5")
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Round 001")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(board.value as? String, paintedBoard)
        XCTAssertLessThanOrEqual(remainingSeconds(app), secondsBeforeJourney)
        let resumedTime = app.staticTexts["timeRemaining"].label
        let countingAgain = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.staticTexts["timeRemaining"].label != resumedTime
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [countingAgain], timeout: 3), .completed)
        XCTAssertGreaterThan(remainingSeconds(app), 0)
        capture(app, "time-rush-journey-resumes-second-maze")

        app.buttons["Restart round"].tap()
        let restart = app.alerts.buttons.matching(identifier: "confirmRestart").firstMatch
        XCTAssertTrue(restart.waitForExistence(timeout: 3))
        restart.tap()
        assertStage(app, "Maze 1 of 5")
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Round 001")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        XCTAssertEqual(remainingSeconds(app), initialBudget)
        XCTAssertFalse(app.buttons["retryLevel"].exists)
        capture(app, "time-rush-restart-resets-entire-round")
    }

    @MainActor
    private func assertStage(_ app: XCUIApplication, _ expected: String) {
        let stage = app.staticTexts["timeRushStage"]
        let reachesStage = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", expected), object: stage
        )
        XCTAssertEqual(XCTWaiter.wait(for: [reachesStage], timeout: 5), .completed)
        XCTAssertEqual(stage.label, expected)
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
    private func accessibleText(_ element: XCUIElement) -> String {
        ([element.label, element.value as? String ?? ""]
            + element.staticTexts.allElementsBoundByIndex.map(\.label)).joined(separator: " ")
    }

    @MainActor
    private func flick(_ board: XCUIElement, _ direction: String) {
        let start = board.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let offset: CGVector
        switch direction {
        case "up": offset = CGVector(dx: 0, dy: -36)
        case "down": offset = CGVector(dx: 0, dy: 36)
        case "left": offset = CGVector(dx: -36, dy: 0)
        case "right": offset = CGVector(dx: 36, dy: 0)
        default: XCTFail("Unknown direction: \(direction)"); return
        }
        start.press(forDuration: 0.01, thenDragTo: start.withOffset(offset),
                    withVelocity: XCUIGestureVelocity(rawValue: 1_500), thenHoldForDuration: 0)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
