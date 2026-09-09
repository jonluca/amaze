import Foundation
import XCTest
@testable import PrismRoll

final class MazeRunOptimalHintTests: XCTestCase {
    func testProvedRouteRetainsOptimalityWhileFollowingItsSuffix() {
        var run = MazeRun(level: square())
        XCTAssertFalse(run.hintIsOptimal)
        XCTAssertTrue(run.installOptimalRoute([.right, .down, .left]))
        XCTAssertTrue(run.hintIsOptimal)
        XCTAssertEqual(run.hintDirection, .right)

        run.move(.right)
        XCTAssertTrue(run.hintIsOptimal)
        XCTAssertEqual(run.hintDirection, .down)
        run.move(.down)
        XCTAssertTrue(run.hintIsOptimal)
        XCTAssertEqual(run.hintDirection, .left)
        run.move(.left)
        XCTAssertTrue(run.isComplete)
        XCTAssertNil(run.hintDirection)
    }

    func testBlockedSwipePreservesProofButADeviationInvalidatesIt() {
        var run = MazeRun(level: square())
        XCTAssertTrue(run.installOptimalRoute([.right, .down, .left]))
        XCTAssertTrue(run.move(.up).isEmpty)
        XCTAssertTrue(run.hintIsOptimal)
        XCTAssertEqual(run.hintDirection, .right)

        run.move(.right)
        run.move(.left)
        XCTAssertFalse(run.hintIsOptimal)
        XCTAssertEqual(run.position, run.level.start)
        // The top row is already painted after the detour, so this completion
        // is optimal for the current state even though the start is unchanged.
        XCTAssertTrue(run.installOptimalRoute([.down, .right]))
        XCTAssertTrue(run.hintIsOptimal)
        XCTAssertEqual(run.hintDirection, .down)
    }

    func testRejectsIncompleteBlockedOrOverlongRoutesWithoutChangingExistingProof() {
        var run = MazeRun(level: square())
        XCTAssertTrue(run.installOptimalRoute([.right, .down, .left]))
        let original = run
        for invalid in [[], [.right], [.up, .right, .down, .left], [.right, .down, .left, .up]] as [[MoveDirection]] {
            XCTAssertFalse(run.installOptimalRoute(invalid))
            XCTAssertEqual(run, original)
        }
    }

    func testResetAndRestorationRequireFreshOptimalityProof() throws {
        var run = MazeRun(level: square())
        XCTAssertTrue(run.installOptimalRoute([.right, .down, .left]))
        run.move(.right)
        let data = try JSONEncoder().encode(run)
        let restored = try JSONDecoder().decode(MazeRun.self, from: data)
        XCTAssertEqual(restored.position, run.position)
        XCTAssertEqual(restored.painted, run.painted)
        XCTAssertEqual(restored.moves, run.moves)
        XCTAssertFalse(restored.hintIsOptimal, "Stored directions are not a persisted native proof")

        run.reset()
        XCTAssertEqual(run.position, run.level.start)
        XCTAssertEqual(run.painted, [run.level.start])
        XCTAssertFalse(run.hintIsOptimal)
    }

    private func square() -> MazeLevel {
        let cells = Set((0..<2).flatMap { row in
            (0..<2).map { GridCell(row: row, column: $0) }
        })
        return MazeLevel(number: 1, mode: .endless, width: 2, height: 2,
                         openCells: cells, start: GridCell(row: 0, column: 0),
                         solution: [.right, .down, .left], moveLimit: nil)
    }
}
