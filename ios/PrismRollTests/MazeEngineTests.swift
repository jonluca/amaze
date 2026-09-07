import XCTest
@testable import PrismRoll

final class MazeEngineTests: XCTestCase {
    func testHundredsOfLevelsHaveDeterministicExecutableSolutions() {
        for number in 1...350 {
            for mode in GameMode.allCases {
                let level = MazeLevel.generate(number: number, mode: mode)
                XCTAssertEqual(level, MazeLevel.generate(number: number, mode: mode), "\(mode) \(number)")
                XCTAssertTrue(level.openCells.contains(level.start))
                XCTAssertTrue(level.openCells.allSatisfy {
                    $0.row >= 0 && $0.row < level.height && $0.column >= 0 && $0.column < level.width
                })
                XCTAssertLessThan(level.openCells.count, level.width * level.height)
                var run = MazeRun(level: level)
                for direction in level.solution {
                    let previous = run.position
                    let path = run.move(direction)
                    XCTAssertFalse(path.isEmpty, "Solution must contain only effective moves: \(number)")
                    XCTAssertFalse(path.contains(previous))
                    XCTAssertFalse(level.openCells.contains(run.position.neighbor(in: direction)))
                }
                XCTAssertTrue(run.isComplete, "Unsolved \(mode) \(number)")
                XCTAssertEqual(run.painted, level.openCells)
                XCTAssertFalse(run.isFailed)
                if mode == .challenge {
                    XCTAssertLessThanOrEqual(run.moves, level.moveLimit!)
                } else {
                    XCTAssertNil(level.moveLimit)
                }
            }
        }
    }

    func testAllReachableStopsCanRecoverAndAllTilesCanBePainted() {
        for number in 1...200 {
            let level = MazeLevel.generate(number: number * 97, mode: .endless)
            var queue = [level.start]
            var seen: Set<GridCell> = [level.start]
            var painted: Set<GridCell> = [level.start]
            var edges: [GridCell: Set<GridCell>] = [:]
            var index = 0
            while index < queue.count {
                let position = queue[index]
                index += 1
                for direction in MoveDirection.allCases {
                    // Independently exercise the actual slide-until-wall rules.
                    var end = position
                    while level.openCells.contains(end.neighbor(in: direction)) {
                        end = end.neighbor(in: direction)
                        painted.insert(end)
                    }
                    edges[position, default: []].insert(end)
                    if seen.insert(end).inserted { queue.append(end) }
                }
            }
            XCTAssertEqual(painted, level.openCells, "Every tile must be reachable by sliding")
            for stop in seen {
                var recoverable: Set<GridCell> = [stop]
                var pending = [stop]
                while let cursor = pending.popLast() {
                    for neighbor in edges[cursor, default: []] where recoverable.insert(neighbor).inserted {
                        pending.append(neighbor)
                    }
                }
                XCTAssertTrue(recoverable.contains(level.start), "Unrecoverable stop \(stop), level \(number)")
            }
        }
    }

    func testGeneratedBoardsHaveVarietyAndInteriorStructure() {
        let boards = (30...80).map { MazeLevel.generate(number: $0, mode: .endless) }
        let signatures = Set(boards.map { level in
            level.openCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        })
        XCTAssertGreaterThan(signatures.count, 45)
        XCTAssertGreaterThan(boards.filter { $0.solution.count > 8 }.count, 35)
        XCTAssertGreaterThan(boards.filter { level in
            level.openCells.contains { $0.row > 0 && $0.column > 0 && $0.row < level.height - 1 && $0.column < level.width - 1 }
        }.count, 45)
    }

    func testBlockedMoveDoesNotConsumeMoveOrChangeState() throws {
        let level = MazeLevel.generate(number: 1, mode: .challenge)
        var run = MazeRun(level: level)
        let original = run
        // Rotated layouts can begin at any edge; use an actual adjacent wall.
        let blocked = try XCTUnwrap(MoveDirection.allCases.first {
            !level.openCells.contains(level.start.neighbor(in: $0))
        })
        XCTAssertTrue(run.move(blocked).isEmpty)
        XCTAssertEqual(run, original)
    }

