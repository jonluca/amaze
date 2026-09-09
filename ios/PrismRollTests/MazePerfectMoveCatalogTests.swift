import Foundation
import XCTest
@testable import PrismRoll

final class MazePerfectMoveCatalogTests: XCTestCase {
    func testEveryCanonicalClassicLevelThroughOneThousandHasAProvenCount() {
        for number in 1...1_000 {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let minimum = MazePerfectMoveCatalog.minimumMoves(for: level)
            XCTAssertNotNil(minimum, "Missing canonical Classic level \(number)")
            XCTAssertGreaterThan(minimum ?? 0, 0, "Invalid count for Classic level \(number)")
        }
    }

    func testEarlyCatalogCountsMatchIndependentReferenceProofs() {
        // These independently checked SciPy/HiGHS counts predate the bundled
        // table. They are intentionally not derived from generated table data.
        let reference = [
            8, 19, 17, 20, 20, 19, 28, 28, 26, 31,
            34, 32, 34, 36, 43, 38, 39, 39, 40, 46,
            40, 51, 44, 47, 42, 42, 42, 50, 46, 58,
            51, 53, 52, 51, 48, 55, 57, 56, 54, 52,
            53, 62, 56, 56, 61, 58, 61, 58, 60, 58,
            57, 61, 59, 58, 54, 62, 63, 64, 65, 62,
            65, 67, 68, 66, 65, 63, 65, 60, 75, 68,
            66, 65, 62, 62, 74, 80, 79, 79, 77, 80,
            76, 77, 77, 81, 75, 82, 80, 78, 81, 76,
            71, 80, 80, 79, 73, 80, 80, 77, 74, 90
        ]
        for (index, expected) in reference.enumerated() {
            // Levels 8 and 72 use the native proof artifact instead of the
            // independent SciPy fixtures, which describe different geometry.
            guard index + 1 != 8, index + 1 != 72 else { continue }
            let level = MazeLevel.generate(number: index + 1, mode: .endless)
            XCTAssertEqual(MazePerfectMoveCatalog.minimumMoves(for: level), expected, "Level \(index + 1)")
        }
    }

