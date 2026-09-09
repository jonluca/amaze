import XCTest
@testable import PrismRoll

final class MazeOptimalityTests: XCTestCase {
    func testMinimumCountIgnoresUnprovenStoredRoutes() {
        XCTAssertEqual(MazeOptimality.minimumMoves(for: squareLevel()), 3)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: squareLevel(solution: [])), 3)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: squareLevel(solution: [.right])), 3)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: squareLevel(
            solution: [.right, .left, .right, .down, .left]
        )), 3)
    }

    func testClassicLevelSixteenHasVerifiedMinimumBelowItsGeneratedRoute() {
        let level = MazeLevel.generate(number: 16, mode: .endless)
        XCTAssertEqual(level.solution.count, 46)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: level), 38)
    }

    func testLargerMazesMatchIndependentlyProvedFlowOptima() {
        // These minima were proved by a separate integer-flow model; its Euler
        // routes were replayed against the raw grids, independently of A*.
        for (number, expected) in [(17, 39), (25, 42), (50, 58)] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            XCTAssertEqual(MazeOptimality.minimumMoves(for: level), expected,
                           "Classic level \(number)")
        }
    }

    func testMinimumCountRespectsCancellation() {
        XCTAssertNil(MazeOptimality.minimumMoves(for: squareLevel(), isCancelled: { true }))
    }

    func testMinimumCountHandlesAlreadyCompleteAndSingleMoveBoards() {
        let start = GridCell(row: 0, column: 0)
        let singleCell = MazeLevel(number: 1, mode: .endless, width: 1, height: 1,
                                   openCells: [start], start: start, solution: [], moveLimit: nil)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: singleCell), 0)
        let corridor = MazeLevel(number: 1, mode: .endless, width: 16, height: 1,
                                 openCells: Set((0..<16).map { GridCell(row: 0, column: $0) }),
                                 start: start, solution: [], moveLimit: nil)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: corridor), 1)
    }

    func testMinimumCountRejectsUnsupportedOrUnreachableBoards() {
        let start = GridCell(row: 0, column: 0)
        let invalidLevels = [
            MazeLevel(number: 1, mode: .endless, width: 0, height: 1,
                      openCells: [start], start: start, solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 17, height: 1,
                      openCells: [start], start: start, solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 1, height: 1,
                      openCells: [], start: start, solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 2, height: 1,
                      openCells: [GridCell(row: 0, column: 1)], start: start,
                      solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 2, height: 1,
                      openCells: [start, GridCell(row: -1, column: 1)], start: start,
                      solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 2, height: 1,
                      openCells: [start, GridCell(row: 0, column: 2)], start: start,
                      solution: [], moveLimit: nil),
            MazeLevel(number: 1, mode: .endless, width: 3, height: 1,
                      openCells: [start, GridCell(row: 0, column: 2)], start: start,
                      solution: [], moveLimit: nil)
        ]
        for level in invalidLevels { XCTAssertNil(MazeOptimality.minimumMoves(for: level)) }
    }

    func testOptimalRouteEarnsAwardEvenWhenStoredSolutionIsLonger() {
        var run = MazeRun(level: squareLevel(solution: [.right, .left, .right, .down, .left]))
        for direction in [MoveDirection.right, .down, .left] { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        XCTAssertEqual(run.moves, 3)
        XCTAssertEqual(MazeOptimality.verify(run), .optimal)
    }

    func testFollowingStoredSolutionDoesNotProveOptimality() {
        let level = squareLevel(solution: [.right, .left, .right, .down, .left])
        var run = MazeRun(level: level)
        for direction in level.solution { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        XCTAssertEqual(run.moves, level.solution.count)
        XCTAssertEqual(MazeOptimality.verify(run), .notOptimal)
    }

    func testAlternativeOptimalRouteAndBlockedSwipeStillEarnAward() {
        var run = MazeRun(level: squareLevel())
        XCTAssertTrue(run.move(.up).isEmpty)
        for direction in [MoveDirection.down, .right, .up] { run.move(direction) }
        XCTAssertEqual(run.moves, 3)
        XCTAssertEqual(MazeOptimality.verify(run), .optimal)
    }

    func testIncompleteRunCannotEarnAward() {
        XCTAssertEqual(MazeOptimality.verify(MazeRun(level: squareLevel())), .incomplete)
    }

    func testCancellationDoesNotClaimOptimality() {
        var run = MazeRun(level: squareLevel())
        for direction in run.level.solution { run.move(direction) }
        XCTAssertEqual(MazeOptimality.verify(run, isCancelled: { true }), .undetermined)
    }

    func testLargeBoardPaintMaskCrossesAllFourWords() {
        // Eight horizontal corridors connected alternately at their ends form a
        // forced serpentine route. Row 14 exercises the fourth 64-bit word.
        var cells: Set<GridCell> = []
        for row in stride(from: 0, through: 14, by: 2) {
            for column in 0..<16 { cells.insert(GridCell(row: row, column: column)) }
            if row < 14 {
                cells.insert(GridCell(row: row + 1, column: (row / 2).isMultiple(of: 2) ? 15 : 0))
            }
        }
        let start = GridCell(row: 0, column: 0)
        let solution = MazeSolver.coveringRoute(openCells: cells, position: start, painted: [start])!
        let level = MazeLevel(number: 1, mode: .endless, width: 16, height: 16,
                              openCells: cells, start: start, solution: solution, moveLimit: nil)
        var run = MazeRun(level: level)
        for direction in solution { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        XCTAssertGreaterThan(cells.count, 128)
        XCTAssertEqual(MazeOptimality.verify(run), .optimal)
        XCTAssertEqual(MazeOptimality.minimumMoves(for: level), run.moves)
    }

    func testIndependentExhaustiveSmallBoardsAgree() {
        // The oracle stores literal painted sets and advances the actual run,
        // independently checking the compact graph search and pruning rules.
        let allCells = (0..<3).flatMap { row in (0..<3).map { GridCell(row: row, column: $0) } }
        for boardMask in 1..<(1 << allCells.count) {
            let cells = Set(allCells.enumerated().compactMap { index, cell in
                boardMask & (1 << index) == 0 ? nil : cell
            })
            for start in cells.sorted() {
                let level = MazeLevel(number: 1, mode: .endless, width: 3, height: 3,
                                      openCells: cells, start: start, solution: [], moveLimit: nil)
                let shortest = shortestCompletedRun(level)
                XCTAssertEqual(MazeOptimality.minimumMoves(for: level), shortest?.moves, "Minimum on board \(boardMask)")
                guard let shortest else { continue }
                XCTAssertEqual(MazeOptimality.verify(shortest), .optimal, "Board \(boardMask)")
                // A return trip before solving must fail, even with no stored route.
                guard let direction = MoveDirection.allCases.first(where: {
                    !MazeSolver.path(from: start, direction: $0, in: cells).isEmpty
                }) else { continue }
                var detour = MazeRun(level: level)
                detour.move(direction)
                let reverse: MoveDirection = switch direction {
                case .up: .down
                case .down: .up
                case .left: .right
                case .right: .left
                }
                detour.move(reverse)
                guard !detour.isComplete,
                      let route = MazeSolver.coveringRoute(openCells: cells, position: detour.position, painted: detour.painted)
                else { continue }
                for move in route { detour.move(move) }
                XCTAssertTrue(detour.isComplete)
                let expected: MazeOptimality.Result = detour.moves == shortest.moves ? .optimal : .notOptimal
                XCTAssertEqual(MazeOptimality.verify(detour), expected, "Detour on board \(boardMask)")
            }
        }
    }

    private func squareLevel(solution: [MoveDirection] = [.right, .down, .left]) -> MazeLevel {
        MazeLevel(number: 1, mode: .endless, width: 2, height: 2,
                  openCells: Set((0..<2).flatMap { row in (0..<2).map { GridCell(row: row, column: $0) } }),
                  start: GridCell(row: 0, column: 0), solution: solution, moveLimit: nil)
    }

    private func shortestCompletedRun(_ level: MazeLevel) -> MazeRun? {
        var queue = [MazeRun(level: level)]
        var visited: [GridCell: Set<Set<GridCell>>] = [level.start: [[level.start]]]
        var index = 0
        while index < queue.count {
            let run = queue[index]
            if run.isComplete { return run }
            index += 1
            for direction in MoveDirection.allCases {
                var next = run
                guard !next.move(direction).isEmpty,
                      visited[next.position, default: []].insert(next.painted).inserted else { continue }
                queue.append(next)
            }
        }
        return nil
    }
}
