import XCTest
@testable import PrismRoll

final class MazeCurrentStateCacheTests: XCTestCase {
    func testTwoRealNativeProofsCanRunConcurrently() async {
        let cache = MazeMinimumMoveCache()
        let medium = MazeLevel.generate(number: 16, mode: .endless)
        let large = MazeLevel.generate(number: 100, mode: .endless)
        async let mediumSolution = cache.solution(for: medium, position: medium.start, painted: [medium.start])
        async let largeSolution = cache.solution(for: large, position: large.start, painted: [large.start])
        let results = await (mediumSolution, largeSolution)
        guard case let .optimal(mediumMoves, mediumRoute) = results.0,
              case let .optimal(largeMoves, largeRoute) = results.1 else {
            return XCTFail("Both concurrent native routes must be proved")
        }
        XCTAssertEqual(mediumMoves, 38)
        XCTAssertEqual(largeMoves, 90)
        XCTAssertEqual(mediumRoute.count, 38)
        XCTAssertEqual(largeRoute.count, 90)
    }

    func testEveryProvenSuffixIsImmediatelyAvailableWithoutAnotherSolve() async {
        let cache = MazeMinimumMoveCache()
        let level = MazeLevel.generate(number: 100, mode: .endless)
        guard case let .optimal(moves, route) = await cache.solution(
            for: level, position: level.start, painted: [level.start]
        ) else { return XCTFail("Missing initial proof") }

        var position = level.start
        var painted: Set<GridCell> = [position]
        for index in 0...route.count {
            let cached = await cache.cachedSolution(for: level, position: position, painted: painted)
            XCTAssertEqual(cached, .optimal(moves: moves - index, route: Array(route.dropFirst(index))))
            guard index < route.count else { break }
            let path = MazeSolver.path(from: position, direction: route[index], in: level.openCells)
            position = path.last!
            painted.formUnion(path)
        }
        let initialMinimum = await cache.cachedMinimumMoves(for: level)
        XCTAssertEqual(initialMinimum, moves, "Suffix insertion must not evict the same grid's starting proof")
    }

    func testCurrentStateCacheSeparatesPaintHistoryAndPosition() async {
        let cache = MazeMinimumMoveCache()
        let level = square()
        let origin = level.start
        let topRight = GridCell(row: 0, column: 1)
        let painted: Set<GridCell> = [origin, topRight, GridCell(row: 1, column: 0)]

        let original = await cache.solution(for: level, position: origin, painted: [origin])
        XCTAssertEqual(minimum(original), 3)
        let missingHistory = await cache.cachedSolution(for: level, position: origin, painted: painted)
        XCTAssertNil(missingHistory)

        let remaining = await cache.solution(for: level, position: origin, painted: painted)
        XCTAssertEqual(minimum(remaining), 2)
        let differentPosition = await cache.solution(for: level, position: topRight, painted: painted)
        XCTAssertEqual(minimum(differentPosition), 1)
        let originalAgain = await cache.cachedSolution(for: level, position: origin, painted: [origin])
        XCTAssertEqual(minimum(originalAgain), 3)
    }

    func testCompletedCurrentStateDoesNotOverwriteTheInitialPerfectTarget() async {
        let cache = MazeMinimumMoveCache()
        let level = square()
        let completed = await cache.solution(for: level, position: level.start, painted: level.openCells)
        XCTAssertEqual(completed, .optimal(moves: 0, route: []))
        let uncachedInitial = await cache.cachedMinimumMoves(for: level)
        XCTAssertNil(uncachedInitial)
        let initial = await cache.minimumMoves(for: level)
        XCTAssertEqual(initial, 3)
    }

    func testCancelledCurrentStateRequestCanBeRetried() async {
        let cache = MazeMinimumMoveCache()
        let level = square()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await cache.solution(for: level, position: level.start, painted: [level.start])
        }
        let cancelled = await task.value
        XCTAssertNil(cancelled)
        let missing = await cache.cachedSolution(for: level, position: level.start, painted: [level.start])
        XCTAssertNil(missing)
        let retried = await cache.solution(for: level, position: level.start, painted: [level.start])
        XCTAssertEqual(minimum(retried), 3)
    }

    private func minimum(_ result: MazeNativeOptimizer.Result?) -> Int? {
        guard case let .optimal(moves, _) = result else { return nil }
        return moves
    }

    private func square() -> MazeLevel {
        let cells = Set((0..<2).flatMap { row in
            (0..<2).map { GridCell(row: row, column: $0) }
        })
        return MazeLevel(number: 1, mode: .endless, width: 2, height: 2,
                         openCells: cells, start: GridCell(row: 0, column: 0),
                         solution: [], moveLimit: nil)
    }
}
