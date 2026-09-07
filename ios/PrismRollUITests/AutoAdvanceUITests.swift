import XCTest

final class AutoAdvanceUITests: XCTestCase {
    @MainActor
    func testThreeClassicLevelsAdvanceWithoutAContinueButton() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        for level in 1...3 {
            let title = String(format: "Level %03d", level)
            XCTAssertEqual(app.staticTexts["levelTitle"].label, title)
            for _ in 0..<80 {
                if app.staticTexts["levelTitle"].label != title { break }
                XCTAssertFalse(app.buttons["Keep rolling"].exists)
                app.buttons["reward_hint"].tap()
                let direction = app.staticTexts["playInstructions"].label
                let board = app.otherElements["mazeBoard"]
                switch direction {
                case "Swipe up": board.swipeUp(velocity: .fast)
                case "Swipe down": board.swipeDown(velocity: .fast)
                case "Swipe left": board.swipeLeft(velocity: .fast)
                case "Swipe right": board.swipeRight(velocity: .fast)
                default: XCTFail("Missing hint: \(direction)"); return
                }
            }
            XCTAssertEqual(app.staticTexts["levelTitle"].label, String(format: "Level %03d", level + 1))
            XCTAssertEqual(app.staticTexts["moveCount"].label, "0 moves")
            XCTAssertTrue(app.otherElements.matching(identifier: "pointsBalance").firstMatch.label.contains("\(level * 50)"))
        }
        XCTAssertFalse(app.buttons["nextLevel"].exists)
        app.tabBars.buttons["Journey"].tap()
        XCTAssertTrue(app.buttons["completionBonus_endless_1"].exists)
        XCTAssertTrue(app.buttons["completionBonus_endless_1"].label.contains("50 coins"))
        app.buttons["completionBonus_endless_1"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.tabBars.buttons["Play"].tap()
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level 004")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "three-levels-advanced-automatically"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testTenPointFlicksCanReverseRepeatedlyOutsideTheBoard() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        app.buttons["reward_hint"].tap()
        let hint = app.staticTexts["playInstructions"].label
        let origin = app.staticTexts["levelTitle"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let vector: CGVector
        switch hint {
        case "Swipe up": vector = CGVector(dx: 0, dy: -10)
        case "Swipe down": vector = CGVector(dx: 0, dy: 10)
        case "Swipe left": vector = CGVector(dx: -10, dy: 0)
        case "Swipe right": vector = CGVector(dx: 10, dy: 0)
        default: XCTFail("Missing hint"); return
        }
        for index in 0..<20 {
            let sign: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            origin.press(forDuration: 0.001,
                         thenDragTo: origin.withOffset(CGVector(dx: vector.dx * sign, dy: vector.dy * sign)),
                         withVelocity: XCUIGestureVelocity(rawValue: 2_500), thenHoldForDuration: 0)
        }
        XCTAssertEqual(app.staticTexts["moveCount"].label, "20 moves")
        XCTAssertFalse(app.buttons["nextLevel"].exists)
    }
}
