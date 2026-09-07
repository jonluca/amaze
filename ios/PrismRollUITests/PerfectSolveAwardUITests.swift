import XCTest

final class PerfectSolveAwardUITests: XCTestCase {
    @MainActor
    func testOptimalFirstMazeAdvancesAutomaticallyAndKeepsItsAward() {
        let app = launch()
        let moves = solveFirstMaze(app)
        assertNextLevel(app)
        XCTAssertFalse(app.buttons["nextLevel"].exists)
        app.tabBars.buttons["tab_journey"].tap()
        // The quick medal can finish during XCTest's gesture synchronization.
        // Its lasting award remains inspectable without slowing real gameplay.
        XCTAssertEqual(app.buttons["journeyLevel_1"].label,
                       "Level 1, unlocked, solved optimally, best \(moves) moves")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "perfect-solve-saved-award"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testSettingsOpenedAtCompletionKeepsProgressionStable() {
        let app = launch()
        _ = solveFirstMaze(app)
        app.buttons["Settings"].tap()
        let done = app.navigationBars["Settings"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        let dismissedEarly = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !done.exists }, object: nil)
        dismissedEarly.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [dismissedEarly], timeout: 3), .completed,
                       "Completion must not dismiss Settings or skip another level")
        done.tap()
        assertNextLevel(app)
    }

    @MainActor
    func testExtraBacktrackCompletesWithoutAnOptimalAward() {
        let app = launch()
        app.buttons["reward_hint"].tap()
        let first = app.staticTexts["playInstructions"].label
        let reverse: String
        switch first {
        case "Swipe up": reverse = "Swipe down"
        case "Swipe down": reverse = "Swipe up"
        case "Swipe left": reverse = "Swipe right"
        case "Swipe right": reverse = "Swipe left"
        default: XCTFail("Missing opening hint: \(first)"); return
        }
        swipe(app, first)
        let firstStop = app.otherElements["mazeBoard"].value as? String
        swipe(app, reverse)
        swipe(app, first)
        XCTAssertEqual(app.otherElements["mazeBoard"].value as? String, firstStop,
                       "The extra two moves return to identical position and paint")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "3 moves")
        let moves = solveFirstMaze(app, startingMoves: 3)
        assertNextLevel(app)
        app.tabBars.buttons["tab_journey"].tap()
        XCTAssertEqual(app.buttons["journeyLevel_1"].label,
                       "Level 1, unlocked, solved, best \(moves) moves")
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level 001")
        return app
    }

    @MainActor
    private func solveFirstMaze(_ app: XCUIApplication, startingMoves: Int = 0) -> Int {
        var moves = startingMoves
        let award = app.otherElements["perfectSolveAward"]
        let title = app.staticTexts["levelTitle"]
        for _ in 0..<80 {
            app.buttons["reward_hint"].tap()
            let hint = app.staticTexts["playInstructions"].label
            swipe(app, hint)
            moves += 1
            if award.exists || app.mazeIsFullyPainted || (title.exists && title.label == "Level 002") {
                return moves
            }
        }
        XCTFail("The first maze did not finish in 80 hinted moves")
        return moves
    }

    @MainActor
    private func swipe(_ app: XCUIApplication, _ direction: String) {
        let board = app.otherElements["mazeBoard"]
        switch direction {
        case "Swipe up": board.swipeUp(velocity: .fast)
        case "Swipe down": board.swipeDown(velocity: .fast)
        case "Swipe left": board.swipeLeft(velocity: .fast)
        case "Swipe right": board.swipeRight(velocity: .fast)
        default: XCTFail("Missing hint: \(direction)")
        }
    }

    @MainActor
    private func assertNextLevel(_ app: XCUIApplication) {
        let nextLevel = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let title = app.staticTexts["levelTitle"]
            return title.exists && title.label == "Level 002"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [nextLevel], timeout: 8), .completed)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        XCTAssertFalse(app.otherElements["perfectSolveAward"].exists)
        XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("50"))
    }
}
