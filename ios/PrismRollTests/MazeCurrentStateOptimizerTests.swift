import XCTest
@testable import PrismRoll

final class MazeCurrentStateOptimizerTests: XCTestCase {
    func testEverySmallBoardPositionAndPaintSetMatchesLiteralGridOracle() {
        // Exhaust all 1,458 valid states of every nonempty 2x3 board, including
        // paint histories that cannot be reached from the catalog's start.
        let allCells = (0..<2).flatMap { row in
            (0..<3).map { GridCell(row: row, column: $0) }
        }
        var checked = 0
        for mask in 1..<(1 << allCells.count) {
            let cells = Set(allCells.enumerated().compactMap { index, cell in
                mask & (1 << index) == 0 ? nil : cell
            })
            let ordered = cells.sorted()
            let level = board(width: 3, height: 2, cells: cells, start: ordered[0])
            for position in ordered {
                for paintMask in 1..<(1 << ordered.count) {
                    let painted = Set(ordered.enumerated().compactMap { index, cell in
                        paintMask & (1 << index) == 0 ? nil : cell
                    })
                    guard painted.contains(position) else { continue }
                    let expected = oracleMinimum(level: level, position: position, painted: painted)
                    assertSolution(level: level, position: position, painted: painted, expected: expected,
                                   context: "board \(mask), position \(position), paint \(paintMask)")
                    checked += 1
                }
            }
        }
        XCTAssertEqual(checked, 1_458)
    }

    func testAlreadyPaintedUnreachableCellsDoNotMakeRemainingStateInfeasible() {
        let origin = GridCell(row: 0, column: 0)
        let unreachable = GridCell(row: 0, column: 3)
        let cells: Set<GridCell> = [origin, GridCell(row: 0, column: 1), unreachable]
        let level = board(width: 4, height: 1, cells: cells, start: origin)
        assertSolution(level: level, position: origin, painted: [origin], expected: nil)
        assertSolution(level: level, position: origin, painted: [origin, unreachable], expected: 1)
        assertSolution(level: level, position: unreachable, painted: cells, expected: 0)

        // The center of an open square cannot be painted by sliding from a
        // corner, but this is a valid solvable state once it is already painted.
        let square = Set((0..<3).flatMap { row in
            (0..<3).map { GridCell(row: row, column: $0) }
        })
        let squareLevel = board(width: 3, height: 3, cells: square, start: origin)
        assertSolution(level: squareLevel, position: origin, painted: [origin], expected: nil)
        assertSolution(level: squareLevel, position: origin,
                       painted: [origin, GridCell(row: 1, column: 1)], expected: 4)
    }

    func testInteriorPositionAndPaintHistoryDetermineRemainingMinimum() {
        let cells = Set((0..<5).map { GridCell(row: 0, column: $0) })
        let middle = GridCell(row: 0, column: 2)
        let level = board(width: 5, height: 1, cells: cells, start: GridCell(row: 0, column: 0))
        assertSolution(level: level, position: middle, painted: [middle], expected: 2)
        assertSolution(level: level, position: middle,
                       painted: Set(cells.filter { $0.column <= 2 }), expected: 1)
        assertSolution(level: level, position: middle, painted: cells, expected: 0)
    }

    func testMalformedCurrentStateFailsWithoutReportingAProof() {
        let origin = GridCell(row: 0, column: 0)
        let end = GridCell(row: 0, column: 1)
        let outside = GridCell(row: 1, column: 0)
        let level = board(width: 2, height: 1, cells: [origin, end], start: origin)
        for (position, painted) in [(outside, Set([origin])), (origin, Set<GridCell>()),
                                    (origin, Set([end])), (origin, Set([origin, outside]))] {
            XCTAssertEqual(MazeNativeOptimizer.solve(level: level, position: position, painted: painted), .failure)
        }
    }

