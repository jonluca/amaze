import XCTest

final class MilestoneProgressionUITests: XCTestCase {
    @MainActor
    func testClaimAdvancesFromFiveToTwentyFiveInlineAndSurvivesRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        for level in 1...5 { solveLevel(level, in: app) }
        let startingCoins = balance(in: app)

        openMilestones(in: app)
        XCTAssertEqual(app.staticTexts["milestoneTarget-levels"].label, "Finish 5 levels in any mode")
        let claim = app.buttons["claimMilestone-first-five"]
        for _ in 0..<5 where !claim.isHittable { app.swipeUp() }
        XCTAssertTrue(claim.isEnabled)
        capture(app, "milestone-five-ready-to-claim")
        claim.tap()

        let nextGoal = app.staticTexts["milestoneTarget-levels"]
        let advanced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            nextGoal.exists && nextGoal.label == "Finish 25 levels in any mode"
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 5), .completed)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Claiming should update the row without a confirmation popup")
        XCTAssertFalse(app.buttons["claimMilestone-first-five"].exists)
        XCTAssertFalse(app.buttons["claimMilestone-twenty-five"].isEnabled)
        XCTAssertEqual(balance(in: app), startingCoins + 75)
        capture(app, "milestone-advances-inline-to-twenty-five")

        app.terminate()
        app.launchArguments = ["--no-ads", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.otherElements["mazeBoard"].waitForExistence(timeout: 15))
        XCTAssertEqual(balance(in: app), startingCoins + 75)
        openMilestones(in: app)
        XCTAssertEqual(app.staticTexts["milestoneTarget-levels"].label, "Finish 25 levels in any mode")
        XCTAssertFalse(app.buttons["claimMilestone-first-five"].exists)
        XCTAssertFalse(app.buttons["claimMilestone-twenty-five"].isEnabled)
        capture(app, "milestone-next-tier-persists-after-relaunch")
    }

    @MainActor
    private func solveLevel(_ level: Int, in app: XCUIApplication) {
        let title = "Level \(level)"
        XCTAssertEqual(app.staticTexts["levelTitle"].label, title)
        for _ in 0..<80 {
            if app.waitForMazeAdvanceAfterCompletion(from: title) { break }
            if app.staticTexts["levelTitle"].label != title { break }
            app.buttons["reward_hint"].tap()
            if app.waitForMazeAdvanceAfterCompletion(from: title) { break }
            if app.staticTexts["levelTitle"].label != title { break }
            let instruction = app.staticTexts["playInstructions"].label
            let board = app.otherElements["mazeBoard"]
            switch instruction {
            case "Swipe up": board.swipeUp(velocity: .fast)
            case "Swipe down": board.swipeDown(velocity: .fast)
            case "Swipe left": board.swipeLeft(velocity: .fast)
            case "Swipe right": board.swipeRight(velocity: .fast)
            default: XCTFail("Missing hint: \(instruction)"); return
            }
        }
        XCTAssertEqual(app.staticTexts["levelTitle"].label, "Level \(level + 1)")
    }

    @MainActor
    private func openMilestones(in app: XCUIApplication) {
        app.tabBars.buttons["Challenges"].tap()
        let goal = app.staticTexts["milestoneTarget-levels"]
        for _ in 0..<6 where !goal.isHittable { app.swipeUp() }
        XCTAssertTrue(goal.isHittable)
    }

    @MainActor
    private func balance(in app: XCUIApplication) -> Int {
        let label = app.buttons["pointsBalance"].label
        guard let value = Int(label.filter(\.isNumber)) else {
            XCTFail("Missing wallet amount: \(label)")
            return -1
        }
        return value
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
