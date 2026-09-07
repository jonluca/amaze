import Foundation
import XCTest
@testable import PrismRoll

final class CoinLayoutMigrationTests: XCTestCase {
    func testLegacyCollectedCoordinatesCannotPayAgainOnAChangedBoard() throws {
        let legacy = Data("""
        {"points":15,"collectedCoinKeys":["endless:5:0,1","endless:5:0,2","endless:5:0,3"]}
        """.utf8)
        var progress = try JSONDecoder().decode(ProgressData.self, from: legacy)
        let run = completedRun(number: 5)
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        XCTAssertEqual(progress.points, 15)
        progress = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
    }

    func testPartiallyCollectedLegacyLevelKeepsOnlyItsRemainingAllowance() throws {
        let legacy = Data("""
        {"points":5,"collectedCoinKeys":["endless:5:0,1"]}
        """.utf8)
        var progress = try JSONDecoder().decode(ProgressData.self, from: legacy)
        let run = completedRun(number: 5)
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 10)
        XCTAssertEqual(progress.points, 15)
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        progress = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 0)
        XCTAssertEqual(progress.awardCollectedCoins(for: completedRun(number: 10)), 15)
        XCTAssertEqual(progress.points, 30)
    }

    func testNewAllowanceAndExistingCompletionBonusesRoundTripIndependently() throws {
        var progress = ProgressData()
        let run = completedRun(number: 5)
        XCTAssertEqual(progress.awardCollectedCoins(for: run), 15)
        XCTAssertEqual(progress.completeLevel(run.level), 50)
        XCTAssertEqual(progress.claimAdBonus(level: run.level), 50)
        progress = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        let regenerated = MazeLevel.generate(number: 5, mode: .endless)
        var next = MazeRun(level: regenerated)
        for direction in regenerated.solution { next.move(direction) }
        XCTAssertTrue(next.isComplete)
        XCTAssertEqual(progress.awardCollectedCoins(for: next), 0)
        XCTAssertEqual(progress.completeLevel(regenerated), 0)
        XCTAssertEqual(progress.claimAdBonus(level: regenerated), 0)
        XCTAssertEqual(progress.points, 115)
    }

    private func completedRun(number: Int) -> MazeRun {
        let cells = Set((0..<4).flatMap { row in
            (0..<4).compactMap { column in
                row == 0 || row == 3 || column == 0 || column == 3
                    ? GridCell(row: row, column: column) : nil
            }
        })
        let level = MazeLevel(number: number, mode: .endless, width: 4, height: 4,
                              openCells: cells, start: GridCell(row: 0, column: 0),
                              solution: [.right, .down, .left, .up], moveLimit: nil,
                              coinCells: Set((1...3).map { GridCell(row: 3, column: $0) }))
        var run = MazeRun(level: level)
        for direction in level.solution { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        return run
    }
}
