import XCTest
@testable import PrismRoll

final class ExactBoardProgressTests: XCTestCase {
    func testProofRequiresExactGeometryAndStartAfterRoundTrip() throws {
        let level = squareLevel()
        let run = completed(level)
        var progress = ProgressData()
        progress.completeLevel(level)
        progress.recordCompletedRun(run, optimality: .optimal)
        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        let changedStart = MazeLevel(number: level.number, mode: level.mode, width: 2, height: 2,
                                     openCells: level.openCells, start: GridCell(row: 0, column: 1),
                                     solution: [], moveLimit: nil)
        let changedGrid = MazeLevel(number: level.number, mode: level.mode, width: 2, height: 2,
                                    openCells: level.openCells.subtracting([GridCell(row: 1, column: 1)]),
                                    start: level.start, solution: [], moveLimit: nil)

        XCTAssertEqual(restored.optimalMoves(for: level), 3)
        XCTAssertNil(restored.optimalMoves(for: changedStart))
        XCTAssertNil(restored.optimalMoves(for: changedGrid))
    }

    func testDifferentBoardResetsTheSingleLevelRecordAndCrown() throws {
        let first = squareLevel()
        let next = MazeLevel(number: first.number, mode: first.mode, width: 3, height: 1,
                             openCells: Set((0..<3).map { GridCell(row: 0, column: $0) }),
                             start: first.start, solution: [.right], moveLimit: nil)
        var progress = ProgressData()
        progress.completeLevel(first)
        progress.recordCompletedRun(completed(first), optimality: .optimal)

        progress.recordCompletedRun(completed(next))

        XCTAssertEqual(progress.bestMoves(number: 7, mode: .endless), 1)
        XCTAssertFalse(progress.hasOptimalCompletion(number: 7, mode: .endless))
        XCTAssertNil(progress.optimalMoves(for: first))
        XCTAssertNil(progress.optimalMoves(for: next))
        progress.recordCompletedRun(completed(next), optimality: .optimal)
        XCTAssertEqual(progress.optimalMoves(for: next), 1)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any])
        let records = try XCTUnwrap(object["levelRecords"] as? [String: Any])
        XCTAssertEqual(Set(records.keys), ["endless:7"])
    }

    func testProvenMinimumReplacesAndRejectsUnverifiedImpossibleMoveCounts() throws {
        let level = squareLevel()
        let proven = completed(level)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(proven)) as? [String: Any])
        object["moves"] = 1
        let malformed = try JSONDecoder().decode(MazeRun.self, from: JSONSerialization.data(withJSONObject: object))
        var progress = ProgressData()
        progress.completeLevel(level)
        progress.recordCompletedRun(malformed)
        XCTAssertNil(progress.optimalMoves(for: level))
        progress.recordCompletedRun(proven, optimality: .optimal)
        XCTAssertEqual(progress.optimalMoves(for: level), 3)
        progress.recordCompletedRun(malformed, optimality: .notOptimal)
        progress.recordCompletedRun(malformed)
        XCTAssertEqual(progress.optimalMoves(for: level), 3)
        XCTAssertEqual(progress.bestMoves(number: 7, mode: .endless), 3)
    }

    private func squareLevel() -> MazeLevel {
        MazeLevel(number: 7, mode: .endless, width: 2, height: 2,
                  openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1),
                              GridCell(row: 1, column: 0), GridCell(row: 1, column: 1)],
                  start: GridCell(row: 0, column: 0), solution: [.right, .down, .left], moveLimit: nil)
    }

    private func completed(_ level: MazeLevel) -> MazeRun {
        var run = MazeRun(level: level)
        for direction in level.solution { run.move(direction, recomputeFallbackHint: false) }
        XCTAssertTrue(run.isComplete)
        return run
    }
}