    func testHintRouteFinishesAfterRandomPlayerDeviations() {
        for number in 1...100 {
            var run = MazeRun(level: MazeLevel.generate(number: number, mode: .endless))
            var random = SeededGenerator(seed: UInt64(number))
            for _ in 0..<20 { run.move(MoveDirection.allCases[random.integer(lessThan: 4)]) }
            for _ in 0..<400 {
                guard let hint = run.hintDirection else { break }
                XCTAssertTrue(run.hintIsGuaranteed)
                XCTAssertFalse(run.move(hint).isEmpty)
            }
            XCTAssertTrue(run.isComplete, "Hints failed for \(number)")
        }
    }

    func testChallengeHintsRemainWithinBudgetWhenFollowed() {
        for number in 1...100 {
            var run = MazeRun(level: MazeLevel.generate(number: number, mode: .challenge))
            while let hint = run.hintDirection {
                XCTAssertTrue(run.hintIsGuaranteed)
                XCTAssertFalse(run.move(hint).isEmpty)
            }
            XCTAssertTrue(run.isComplete)
            XCTAssertFalse(run.isFailed)
        }
    }

    func testMoveBudgetFailureAndReset() {
        let cells: Set<GridCell> = [
            GridCell(row: 0, column: 0), GridCell(row: 0, column: 1),
            GridCell(row: 1, column: 0), GridCell(row: 1, column: 1)
        ]
        let level = MazeLevel(number: 1, mode: .challenge, width: 2, height: 2,
                              openCells: cells, start: GridCell(row: 0, column: 0),
                              solution: [.right, .down, .left], moveLimit: 3)
        var run = MazeRun(level: level)
        XCTAssertEqual(run.move(.right), [GridCell(row: 0, column: 1)])
        run.move(.left)
        XCTAssertFalse(run.hintIsGuaranteed)
        run.move(.right)
        XCTAssertTrue(run.isFailed)
        XCTAssertFalse(run.isComplete)
        XCTAssertEqual(run.remainingMoves, 0)
        XCTAssertNil(run.hintDirection)
        XCTAssertTrue(run.move(.down).isEmpty)
        run.reset()
        XCTAssertEqual(run, MazeRun(level: level))
    }

    func testCompletingOnFinalAllowedMoveSucceeds() {
        let cells: Set<GridCell> = [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)]
        let level = MazeLevel(number: 1, mode: .challenge, width: 2, height: 1,
                              openCells: cells, start: GridCell(row: 0, column: 0),
                              solution: [.right], moveLimit: 1)
        var run = MazeRun(level: level)
        run.move(.right)
        XCTAssertTrue(run.isComplete)
        XCTAssertFalse(run.isFailed)
        XCTAssertNil(run.hintDirection)
        XCTAssertTrue(run.move(.left).isEmpty)
    }

    func testSavedRunResumesWithSameHintAndPaintState() throws {
        var run = MazeRun(level: MazeLevel.generate(number: 75, mode: .challenge))
        run.move(run.hintDirection!)
        let data = try JSONEncoder().encode(run)
        var restored = try JSONDecoder().decode(MazeRun.self, from: data)
        XCTAssertEqual(run, restored)
        while let hint = restored.hintDirection { restored.move(hint) }
        XCTAssertTrue(restored.isComplete)
    }

    func testExtremeLevelNumbersRemainValid() {
        for number in [Int.min, 0, 1, 100_000, Int.max] {
            let level = MazeLevel.generate(number: number, mode: .challenge)
            XCTAssertGreaterThanOrEqual(level.number, 1)
            var run = MazeRun(level: level)
            for direction in level.solution { run.move(direction) }
            XCTAssertTrue(run.isComplete)
        }
    }
}
