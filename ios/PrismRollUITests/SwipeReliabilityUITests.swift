import XCTest

final class SwipeReliabilityUITests: XCTestCase {
    @MainActor
    func testAngledFlicksKeepHorizontalAndVerticalBoardAxes() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let board = app.otherElements["mazeBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 15))
        var verified = Set<String>()

        for _ in 0..<32 {
            let title = app.staticTexts["levelTitle"].label
            app.buttons["reward_hint"].tap()
            let direction = app.staticTexts["playInstructions"].label
            let before = try position(of: board)
            let vector: CGVector
            switch direction {
            case "Swipe right": vector = CGVector(dx: 32, dy: 8)
            case "Swipe left": vector = CGVector(dx: -32, dy: -8)
            case "Swipe down": vector = CGVector(dx: -8, dy: 32)
            case "Swipe up": vector = CGVector(dx: 8, dy: -32)
            default: XCTFail("Missing direction: \(direction)"); return
            }
            let origin = app.staticTexts["levelTitle"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            origin.press(forDuration: 0, thenDragTo: origin.withOffset(vector),
                         withVelocity: XCUIGestureVelocity(rawValue: 2_500), thenHoldForDuration: 0)
            if app.staticTexts["levelTitle"].label != title { continue }
            let after = try position(of: board)
            switch direction {
            case "Swipe right":
                XCTAssertEqual(after.row, before.row)
                XCTAssertGreaterThan(after.column, before.column)
            case "Swipe left":
                XCTAssertEqual(after.row, before.row)
                XCTAssertLessThan(after.column, before.column)
            case "Swipe down":
                XCTAssertEqual(after.column, before.column)
                XCTAssertGreaterThan(after.row, before.row)
            default:
                XCTAssertEqual(after.column, before.column)
                XCTAssertLessThan(after.row, before.row)
            }
            verified.insert(direction)
            if verified.count == 4 { break }
        }
        XCTAssertEqual(verified, ["Swipe right", "Swipe left", "Swipe down", "Swipe up"])
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "angled-flicks-verified-on-both-board-axes"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func position(of board: XCUIElement) throws -> (row: Int, column: Int) {
        let value = try XCTUnwrap(board.value as? String)
        let numbers = value.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertGreaterThanOrEqual(numbers.count, 2, value)
        return (try XCTUnwrap(numbers.first), try XCTUnwrap(numbers.dropFirst().first))
    }

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
        app.buttons["Settings"].tap()
        let done = app.navigationBars["Settings"].buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["moveCount"].label, "20 moves", "Native control taps must not add a move")
        XCTAssertEqual(board.value as? String, boardState, "Opening and closing Settings must preserve the run")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "twenty-short-diagonal-flicks"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
