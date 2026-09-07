import XCTest

final class LevelBrowserUITests: XCTestCase {
    @MainActor
    func testPerfectSolveKeepsCrownAndBestMovesAfterRelaunch() {
        let app = launch()
        let moves = solveFirstMaze(app)
        openLevels(app)
        let firstLevel = app.buttons["journeyLevel_1"]
        XCTAssertEqual(firstLevel.label, "Level 1, unlocked, solved optimally, best \(moves) moves")
        capture(app, "levels-optimal-crown")

        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        openLevels(app)
        XCTAssertEqual(firstLevel.label, "Level 1, unlocked, solved optimally, best \(moves) moves")

        app.segmentedControls["modePicker"].buttons["Limited Moves"].tap()
        XCTAssertEqual(firstLevel.label, "Level 1, unlocked, not solved",
                       "Completion and crowns belong to the selected mode")
        app.segmentedControls["modePicker"].buttons["Classic"].tap()
        XCTAssertEqual(firstLevel.label, "Level 1, unlocked, solved optimally, best \(moves) moves")
    }

    @MainActor
    func testExtraBacktrackKeepsSolvedCheckmarkWithoutCrown() {
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
        swipe(app, reverse)
        swipe(app, first)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "3 moves")

        let moves = solveFirstMaze(app, startingMoves: 3)
        openLevels(app)
        XCTAssertEqual(app.buttons["journeyLevel_1"].label, "Level 1, unlocked, solved, best \(moves) moves")
        capture(app, "levels-solved-checkmark")

        app.terminate()
        app.launchArguments = ["--no-ads"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        openLevels(app)
        XCTAssertEqual(app.buttons["journeyLevel_1"].label, "Level 1, unlocked, solved, best \(moves) moves")
    }

    @MainActor
    func testBrowseAndJumpToFutureLevelsKeepsThemLocked() {
        let app = launch()
        openLevels(app)
        XCTAssertEqual(app.staticTexts["journeyRange"].label, "Levels 1–20")
        XCTAssertTrue(app.buttons["journeyLater"].isEnabled)
        app.buttons["journeyLater"].tap()
        XCTAssertEqual(app.staticTexts["journeyRange"].label, "Levels 21–40")
        XCTAssertEqual(app.buttons["journeyLevel_21"].label, "Level 21, locked, not solved")
        XCTAssertFalse(app.buttons["journeyLevel_21"].isEnabled)

        app.buttons["journeyJump"].tap()
        app.buttons["journeyJumpToNumber"].tap()
        let number = app.alerts.textFields.firstMatch
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        number.typeText("1000")
        app.alerts.buttons["journeyJumpGo"].firstMatch.tap()
        XCTAssertEqual(app.staticTexts["journeyRange"].label, "Levels \(1_000.formatted())–\(1_019.formatted())")
        XCTAssertEqual(app.buttons["journeyLevel_1000"].label, "Level 1000, locked, not solved")
        XCTAssertFalse(app.buttons["journeyLevel_1000"].isEnabled)
        capture(app, "levels-browse-future")

        app.buttons["journeyJump"].tap()
        app.buttons["Current level"].tap()
        XCTAssertEqual(app.staticTexts["journeyRange"].label, "Levels 1–20")
        XCTAssertTrue(app.buttons["journeyLevel_1"].isEnabled)
        app.buttons["journeyLevel_1"].tap()
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level 001")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
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
    private func openLevels(_ app: XCUIApplication) {
        app.tabBars.buttons["Levels"].tap()
        XCTAssertTrue(app.navigationBars["Levels"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["journeyLevel_1"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func solveFirstMaze(_ app: XCUIApplication, startingMoves: Int = 0) -> Int {
        var moves = startingMoves
        for _ in 0..<80 {
            app.buttons["reward_hint"].tap()
            swipe(app, app.staticTexts["playInstructions"].label)
            moves += 1
            let title = app.staticTexts["levelTitle"]
            if app.mazeIsFullyPainted || app.otherElements["perfectSolveAward"].exists || title.label == "Level 002" {
                let nextLevel = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    title.exists && title.label == "Level 002"
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [nextLevel], timeout: 8), .completed)
                return moves
            }
        }
        XCTFail("The first maze did not finish in 80 hinted moves")
        return moves
    }

    @MainActor
    private func swipe(_ app: XCUIApplication, _ instruction: String) {
        let board = app.otherElements["mazeBoard"]
        switch instruction {
        case "Swipe up": board.swipeUp(velocity: .fast)
        case "Swipe down": board.swipeDown(velocity: .fast)
        case "Swipe left": board.swipeLeft(velocity: .fast)
        case "Swipe right": board.swipeRight(velocity: .fast)
        default: XCTFail("Missing hint: \(instruction)")
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
