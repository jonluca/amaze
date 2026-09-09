import XCTest

final class PerfectMoveCountUITests: XCTestCase {
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
}
