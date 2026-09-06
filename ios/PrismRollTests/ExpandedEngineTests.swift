import XCTest
@testable import PrismRoll

final class ExpandedEngineTests: XCTestCase {
    func testTimedLevelsHaveExecutableSolutionsAndExplicitTimeBudgets() {
        for number in 1...200 {
            let level = MazeLevel.generate(number: number, mode: .timed)
            XCTAssertEqual(level, .generate(number: number, mode: .timed))
            XCTAssertNil(level.moveLimit)
            XCTAssertGreaterThanOrEqual(level.timeLimit ?? 0, Double(level.solution.count * 2))
            XCTAssertGreaterThanOrEqual(level.timeLimit ?? 0, 30)
            XCTAssertTrue(level.coinCells.isEmpty)
            var run = MazeRun(level: level)
            for direction in level.solution { XCTAssertFalse(run.move(direction).isEmpty) }
            XCTAssertTrue(run.isComplete)
            XCTAssertFalse(run.isFailed, "Elapsed time is owned by the app lifecycle")
        }
        XCTAssertEqual(GameMode.endless.rawValue, "endless")
        XCTAssertEqual(GameMode.challenge.rawValue, "challenge")
        XCTAssertEqual(GameMode.timed.title, "Time Rush")
    }

    func testEveryFifthEndlessBoardHasThreeReachableCoinsAwayFromStart() {
        for number in 1...150 {
            let level = MazeLevel.generate(number: number, mode: .endless)
            XCTAssertEqual(level.coinCells.count, number.isMultiple(of: 5) ? 3 : 0)
            XCTAssertTrue(level.coinCells.isSubset(of: level.openCells))
            XCTAssertFalse(level.coinCells.contains(level.start))
            XCTAssertNil(level.timeLimit)
            var run = MazeRun(level: level)
            XCTAssertTrue(run.collectedCoinCells.isEmpty)
            for direction in level.solution { run.move(direction) }
            XCTAssertEqual(run.collectedCoinCells, level.coinCells)
        }
    }

    func testExtraMovesReviveFailurePersistAndResetWithRun() throws {
        let level = squareChallenge(moveLimit: 3)
        var run = MazeRun(level: level)
        run.move(.right)
        run.move(.left)
        run.move(.right)
        XCTAssertTrue(run.isFailed)
        XCTAssertFalse(run.grantExtraMoves(count: 0))
        XCTAssertFalse(run.grantExtraMoves(count: -3))
        XCTAssertTrue(run.grantExtraMoves(count: 2))
        XCTAssertFalse(run.isFailed)
        XCTAssertEqual(run.extraMovesGranted, 2)
        XCTAssertEqual(run.effectiveMoveLimit, 5)
        XCTAssertEqual(run.remainingMoves, 2)
        XCTAssertTrue(run.hintIsGuaranteed)
        let data = try JSONEncoder().encode(run)
        var restored = try JSONDecoder().decode(MazeRun.self, from: data)
        XCTAssertEqual(restored, run)
        restored.move(.down)
        restored.move(.left)
        XCTAssertTrue(restored.isComplete)
        XCTAssertFalse(restored.isFailed)
        XCTAssertFalse(restored.grantExtraMoves(count: 5))
        restored.reset()
        XCTAssertEqual(restored.extraMovesGranted, 0)
        XCTAssertEqual(restored.remainingMoves, 3)
        var endless = MazeRun(level: .generate(number: 1, mode: .endless))
        XCTAssertFalse(endless.grantExtraMoves(count: 5))
    }

    func testExtraMoveAllowanceSaturatesWithoutIntegerOverflow() {
        var run = MazeRun(level: squareChallenge(moveLimit: 3))
        XCTAssertTrue(run.grantExtraMoves(count: Int.max))
        XCTAssertEqual(run.effectiveMoveLimit, Int.max)
        XCTAssertFalse(run.grantExtraMoves(count: 1))
    }

    func testCoinAwardsAreOncePerTileAcrossRetriesAndSaves() throws {
        let level = MazeLevel.generate(number: 5, mode: .endless)
        var run = MazeRun(level: level)
        var progress = ProgressData()
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        var coins = 0
        for direction in level.solution {
            run.move(direction)
            coins += progress.awardCollectedCoins(for: run)
            XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        }
        XCTAssertEqual(coins, 15)
        XCTAssertEqual(progress.points, 15)
        XCTAssertEqual(progress.completeLevel(level), 50)
        let saved = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
        run.reset()
        for direction in level.solution {
            run.move(direction)
            XCTAssertEqual(restored.awardCollectedCoins(for: run), 0)
        }
        XCTAssertEqual(restored.completeLevel(level), 0)
        XCTAssertEqual(restored.points, 65)
        var another = MazeRun(level: .generate(number: 10, mode: .endless))
        for direction in another.level.solution { another.move(direction) }
        XCTAssertEqual(restored.awardCollectedCoins(for: another), 15)
    }

    func testCoinsAreCollectedAlongEntireSlideNotJustDestination() {
        let cells: Set<GridCell> = (0..<3).map { GridCell(row: 0, column: $0) }.reduce(into: []) { $0.insert($1) }
        let start = GridCell(row: 0, column: 0)
        let level = MazeLevel(number: 500, mode: .endless, width: 3, height: 1,
                              openCells: cells, start: start, solution: [.right], moveLimit: nil,
                              coinCells: cells.subtracting([start]))
        var run = MazeRun(level: level)
        run.move(.right)
        XCTAssertEqual(run.collectedCoinCells.count, 2)
        var progress = ProgressData()
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 10)
    }

    private func squareChallenge(moveLimit: Int) -> MazeLevel {
        MazeLevel(number: 1, mode: .challenge, width: 2, height: 2,
                  openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1),
                              GridCell(row: 1, column: 0), GridCell(row: 1, column: 1)],
                  start: GridCell(row: 0, column: 0), solution: [.right, .down, .left], moveLimit: moveLimit)
    }
}