    func testEarlyAndLaterCountsMatchFreshNativeProofs() {
        for number in [8, 72, 101, 137, 142, 150, 250, 432, 500, 777, 938, 999, 1_000] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            guard case let .optimal(moves, route) = MazeNativeOptimizer.solve(level: level) else {
                return XCTFail("Missing fresh native proof for level \(number)")
            }
            XCTAssertEqual(MazePerfectMoveCatalog.minimumMoves(for: level), moves, "Level \(number)")
            XCTAssertEqual(route.count, moves)
        }
    }

    func testCatalogRejectsDifferentGridsStartsDimensionsModesAndOutOfRangeNumbers() {
        let canonical = MazeLevel.generate(number: 16, mode: .endless)
        let anotherCell = canonical.openCells.sorted().first { $0 != canonical.start }!
        let altered = [
            copy(canonical, width: canonical.width + 1),
            copy(canonical, height: canonical.height + 1),
            copy(canonical, cells: canonical.openCells.subtracting([anotherCell])),
            copy(canonical, cells: canonical.openCells.union([GridCell(row: -1, column: 0)])),
            copy(canonical, start: anotherCell),
            copy(canonical, mode: .challenge),
            copy(canonical, mode: .timed),
            copy(canonical, number: 0),
            copy(canonical, number: -1),
            copy(canonical, number: 1_001),
            copy(canonical, number: Int.max),
            copy(canonical, number: 17)
        ]
        for level in altered {
            XCTAssertNil(MazePerfectMoveCatalog.minimumMoves(for: level),
                         "A catalog number alone cannot prove a different board")
        }
        XCTAssertNil(MazePerfectMoveCatalog.minimumMoves(for: MazeLevel.generate(number: 1_001, mode: .endless)))
    }

    func testNonGeometricMetadataDoesNotInvalidateACatalogProof() {
        let level = MazeLevel.generate(number: 16, mode: .endless)
        let modified = MazeLevel(number: level.number, mode: level.mode, width: level.width,
                                 height: level.height, openCells: level.openCells, start: level.start,
                                 solution: [.up, .up], moveLimit: 1, timeLimit: 0.001,
                                 coinCells: [level.start])
        XCTAssertEqual(MazePerfectMoveCatalog.minimumMoves(for: modified), 38)
    }

    func testEveryPartOfTheFullSizeOccupancyMaskMustMatch() {
        let level = MazeLevel.generate(number: 100, mode: .endless)
        for chunk in 0..<4 {
            guard let cell = level.openCells.first(where: { $0.row / 4 == chunk && $0 != level.start }) else {
                return XCTFail("Expected populated occupancy chunk \(chunk)")
            }
            let changed = copy(level, cells: level.openCells.subtracting([cell]))
            XCTAssertNil(MazePerfectMoveCatalog.minimumMoves(for: changed), "Occupancy chunk \(chunk) must be checked")
        }
    }

    func testCatalogCountIsInstantButDoesNotPretendToSupplyAnOptimalRoute() async {
        let recorder = NativeCallRecorder()
        let cache = MazeMinimumMoveCache(solver: { level, position, painted in
            recorder.solve(level: level, position: position, painted: painted)
        })
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let availableBeforeAnySearch = await cache.cachedMinimumMoves(for: level)
        let requestedMinimum = await cache.minimumMoves(for: level)
        XCTAssertEqual(availableBeforeAnySearch, 8)
        XCTAssertEqual(requestedMinimum, 8)
        XCTAssertEqual(recorder.callCount, 0, "Bundled perfect counts must never invoke native optimization")
        let missingRoute = await cache.cachedSolution(for: level, position: level.start, painted: [level.start])
        XCTAssertNil(missingRoute, "A move count is not a cached route")

        guard case let .optimal(moves, route) = await cache.solution(
            for: level, position: level.start, painted: [level.start]
        ) else { return XCTFail("Native guidance must still compute a proved route") }
        XCTAssertEqual(recorder.callCount, 1)
        XCTAssertEqual(moves, 8)
        XCTAssertEqual(route.count, 8)
        var run = MazeRun(level: level)
        for direction in route { run.move(direction) }
        XCTAssertTrue(run.isComplete)
    }

    func testCancelledCatalogMinimumRequestDoesNotStartNativeWork() async {
        let recorder = NativeCallRecorder()
        let cache = MazeMinimumMoveCache(solver: { level, position, painted in
            recorder.solve(level: level, position: position, painted: painted)
        })
        let level = MazeLevel.generate(number: 1, mode: .endless)
        let request = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await cache.minimumMoves(for: level)
        }
        let result = await request.value
        XCTAssertNil(result)
        XCTAssertEqual(recorder.callCount, 0)
    }

    private func copy(
        _ level: MazeLevel, number: Int? = nil, mode: GameMode? = nil,
        width: Int? = nil, height: Int? = nil, cells: Set<GridCell>? = nil, start: GridCell? = nil
    ) -> MazeLevel {
        MazeLevel(number: number ?? level.number, mode: mode ?? level.mode,
                  width: width ?? level.width, height: height ?? level.height,
                  openCells: cells ?? level.openCells, start: start ?? level.start,
                  solution: level.solution, moveLimit: level.moveLimit,
                  timeLimit: level.timeLimit, coinCells: level.coinCells)
    }

    private final class NativeCallRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var calls = 0

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        func solve(level: MazeLevel, position: GridCell, painted: Set<GridCell>) -> MazeNativeOptimizer.Result {
            lock.lock()
            calls += 1
            lock.unlock()
            return MazeNativeOptimizer.solve(level: level, position: position, painted: painted,
                                             isCancelled: { Task.isCancelled })
        }
    }
}
