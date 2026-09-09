import Foundation
import XCTest
@testable import PrismRoll

final class MazeNativeOptimizerTests: XCTestCase {
    func testCatalogMatchesVerifiedExactReferenceCounts() {
        // Counts for 8, 72 and 150 come from native proof records with replayed
        // routes in classic-1-1000.json. The other counts were also checked by
        // the independent SciPy/HiGHS model. Include hard boards whose proofs
        // must not depend on a search deadline.
        let firstHundred = [
            8, 19, 17, 20, 20, 19, 28, 26, 26, 31,
            34, 32, 34, 36, 43, 38, 39, 39, 40, 46,
            40, 51, 44, 47, 42, 42, 42, 50, 46, 58,
            51, 53, 52, 51, 48, 55, 57, 56, 54, 52,
            53, 62, 56, 56, 61, 58, 61, 58, 60, 58,
            57, 61, 59, 58, 54, 62, 63, 64, 65, 62,
            65, 67, 68, 66, 65, 63, 65, 60, 75, 68,
            66, 62, 62, 62, 74, 80, 79, 79, 77, 80,
            76, 77, 77, 81, 75, 82, 80, 78, 81, 76,
            71, 80, 80, 79, 73, 80, 80, 77, 74, 90
        ]
        let reference = firstHundred.enumerated().map { ($0.offset + 1, $0.element) }
            + [(150, 84), (200, 91), (250, 88), (500, 91),
               (1_000, 88), (1_001, 85), (10_000, 86), (100_000, 89)]
        for (number, expected) in reference {
            let level = MazeLevel.generate(number: number, mode: .endless)
            assertOptimal(level, expected: expected)
        }
    }

    func testEverySmallBoardAndEveryStartMatchesLiteralGridOracle() {
        // The oracle performs literal cell-by-cell slides and stores full paint
        // sets; it shares neither the native flow graph nor its constraints.
        let allCells = (0..<3).flatMap { row in
            (0..<3).map { GridCell(row: row, column: $0) }
        }
        var solvable = 0
        var infeasible = 0
        for mask in 1..<(1 << allCells.count) {
            let cells = Set(allCells.enumerated().compactMap { index, cell in
                mask & (1 << index) == 0 ? nil : cell
            })
            for start in cells.sorted() {
                let level = board(width: 3, height: 3, cells: cells, start: start)
                if let expected = oracleMinimum(level) {
                    solvable += 1
                    assertOptimal(level, expected: expected, context: "mask \(mask), start \(start)")
                } else {
                    infeasible += 1
                    XCTAssertEqual(MazeNativeOptimizer.solve(level: level), .infeasible,
                                   "mask \(mask), start \(start)")
                }
            }
        }
        XCTAssertEqual(solvable, 934)
        XCTAssertEqual(infeasible, 1_370)
    }

    func testVeryLargeLevelNumbersMatchIndependentProofs() {
        // Numbered levels remain deterministic at the integer boundary. These
        // full-size boards were also solved by the separate uncapped model.
        for (number, expected) in [(1_000_000, 89), (1_000_000_000, 89), (Int.max, 92)] {
            assertOptimal(MazeLevel.generate(number: number, mode: .endless), expected: expected)
        }
    }

    func testStoredHintsCannotConstrainTheProvedMinimum() {
        let cells = Set((0..<2).flatMap { row in
            (0..<2).map { GridCell(row: row, column: $0) }
        })
        for hint in [[], [.right], [.up, .left], [.right, .left, .right, .down, .left]] as [[MoveDirection]] {
            let level = board(width: 2, height: 2, cells: cells,
                              start: GridCell(row: 0, column: 0), hint: hint)
            assertOptimal(level, expected: 3)
        }
    }

    func testMoveBudgetAndModeMetadataDoNotChangeGridMinimum() {
        let cells = Set((0..<2).flatMap { row in
            (0..<2).map { GridCell(row: row, column: $0) }
        })
        let level = MazeLevel(number: 999, mode: .challenge, width: 2, height: 2,
                              openCells: cells, start: GridCell(row: 0, column: 0),
                              solution: [.right], moveLimit: 1, timeLimit: 0.001,
                              coinCells: [GridCell(row: 1, column: 1)])
        assertOptimal(level, expected: 3)
    }

    func testInteriorStartAndOneCellBoard() {
        let origin = GridCell(row: 0, column: 0)
        assertOptimal(board(width: 1, height: 1, cells: [origin], start: origin), expected: 0)
        let cells = Set((0..<3).map { GridCell(row: 0, column: $0) })
        assertOptimal(board(width: 3, height: 1, cells: cells, start: origin), expected: 1)
        assertOptimal(board(width: 3, height: 1, cells: cells,
                            start: GridCell(row: 0, column: 1)), expected: 2)
    }

    func testIndividuallyReachableGoalsDoNotPermitDisconnectedCycles() {
        // All arms can be reached from the center, but after the first move the
        // ball cannot stop at the center to change axis. Coverage alone is not
        // sufficient: a disconnected collection of Euler cycles would be wrong.
        let center = GridCell(row: 1, column: 1)
        let cells: Set<GridCell> = [center, GridCell(row: 0, column: 1),
                                   GridCell(row: 2, column: 1), GridCell(row: 1, column: 0),
                                   GridCell(row: 1, column: 2)]
        XCTAssertEqual(MazeNativeOptimizer.solve(level: board(width: 3, height: 3,
                                                              cells: cells, start: center)), .infeasible)
    }

