import XCTest
@testable import PrismRoll

final class LevelProgressTests: XCTestCase {
    func testOlderSavePreservesSolvedLevelsWithoutInventingMoveRecordsOrCrowns() throws {
        let data = Data("""
        {
            "endlessLevel": 12,
            "challengeLevel": 8,
            "rewardedLevelKeys": ["endless:10", "challenge:4", "timed:2"]
        }
        """.utf8)
        let progress = try JSONDecoder().decode(ProgressData.self, from: data)

        for (number, mode) in [(10, GameMode.endless), (4, .challenge), (2, .timed)] {
            XCTAssertTrue(progress.hasCompleted(number: number, mode: mode))
            XCTAssertFalse(progress.hasOptimalCompletion(number: number, mode: mode))
            XCTAssertNil(progress.bestMoves(number: number, mode: mode))
        }
        XCTAssertFalse(progress.hasCompleted(number: 11, mode: .endless), "A skipped level is not solved")
        XCTAssertFalse(progress.hasCompleted(number: 7, mode: .challenge))
        XCTAssertEqual(progress.completedLevels, 3)
    }

    func testUnknownAndSuboptimalRunsHaveCheckmarksWithoutCrowns() {
        for optimality in [MazeOptimality.Result.undetermined, .notOptimal] {
            var progress = ProgressData()
            let run = completedRun(detour: true)
            progress.recordCompletedRun(run, optimality: optimality)
            progress.completeLevel(run.level)

            XCTAssertTrue(progress.hasCompleted(number: 10, mode: .endless))
            XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 5)
            XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .endless))
        }
    }

    func testRecordingEvidenceDoesNotAwardCoinsOrAdvanceProgress() {
        var progress = ProgressData()
        let run = completedRun()
        progress.recordCompletedRun(run, optimality: .optimal)

        XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 3)
        XCTAssertEqual(progress.points, 0)
        XCTAssertEqual(progress.completedLevels, 0)
        XCTAssertEqual(progress.endlessLevel, 1)
        XCTAssertFalse(progress.hasCompleted(number: 10, mode: .endless))
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .endless))

        progress.completeLevel(run.level)
        XCTAssertTrue(progress.hasOptimalCompletion(number: 10, mode: .endless))
        XCTAssertEqual(progress.points, 50)
    }

    func testReplayImprovesBestMovesAndNeverRemovesEarnedCrown() throws {
        var progress = ProgressData()
        let slower = completedRun(detour: true)
        let optimal = completedRun()
        progress.completeLevel(slower.level)
        progress.recordCompletedRun(slower, optimality: MazeOptimality.verify(slower))
        XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 5)
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .endless))

        progress.recordCompletedRun(optimal, optimality: MazeOptimality.verify(optimal))
        XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 3)
        XCTAssertTrue(progress.hasOptimalCompletion(number: 10, mode: .endless))

        progress.recordCompletedRun(slower)
        progress.recordCompletedRun(slower, optimality: .notOptimal)
        progress.completeLevel(slower.level)
        XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 3)
        XCTAssertTrue(progress.hasOptimalCompletion(number: 10, mode: .endless))
        XCTAssertEqual(progress.points, 50)
        XCTAssertEqual(progress.completedLevels, 1)

        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.bestMoves(number: 10, mode: .endless), 3)
        XCTAssertTrue(restored.hasOptimalCompletion(number: 10, mode: .endless))
    }

    func testLevelNumbersAndModesHaveIndependentRecords() {
        var progress = ProgressData()
        let endless = completedRun()
        let challenge = completedRun(mode: .challenge, detour: true)
        progress.completeLevel(endless.level)
        progress.recordCompletedRun(endless, optimality: .optimal)
        progress.completeLevel(challenge.level)
        progress.recordCompletedRun(challenge, optimality: .notOptimal)

        XCTAssertEqual(progress.bestMoves(number: 10, mode: .endless), 3)
        XCTAssertEqual(progress.bestMoves(number: 10, mode: .challenge), 5)
        XCTAssertTrue(progress.hasOptimalCompletion(number: 10, mode: .endless))
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .challenge))
        XCTAssertFalse(progress.hasCompleted(number: 10, mode: .timed))
        XCTAssertFalse(progress.hasCompleted(number: 9, mode: .endless))
        XCTAssertNil(progress.bestMoves(number: 9, mode: .endless))
    }

    func testIncompleteRunCannotRecordMovesOrOptimalEvidence() {
        var progress = ProgressData()
        let level = squareLevel()
        var run = MazeRun(level: level)
        run.move(.right)
        XCTAssertFalse(run.isComplete)
        progress.recordCompletedRun(run, optimality: .optimal)
        // A prior completion must not let an incomplete replay produce a crown.
        progress.completeLevel(level)

        XCTAssertNil(progress.bestMoves(number: 10, mode: .endless))
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .endless))
    }

    func testTimeRushRequiresAllFiveOptimalStagesAndCompletedRound() throws {
        var progress = ProgressData()
        let run = completedRun(mode: .timed)
        for stage in 0..<4 {
            progress.recordCompletedRun(run, optimality: .optimal, stageIndex: stage)
        }
        progress.recordCompletedRun(run, stageIndex: 4)
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .timed))

        progress.recordCompletedRun(run, optimality: .optimal, stageIndex: 4)
        XCTAssertFalse(progress.hasCompleted(number: 10, mode: .timed))
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .timed))

        progress.completeLevel(run.level)
        XCTAssertTrue(progress.hasCompleted(number: 10, mode: .timed))
        XCTAssertTrue(progress.hasOptimalCompletion(number: 10, mode: .timed))
        XCTAssertNil(progress.bestMoves(number: 10, mode: .timed))
        XCTAssertFalse(progress.hasOptimalCompletion(number: 11, mode: .timed))

        progress.recordCompletedRun(completedRun(mode: .timed, detour: true), optimality: .notOptimal, stageIndex: 0)
        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(restored, progress)
        XCTAssertTrue(restored.hasOptimalCompletion(number: 10, mode: .timed))
        XCTAssertNil(restored.bestMoves(number: 10, mode: .timed))
    }

    func testOneOptimalTimeRushStageCannotCrownWholeRound() {
        var progress = ProgressData()
        let run = completedRun(mode: .timed)
        progress.completeLevel(run.level)
        for _ in 0..<5 {
            progress.recordCompletedRun(run, optimality: .optimal, stageIndex: 0)
        }
        progress.recordCompletedRun(run, optimality: .optimal)
        progress.recordCompletedRun(run, optimality: .optimal, stageIndex: -1)
        progress.recordCompletedRun(run, optimality: .optimal, stageIndex: 5)
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .timed))

        for stage in 1..<5 {
            progress.recordCompletedRun(run, optimality: stage == 4 ? .notOptimal : .optimal, stageIndex: stage)
        }
        XCTAssertFalse(progress.hasOptimalCompletion(number: 10, mode: .timed))
        XCTAssertTrue(progress.hasCompleted(number: 10, mode: .timed))
    }

    private func completedRun(mode: GameMode = .endless, detour: Bool = false) -> MazeRun {
        var run = MazeRun(level: squareLevel(mode: mode))
        if detour { for direction in [MoveDirection.right, .left] { run.move(direction) } }
        for direction in [MoveDirection.right, .down, .left] { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        return run
    }

    private func squareLevel(mode: GameMode = .endless) -> MazeLevel {
        MazeLevel(number: 10, mode: mode, width: 2, height: 2,
                  openCells: Set((0..<2).flatMap { row in (0..<2).map { GridCell(row: row, column: $0) } }),
                  start: GridCell(row: 0, column: 0), solution: [.right, .down, .left], moveLimit: nil)
    }
}
