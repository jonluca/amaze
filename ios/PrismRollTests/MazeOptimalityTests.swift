import XCTest
@testable import PrismRoll

final class MazeOptimalityTests: XCTestCase {
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

    func testExhaustedBudgetAndCancellationDoNotClaimOptimality() {
        var run = MazeRun(level: squareLevel(solution: [.right, .left, .right, .down, .left]))
        for direction in run.level.solution { run.move(direction) }
        XCTAssertEqual(MazeOptimality.verify(run, stateLimit: 1), .undetermined)
        XCTAssertEqual(MazeOptimality.verify(run, stateLimit: 0), .undetermined)
        XCTAssertEqual(MazeOptimality.verify(run, timeLimit: .zero), .undetermined)
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
    }

    func testIndependentExhaustiveSmallBoardsAgree() {
        // The oracle stores literal painted sets and advances the actual run,
        // independently checking the compact graph search and pruning rules.
        let allCells = (0..<3).flatMap { row in (0..<3).map { GridCell(row: row, column: $0) } }
        for boardMask in 1..<(1 << allCells.count) {
            let cells = Set(allCells.enumerated().compactMap { index, cell in
                boardMask & (1 << index) == 0 ? nil : cell
            })
            let start = cells.min()!
            let level = MazeLevel(number: 1, mode: .endless, width: 3, height: 3,
                                  openCells: cells, start: start, solution: [], moveLimit: nil)
            guard let shortest = shortestCompletedRun(level) else { continue }
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
