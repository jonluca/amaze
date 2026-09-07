import XCTest

final class SwipeReliabilityUITests: XCTestCase {
    @MainActor
    func testShortDiagonalFlicksOutsideBoardRegisterAndPreserveNativeControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()

        let board = app.otherElements["mazeBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        let title = app.staticTexts["levelTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "Level 001")
        XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
        app.buttons["reward_hint"].tap()

        let hint = app.staticTexts["playInstructions"].label
        let vector: CGVector
        switch hint {
        case "Swipe up": vector = CGVector(dx: 11, dy: -12)
        case "Swipe down": vector = CGVector(dx: 11, dy: 12)
        case "Swipe left": vector = CGVector(dx: -12, dy: 11)
        case "Swipe right": vector = CGVector(dx: 12, dy: 11)
        default: XCTFail("Missing initial direction: \(hint)"); return
        }
        let origin = title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        XCTAssertFalse(board.frame.contains(origin.screenPoint), "Exercise the full-screen input surface")

        // A 12:11 diagonal has a clear dominant axis but fell inside the old
        // 1.15 axis-ratio dead zone. XCTest waits between gestures, so this tests
        // recognition of short, fast strokes rather than hardware input throughput.
        for index in 0..<20 {
            let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let destination = origin.withOffset(CGVector(dx: vector.dx * sign, dy: vector.dy * sign))
            origin.press(forDuration: 0, thenDragTo: destination,
                         withVelocity: XCUIGestureVelocity(rawValue: 2_500), thenHoldForDuration: 0)
        }
        XCTAssertEqual(app.staticTexts["moveCount"].label, "20 moves", "Each diagonal flick must register exactly once")
        XCTAssertEqual(title.label, "Level 001")

        let boardState = board.value as? String
        app.buttons["pauseGame"].tap()
        let resume = app.buttons["resumeGame"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3))
        resume.tap()
        XCTAssertTrue(app.buttons["pauseGame"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["moveCount"].label, "20 moves", "Native control taps must not add a move")
        XCTAssertEqual(board.value as? String, boardState, "Pause and resume must preserve the run")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "twenty-short-diagonal-flicks"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