    func testLargeForcedRouteDoesNotDependOnHintOrPaintMaskSize() {
        var cells: Set<GridCell> = []
        for row in stride(from: 0, through: 14, by: 2) {
            for column in 0..<16 { cells.insert(GridCell(row: row, column: column)) }
            if row < 14 {
                cells.insert(GridCell(row: row + 1, column: (row / 2).isMultiple(of: 2) ? 15 : 0))
            }
        }
        assertOptimal(board(width: 16, height: 16, cells: cells,
                            start: GridCell(row: 0, column: 0)), expected: 15)
    }

    func testUnreachableTilesAreInfeasible() {
        let origin = GridCell(row: 0, column: 0)
        let disconnected: Set<GridCell> = [origin, GridCell(row: 0, column: 2)]
        XCTAssertEqual(MazeNativeOptimizer.solve(level: board(width: 3, height: 1,
                                                              cells: disconnected, start: origin)), .infeasible)
        let fullGrid = Set((0..<16).flatMap { row in
            (0..<16).map { GridCell(row: row, column: $0) }
        })
        // A fully open rectangle only permits stopping on the perimeter.
        XCTAssertEqual(MazeNativeOptimizer.solve(level: board(width: 16, height: 16,
                                                              cells: fullGrid, start: origin)), .infeasible)
    }

    func testMalformedBoardsFailWithoutClaimingInfeasibilityOrOptimality() {
        let origin = GridCell(row: 0, column: 0)
        let levels = [
            board(width: 0, height: 1, cells: [origin], start: origin),
            board(width: 1, height: -1, cells: [origin], start: origin),
            board(width: 17, height: 1, cells: [origin], start: origin),
            board(width: 1, height: 1, cells: [], start: origin),
            board(width: 2, height: 1, cells: [GridCell(row: 0, column: 1)], start: origin),
            board(width: 2, height: 1, cells: [origin, GridCell(row: -1, column: 1)], start: origin),
            board(width: 2, height: 1, cells: [origin, GridCell(row: 0, column: 2)], start: origin)
        ]
        for level in levels { XCTAssertEqual(MazeNativeOptimizer.solve(level: level), .failure) }
    }

    func testCancellationNeverReturnsAnIncumbentAsOptimal() {
        let level = MazeLevel.generate(number: 100, mode: .endless)
        XCTAssertEqual(MazeNativeOptimizer.solve(level: level, isCancelled: { true }), .cancelled)
        let probe = CancellationProbe(cancelAfter: 4)
        XCTAssertEqual(MazeNativeOptimizer.solve(level: level, isCancelled: { probe.poll() }), .cancelled)
        XCTAssertGreaterThanOrEqual(probe.pollCount, 4)
        assertOptimal(level, expected: 90)
    }

    func testNativeSearchRespondsToCancellationDeadline() {
        let level = MazeLevel.generate(number: 100, mode: .endless)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(100))
        let result = MazeNativeOptimizer.solve(level: level, isCancelled: { clock.now >= deadline })
        if case let .optimal(moves, route) = result {
            // A future faster solve is also valid; it must still be a proof.
            XCTAssertEqual(moves, 90)
            XCTAssertEqual(route.count, 90)
        } else {
            XCTAssertEqual(result, .cancelled)
        }
    }

    private func assertOptimal(
        _ level: MazeLevel, expected: Int, context: String = "",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let result = MazeNativeOptimizer.solve(level: level)
        guard case let .optimal(moves, route) = result else {
            XCTFail("Expected a proof for level \(level.number) \(context), got \(result)", file: file, line: line)
            return
        }
        XCTAssertEqual(moves, expected, "Level \(level.number) \(context)", file: file, line: line)
        XCTAssertEqual(route.count, moves, file: file, line: line)
        var position = level.start
        var painted: Set<GridCell> = [position]
        for direction in route {
            XCTAssertNotEqual(painted, level.openCells, "Route continued after completion", file: file, line: line)
            let path = literalSlide(cells: level.openCells, position: position, direction: direction)
            guard let destination = path.last else {
                XCTFail("Route contained a blocked swipe", file: file, line: line)
                return
            }
            position = destination
            painted.formUnion(path)
        }
        XCTAssertEqual(painted, level.openCells, "Route did not cover the raw grid", file: file, line: line)
    }

    private func oracleMinimum(_ level: MazeLevel) -> Int? {
        let initial = OracleState(position: level.start, painted: [level.start])
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
        var result: [GridCell] = []
        var cursor = position
        while true {
            let next = GridCell(row: cursor.row + delta.0, column: cursor.column + delta.1)
            guard cells.contains(next) else { return result }
            result.append(next)
            cursor = next
        }
    }

    private func board(
        width: Int, height: Int, cells: Set<GridCell>, start: GridCell, hint: [MoveDirection] = []
    ) -> MazeLevel {
        MazeLevel(number: 1, mode: .endless, width: width, height: height,
                  openCells: cells, start: start, solution: hint, moveLimit: nil)
    }

    private struct OracleState: Hashable {
        let position: GridCell
        let painted: Set<GridCell>
    }

    private final class CancellationProbe: @unchecked Sendable {
        // The native solver owns callback timing; this small lock protects the
        // mutable counter exposed through its @Sendable cancellation closure.
        private let lock = NSLock()
        private var calls = 0
        private let cancelAfter: Int

        init(cancelAfter: Int) { self.cancelAfter = cancelAfter }

        var pollCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        func poll() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            calls += 1
            return calls >= cancelAfter
        }
    }
}
