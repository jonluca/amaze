import XCTest
@testable import PrismRoll

final class MazeMoveTargetTests: XCTestCase {
    func testKnownTargetCountsEffectiveMovesAndStopsWhenPaintIsComplete() {
        let level = square(solution: [.up, .right, .down, .left, .up, .right])
        XCTAssertEqual(MazeMoveTarget.knownSolution(for: level, completedBest: nil), .bestKnown(3))
    }

    func testIncompleteStoredRouteCannotSupplyATarget() {
        XCTAssertNil(MazeMoveTarget.knownSolution(for: square(solution: [.right]), completedBest: nil))
    }

    func testSavedBetterCompletionImprovesTargetWithoutClaimingPerfection() {
        let level = square(solution: [.right, .left, .right, .down, .left])
        XCTAssertEqual(MazeMoveTarget.knownSolution(for: level, completedBest: 3), .bestKnown(3))
        XCTAssertEqual(MazeMoveTarget.knownSolution(for: level, completedBest: 7), .bestKnown(5))
    }

    private func square(solution: [MoveDirection]) -> MazeLevel {
        MazeLevel(number: 1, mode: .endless, width: 2, height: 2,
                  openCells: Set((0..<2).flatMap { row in (0..<2).map { GridCell(row: row, column: $0) } }),
                  start: GridCell(row: 0, column: 0), solution: solution, moveLimit: nil)
    }
}
