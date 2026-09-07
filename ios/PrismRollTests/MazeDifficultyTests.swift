import XCTest
@testable import PrismRoll

final class MazeDifficultyTests: XCTestCase {
    private struct SearchState: Hashable {
        let position: GridCell
        let painted: Set<GridCell>
    }

    func testTutorialAndEarlyClassicUseExactMeaningfulRoutes() throws {
        for number in 1...3 {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let minimum = try XCTUnwrap(exactMinimum(level))
            XCTAssertEqual(level.solution.count, minimum.moves, "Small Classic boards use actual shortest routes")
            XCTAssertGreaterThanOrEqual(minimum.moves, number == 1 ? 7 : 12)
            XCTAssertLessThanOrEqual(minimum.moves, number == 1 ? 8 : 22)
        }
    }

    func testFirstLimitedLevelUsesTightOptimalBudget() throws {
        let level = MazeLevel.generate(number: 1, mode: .challenge)
        let minimum = try XCTUnwrap(exactMinimum(level))
        XCTAssertEqual(level.solution.count, minimum.moves)
        XCTAssertEqual(level.moveLimit, minimum.moves + 3)
        XCTAssertGreaterThanOrEqual(minimum.moves, 12)
    }

    func testHundredsOfBoardsMeetCurveAndStructureAndRemainRecoverable() {
        let numbers = Array(1...40) + Array(80...139) + [500, 10_000, Int.max]
        for mode in [GameMode.endless, .challenge] {
            for number in numbers {
                let level = MazeLevel.generate(number: number, mode: mode)
                let difficulty = MazeDifficulty(number: number, mode: mode)
                let topology = MazeTopology(openCells: level.openCells, start: level.start)
                let layout = MazeLayout(cells: level.openCells, start: level.start, route: level.solution, topology: topology)
                XCTAssertTrue(difficulty.accepts(layout), "\(mode) \(number) violates the difficulty gate")
                XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: level.openCells, start: level.start))
                XCTAssertEqual(level, MazeLevel.generate(number: number, mode: mode))
                XCTAssertLessThanOrEqual(level.width, 16)
                var run = MazeRun(level: level)
                for (index, direction) in level.solution.enumerated() {
                    XCTAssertFalse(run.isComplete, "Stored routes must not pad the win with extra moves")
                    XCTAssertFalse(run.move(direction).isEmpty, "Stored routes must not pad with blocked moves")
                    if index == level.solution.count - 1 { XCTAssertTrue(run.isComplete) }
                }
                XCTAssertFalse(run.isFailed)
                if mode == .challenge {
                    XCTAssertEqual(level.moveLimit, level.solution.count + (number <= 5 ? 3 : number <= 20 ? 2 : 1))
                }
            }
        }
    }

    func testEveryFallbackOrientationHasRealDecisionsAndExecutableRoutes() {
        for mode in [GameMode.endless, .challenge] {
            for number in [1, 2, 4, 7, 10, 15, 22, 30, 42, 56, 75, 100, 200] {
                let difficulty = MazeDifficulty(number: number, mode: mode)
                for orientation in 0..<8 {
                    let layout = MazeFallbackLayouts.make(size: difficulty.size, orientation: orientation)
                    XCTAssertTrue(difficulty.accepts(layout), "Fallback \(difficulty.size), \(mode) \(number)")
                    XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: layout.cells, start: layout.start))
                    var painted: Set<GridCell> = [layout.start]
                    var position = layout.start
                    for direction in layout.route {
                        let path = MazeSolver.path(from: position, direction: direction, in: layout.cells)
                        XCTAssertFalse(path.isEmpty)
                        painted.formUnion(path)
                        position = path.last ?? position
                    }
                    XCTAssertEqual(painted, layout.cells)
                    XCTAssertGreaterThan(layout.route.count, 4)
                }
            }
        }
    }

    func testSegmentAndReturnBoundsAgainstIndependentSmallBoardSearch() throws {
        var ring: Set<GridCell> = []
        for row in 0..<5 {
            for column in 0..<5 where row == 0 || row == 4 || column == 0 || column == 4 {
                ring.insert(GridCell(row: row, column: column))
            }
        }
        let ringLevel = MazeLevel(number: 1, mode: .endless, width: 5, height: 5, openCells: ring,
            start: GridCell(row: 0, column: 0), solution: [.down, .right, .up, .left], moveLimit: nil)
        let ringTopology = MazeTopology(openCells: ring, start: ringLevel.start)
        XCTAssertEqual(ringTopology.minimumSegments, 4)
        XCTAssertEqual(ringTopology.decisionStops, 0)
        XCTAssertEqual(ringTopology.minimumRevisitedSteps, 0)
        XCTAssertEqual(try XCTUnwrap(exactMinimum(ringLevel)).moves, 4)

        let branch = MazeFallbackLayouts.make(size: 5, orientation: 0)
        let branchLevel = MazeLevel(number: 1, mode: .endless, width: 5, height: 5, openCells: branch.cells,
            start: branch.start, solution: branch.route, moveLimit: nil)
        XCTAssertGreaterThanOrEqual(branch.topology.decisionStops, 2)
        XCTAssertGreaterThan(branch.topology.minimumRevisitedSteps, 0)
        for level in [ringLevel, branchLevel, .generate(number: 1, mode: .endless), .generate(number: 2, mode: .endless), .generate(number: 1, mode: .challenge)] {
            let topology = MazeTopology(openCells: level.openCells, start: level.start)
            let exact = try XCTUnwrap(exactMinimum(level))
            XCTAssertLessThanOrEqual(topology.minimumSegments, exact.moves)
            XCTAssertLessThanOrEqual(topology.minimumRevisitedSteps, exact.revisits)
        }
    }

    private func exactMinimum(_ level: MazeLevel) -> (moves: Int, revisits: Int)? {
        let start = SearchState(position: level.start, painted: [level.start])
        var queue = [(state: start, moves: 0, revisits: 0)]
        var visited: Set<SearchState> = [start]
        var index = 0
        while index < queue.count && queue.count <= 100_000 {
            let current = queue[index]
            index += 1
            for direction in MoveDirection.allCases {
                let path = MazeSolver.path(from: current.state.position, direction: direction, in: level.openCells)
                guard let position = path.last else { continue }
                let painted = current.state.painted.union(path)
                let revisits = current.revisits + path.filter { current.state.painted.contains($0) }.count
                if painted == level.openCells { return (current.moves + 1, revisits) }
                let next = SearchState(position: position, painted: painted)
                if visited.insert(next).inserted { queue.append((next, current.moves + 1, revisits)) }
            }
        }
        return nil
    }
}
