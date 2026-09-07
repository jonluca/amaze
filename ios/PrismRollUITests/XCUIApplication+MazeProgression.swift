import XCTest

extension XCUIApplication {
    @MainActor
    var mazeIsFullyPainted: Bool {
        let board = otherElements["mazeBoard"]
        guard board.exists, let value = board.value as? String else { return false }
        let counts = value.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        return counts.count == 4 && counts[2] == counts[3]
    }

    /// A solved board can briefly hide its controls while the award is visible.
    @MainActor
    @discardableResult
    func waitForMazeAdvanceAfterCompletion(from title: String) -> Bool {
        guard otherElements["perfectSolveAward"].exists || mazeIsFullyPainted else { return false }
        let nextLevel = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let heading = self.staticTexts["levelTitle"]
            return heading.exists && heading.label != title
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [nextLevel], timeout: 8), .completed)
        return true
    }
}