    func testCurrentStateOnHardLevelsHasExactlyTheProvenSuffixMinimum() {
        // Any suffix of a shortest route must itself be shortest for its exact
        // position and paint set, providing an independent current-state bound.
        for number in [100, 1_000, Int.max] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            guard case let .optimal(moves, route) = MazeNativeOptimizer.solve(level: level) else {
                return XCTFail("Missing initial proof for level \(number)")
            }
            var position = level.start
            var painted: Set<GridCell> = [position]
            let prefixCount = route.count * 3 / 4
            for direction in route.prefix(prefixCount) {
                let path = literalSlide(cells: level.openCells, position: position, direction: direction)
                position = path.last!
                painted.formUnion(path)
            }
            assertSolution(level: level, position: position, painted: painted,
                           expected: moves - prefixCount, context: "level \(number)")
        }
    }

    func testDetourIsSolvedFromTheActualPaintSet() {
        let cells: Set<GridCell> = [
            GridCell(row: 0, column: 0), GridCell(row: 0, column: 1), GridCell(row: 0, column: 2),
            GridCell(row: 1, column: 0), GridCell(row: 1, column: 2),
            GridCell(row: 2, column: 0), GridCell(row: 2, column: 1), GridCell(row: 2, column: 2)
        ]
        let level = board(width: 3, height: 3, cells: cells, start: GridCell(row: 0, column: 0))
        var position = level.start
        var painted: Set<GridCell> = [position]
        // Return to the same stop after a real detour. Position alone cannot
        // identify the remaining minimum: the top edge is now already painted.
        for direction in [MoveDirection.right, .left] {
            let path = literalSlide(cells: cells, position: position, direction: direction)
            position = path.last!
            painted.formUnion(path)
        }
        XCTAssertEqual(position, level.start)
        XCTAssertEqual(oracleMinimum(level: level, position: position, painted: painted), 3)
        assertSolution(level: level, position: position, painted: painted, expected: 3)
    }

    func testCancellationOfCurrentStateNeverPublishesAnIncumbent() {
        let level = MazeLevel.generate(number: 100, mode: .endless)
        XCTAssertEqual(MazeNativeOptimizer.solve(level: level, position: level.start,
                                                  painted: [level.start], isCancelled: { true }), .cancelled)
    }

    private func assertSolution(
        level: MazeLevel, position: GridCell, painted: Set<GridCell>, expected: Int?, context: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let result = MazeNativeOptimizer.solve(level: level, position: position, painted: painted)
        guard let expected else {
            XCTAssertEqual(result, .infeasible, context, file: file, line: line)
            return
        }
        guard case let .optimal(moves, route) = result else {
            return XCTFail("Expected \(expected) moves for \(context), got \(result)", file: file, line: line)
        }
        XCTAssertEqual(moves, expected, context, file: file, line: line)
        XCTAssertEqual(route.count, moves, context, file: file, line: line)
        var cursor = position
        var covered = painted
        for direction in route {
            XCTAssertNotEqual(covered, level.openCells, "Continued after completion: \(context)", file: file, line: line)
            let path = literalSlide(cells: level.openCells, position: cursor, direction: direction)
            guard let destination = path.last else {
                return XCTFail("Blocked direction: \(context)", file: file, line: line)
            }
            cursor = destination
            covered.formUnion(path)
        }
        XCTAssertEqual(covered, level.openCells, context, file: file, line: line)
    }

    private func oracleMinimum(level: MazeLevel, position: GridCell, painted: Set<GridCell>) -> Int? {
        let initial = OracleState(position: position, painted: painted)
        var queue = [(initial, 0)]
        var visited: Set<OracleState> = [initial]
        var cursor = 0
        while cursor < queue.count {
            let (state, moves) = queue[cursor]
            cursor += 1
            if state.painted == level.openCells { return moves }
            for direction in MoveDirection.allCases {
                let path = literalSlide(cells: level.openCells, position: state.position, direction: direction)
                guard let destination = path.last else { continue }
                let next = OracleState(position: destination, painted: state.painted.union(path))
                if visited.insert(next).inserted { queue.append((next, moves + 1)) }
            }
        }
        return nil
    }

    private func literalSlide(cells: Set<GridCell>, position: GridCell, direction: MoveDirection) -> [GridCell] {
        let delta: (Int, Int) = switch direction {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
        var path: [GridCell] = []
        var cursor = position
        while true {
            let next = GridCell(row: cursor.row + delta.0, column: cursor.column + delta.1)
            guard cells.contains(next) else { return path }
            path.append(next)
            cursor = next
        }
    }

    private func board(width: Int, height: Int, cells: Set<GridCell>, start: GridCell) -> MazeLevel {
        MazeLevel(number: 1, mode: .endless, width: width, height: height,
                  openCells: cells, start: start, solution: [], moveLimit: nil)
    }

    private struct OracleState: Hashable {
        let position: GridCell
        let painted: Set<GridCell>
    }
}
