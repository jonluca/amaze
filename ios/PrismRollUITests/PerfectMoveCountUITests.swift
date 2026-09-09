import XCTest

final class PerfectMoveCountUITests: XCTestCase {
    @MainActor
    func testReplacementLevelsHaveBundledCountsAndPlayableOptimalHints() {
        for (number, minimum) in [(8, 26), (72, 62)] {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--no-ads", "--ui-test-level", String(number),
                                   "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            let board = app.otherElements["mazeBoard"]
            XCTAssertTrue(board.waitForExistence(timeout: 15))
            XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level \(number)")
            let target = app.descendants(matching: .any).matching(identifier: "perfectMoveCount").firstMatch
            XCTAssertTrue(target.exists)
            XCTAssertEqual(target.label, "Perfect: \(minimum) moves")
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "perfectMoveCountLoading").firstMatch.exists)
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "retryPerfectMoveCount").firstMatch.exists)
            let opening = optimalHint(in: app)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "replacement-perfect-count-level-\(number)"
            attachment.lifetime = .keepAlways
            add(attachment)

            swipe(opening, on: board)

            XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
            XCTAssertEqual(target.label, "Perfect: \(minimum) moves")
            app.terminate()
        }
    }

    @MainActor
    func testBundledPerfectCountsAppearOnTheFirstAndThousandthLevel() {
        for number in [1, 1_000] {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--no-ads", "--ui-test-level", String(number),
                                   "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            app.launch()
            XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
            XCTAssertEqual(app.staticTexts["levelTitle"].label,
                           "Level \(number.formatted(.number.locale(Locale(identifier: "en_US"))))")
            let target = app.descendants(matching: .any).matching(identifier: "perfectMoveCount").firstMatch

            // Board readiness is the only wait. A bundled count must be part
            // of its first presentation, without a separate solver wait.
            XCTAssertTrue(target.exists)
            XCTAssertEqual(target.label, number == 1 ? "Perfect: 8 moves" : "Perfect: 88 moves")
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "perfectMoveCountLoading").firstMatch.exists)
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "retryPerfectMoveCount").firstMatch.exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "bundled-perfect-count-level-\(number)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    @MainActor
    func testOptimalHintIsReadyAfterBacktracking() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--no-ads"]
        app.launch()
        let board = app.otherElements["mazeBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        let target = app.descendants(matching: .any).matching(identifier: "perfectMoveCount").firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let targetLabel = target.label
        let opening = optimalHint(in: app)
        swipe(opening, on: board)
        let reverse: String
        switch opening {
        case "Swipe up": reverse = "Swipe down"
        case "Swipe down": reverse = "Swipe up"
        case "Swipe left": reverse = "Swipe right"
        case "Swipe right": reverse = "Swipe left"
        default: XCTFail("Missing opening optimal hint: \(opening)"); return
        }
        swipe(reverse, on: board)
        swipe(opening, on: board)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "3 moves")
        XCTAssertEqual(target.label, targetLabel, "The level target stays fixed after a detour")
        let next = optimalHint(in: app)
        XCTAssertTrue(["Swipe up", "Swipe down", "Swipe left", "Swipe right"].contains(next))

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "optimal-hint-after-backtracking"
        attachment.lifetime = .keepAlways
        add(attachment)
        swipe(next, on: board)
        XCTAssertEqual(app.staticTexts["moveCount"].label, "4 moves", "The new hint must be legal from the live position")
    }

    @MainActor
    func testClassicTargetStaysFixedDuringPlayAndIsScopedToClassic() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--no-ads"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        let target = app.descendants(matching: .any).matching(identifier: "perfectMoveCount").firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Perfect: 8 moves")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "classic-perfect-move-target"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.buttons["reward_hint"].tap()
        let board = app.otherElements["mazeBoard"]
        switch app.staticTexts["playInstructions"].label {
        case "Swipe up": board.swipeUp(velocity: .fast)
        case "Swipe down": board.swipeDown(velocity: .fast)
        case "Swipe left": board.swipeLeft(velocity: .fast)
        case "Swipe right": board.swipeRight(velocity: .fast)
        default: XCTFail("Missing opening hint"); return
        }
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")
        XCTAssertEqual(target.label, "Perfect: 8 moves", "The target is for the whole level, not remaining moves")

        let modes = app.segmentedControls["modePicker"]
        modes.buttons["Time Rush"].tap()
        XCTAssertFalse(target.exists)
        modes.buttons["Limited Moves"].tap()
        XCTAssertFalse(target.exists)
        modes.buttons["Classic"].tap()
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Perfect: 8 moves")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "1 move")

        app.buttons["Restart level"].tap()
        app.alerts.buttons.matching(identifier: "confirmRestart").firstMatch.tap()
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, "Perfect: 8 moves")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
    }

    @MainActor
    private func optimalHint(in app: XCUIApplication) -> String {
        let button = app.buttons["reward_hint"]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        button.tap()
        let instructions = app.staticTexts["playInstructions"]
        let shown = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label IN %@", ["Swipe up", "Swipe down", "Swipe left", "Swipe right"]),
            object: instructions
        )
        XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 5), .completed)
        return instructions.label
    }

    @MainActor
    private func swipe(_ instruction: String, on board: XCUIElement) {
        switch instruction {
        case "Swipe up": board.swipeUp(velocity: .fast)
        case "Swipe down": board.swipeDown(velocity: .fast)
        case "Swipe left": board.swipeLeft(velocity: .fast)
        case "Swipe right": board.swipeRight(velocity: .fast)
        default: XCTFail("Unexpected hint: \(instruction)")
        }
    }
}
