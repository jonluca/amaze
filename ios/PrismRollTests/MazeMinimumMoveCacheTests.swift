import XCTest
@testable import PrismRoll

final class MazeMinimumMoveCacheTests: XCTestCase {
    func testSameLevelNumberCannotReuseProofForADifferentGridOrStart() async {
        let cache = MazeMinimumMoveCache()
        let cells = Set((0..<3).map { GridCell(row: 0, column: $0) })
        let leftStart = level(width: 3, height: 1, cells: cells)
        let middleStart = level(width: 3, height: 1, cells: cells, start: GridCell(row: 0, column: 1))
        let shorterGrid = level(width: 3, height: 1, cells: cells.subtracting([GridCell(row: 0, column: 2)]))

        let leftMinimum = await cache.minimumMoves(for: leftStart)
        let missingMiddle = await cache.cachedMinimumMoves(for: middleStart)
        let missingShorter = await cache.cachedMinimumMoves(for: shorterGrid)
        XCTAssertEqual(leftMinimum, 1)
        XCTAssertNil(missingMiddle)
        XCTAssertNil(missingShorter)

        let middleMinimum = await cache.minimumMoves(for: middleStart)
        let shorterMinimum = await cache.minimumMoves(for: shorterGrid)
        let cachedLeft = await cache.cachedMinimumMoves(for: leftStart)
        XCTAssertEqual(middleMinimum, 2)
        XCTAssertEqual(shorterMinimum, 1)
        XCTAssertEqual(cachedLeft, 1)
    }

    func testGridProofSurvivesChangesToLevelMetadata() async {
        let cache = MazeMinimumMoveCache()
        let original = level(width: 2, height: 1,
                             cells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)])
        let updated = MazeLevel(number: 99, mode: .challenge, width: original.width,
                                height: original.height, openCells: original.openCells,
                                start: original.start, solution: [.left, .right], moveLimit: 5)
        let minimum = await cache.minimumMoves(for: original)
        let reused = await cache.cachedMinimumMoves(for: updated)
        XCTAssertEqual(minimum, 1)
        XCTAssertEqual(reused, 1)
    }

    func testCancelledRequestDoesNotCacheAnUnprovenResult() async {
        let cache = MazeMinimumMoveCache()
        let board = level(width: 2, height: 1,
                          cells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)])
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await cache.minimumMoves(for: board)
        }
        let cancelledResult = await cancelled.value
        let nextResult = await cache.minimumMoves(for: board)
        XCTAssertNil(cancelledResult)
        XCTAssertEqual(nextResult, 1)
    }

    func testCacheEvictsTheLeastRecentlyUsedGridAfterThirtyTwoEntries() async {
        let cache = MazeMinimumMoveCache()
        let boards = (0..<33).map { index in
            level(width: index % 16 + 1, height: index / 16 + 1,
                  cells: [GridCell(row: 0, column: 0)])
        }
        for board in boards.prefix(32) {
            let minimum = await cache.minimumMoves(for: board)
            XCTAssertEqual(minimum, 0)
        }
        let refreshed = await cache.minimumMoves(for: boards[0])
        let newest = await cache.minimumMoves(for: boards[32])
        let retained = await cache.cachedMinimumMoves(for: boards[0])
        let evicted = await cache.cachedMinimumMoves(for: boards[1])
        XCTAssertEqual(refreshed, 0)
        XCTAssertEqual(newest, 0)
        XCTAssertEqual(retained, 0)
        XCTAssertNil(evicted)
    }

    private func level(
        width: Int, height: Int, cells: Set<GridCell>, start: GridCell = GridCell(row: 0, column: 0)
    ) -> MazeLevel {
        MazeLevel(number: 16, mode: .endless, width: width, height: height,
                  openCells: cells, start: start, solution: [], moveLimit: nil)
    }
}
