import Foundation
import XCTest
@testable import PrismRoll

final class GameCenterProgressTests: XCTestCase {
    func testUnlockedAndLegacyAggregateCountsCannotInventCompletions() throws {
        let progress = try decodeProgress("""
        {"endlessLevel":900,"challengeLevel":400,"timedLevel":300,
         "completedLevels":1200,"points":100000,"receivedCoinTransactionIDs":["purchase"]}
        """)
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress), .empty)
    }

    func testLegacySaveCountsOnlyExactCompletedIDsWithoutInventingPerfectSolves() throws {
        let progress = try decodeProgress("""
        {"endlessLevel":100,"challengeLevel":50,"timedLevel":30,"completedLevels":999,
         "rewardedLevelKeys":["endless:2","endless:9","endless:9","challenge:7","timed:4",
           "endless:0","endless:-1","endless:03","endless:4:stage:0","timed:4:stage:1","other:1"]}
        """)
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress),
                       GameCenterProgressSnapshot(classicCompleted: 2, limitedCompleted: 1, rushCompleted: 1))
        XCTAssertEqual(progress.completedLevelNumbers(in: .endless), [2, 9])
    }

    func testReplaysRemainOneCompletionAndPerfectEvidenceArrivesIndependently() throws {
        var progress = ProgressData()
        let classic = completedRun()
        let limited = completedRun(mode: .challenge)
        for run in [classic, limited] {
            progress.completeLevel(run.level)
            progress.completeLevel(run.level)
            progress.recordCompletedRun(run, optimality: .notOptimal)
        }
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress).perfectCompleted, 0)

        progress.recordCompletedRun(classic, optimality: .optimal)
        progress.recordCompletedRun(classic, optimality: .optimal)
        progress.recordCompletedRun(completedRun(number: 88), optimality: .optimal)
        let snapshot = GameCenterProgressSnapshot(progress: progress)
        XCTAssertEqual(snapshot, GameCenterProgressSnapshot(classicCompleted: 1, perfectCompleted: 1, limitedCompleted: 1))
        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(GameCenterProgressSnapshot(progress: restored), snapshot)
    }

    func testPerfectTimeRushRequiresFiveStageProofsAndCompletedRoundThenCountsOnce() throws {
        var progress = ProgressData()
        let run = completedRun(mode: .timed)
        for stage in 0..<4 { progress.recordCompletedRun(run, optimality: .optimal, stageIndex: stage) }
        progress.completeLevel(run.level)
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress).perfectCompleted, 0)
        progress.recordCompletedRun(run, optimality: .notOptimal, stageIndex: 4)
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress).perfectCompleted, 0)
        progress.recordCompletedRun(run, optimality: .optimal, stageIndex: 4)

        let uncompletedRound = completedRun(number: 99, mode: .timed)
        for stage in 0..<5 { progress.recordCompletedRun(uncompletedRound, optimality: .optimal, stageIndex: stage) }
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress),
                       GameCenterProgressSnapshot(perfectCompleted: 1, rushCompleted: 1))
        progress.completeLevel(run.level)
        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(GameCenterProgressSnapshot(progress: restored).perfectCompleted, 1)
    }

    func testDailyAchievementCountsUniqueMazesAcrossNonconsecutiveDaysNotLogins() throws {
        var progress = ProgressData()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let first = Date(timeIntervalSince1970: 1_789_171_200)
        for day in 0..<7 {
            let date = try XCTUnwrap(calendar.date(byAdding: .day, value: day * 2, to: first))
            progress.claimDailyReward(at: date, calendar: calendar)
            let challenge = DailyChallenge.generate(for: date, calendar: calendar)
            progress.completeDailyChallenge(challenge, at: date, calendar: calendar)
            XCTAssertEqual(progress.completeDailyChallenge(challenge, at: date, calendar: calendar), 0)
        }
        let snapshot = GameCenterProgressSnapshot(progress: progress)
        XCTAssertEqual(snapshot.dailyCompleted, 7)
        XCTAssertEqual(progress.dailyChallengeStreak, 1)
        XCTAssertEqual(snapshot.classicCompleted + snapshot.limitedCompleted + snapshot.perfectCompleted, 0)
        XCTAssertEqual(GameCenterAchievement.daily7.percentComplete(in: snapshot), 100)
    }

    func testMazeCoinCountSurvivesLegacyMigrationAndExcludesRewardsBalanceAndPurchases() throws {
        var progress = try decodeProgress("""
        {"points":100000,"collectedCoinKeys":["endless:10:0,1"],
         "receivedCoinTransactionIDs":["purchased-coins"]}
        """)
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress).mazeCoinsCollected, 1)
        let run = completedRun()
        progress.awardCollectedCoins(for: run)
        progress.awardCollectedCoins(for: run)
        progress.completeLevel(run.level)
        progress.claimAdBonus(level: run.level)
        progress.claimDailyReward(at: Date(timeIntervalSince1970: 1_789_171_200))
        XCTAssertEqual(GameCenterProgressSnapshot(progress: progress).mazeCoinsCollected, 3)
        progress.points = 0
        let restored = try JSONDecoder().decode(ProgressData.self, from: JSONEncoder().encode(progress))
        XCTAssertEqual(GameCenterProgressSnapshot(progress: restored).mazeCoinsCollected, 3)
    }

    func testAchievementMetricsAndPercentagesAreBoundedWithoutIntegerOverflow() {
        let snapshot = GameCenterProgressSnapshot(
            classicCompleted: 5, perfectCompleted: 2, limitedCompleted: 3,
            rushCompleted: 4, dailyCompleted: 6, mazeCoinsCollected: 20
        )
        XCTAssertEqual(GameCenterAchievement.classic25.percentComplete(in: snapshot), 20)
        XCTAssertEqual(GameCenterAchievement.perfect25.percentComplete(in: snapshot), 8)
        XCTAssertEqual(GameCenterAchievement.limited25.percentComplete(in: snapshot), 12)
        XCTAssertEqual(GameCenterAchievement.rush10.percentComplete(in: snapshot), 40)
        XCTAssertEqual(GameCenterAchievement.daily7.percentComplete(in: snapshot), 600.0 / 7, accuracy: 0.000001)
        XCTAssertEqual(GameCenterAchievement.coins100.percentComplete(in: snapshot), 20)
        XCTAssertEqual(GameCenterAchievement.firstMaze.percentComplete(in: snapshot), 100)

        let enormous = GameCenterProgressSnapshot(counters: snapshot.counters.mapValues { _ in Int.max })
        let negative = GameCenterProgressSnapshot(counters: snapshot.counters.mapValues { _ in -1 })
        for achievement in GameCenterAchievement.allCases {
            XCTAssertEqual(achievement.percentComplete(in: enormous), 100)
            XCTAssertEqual(achievement.percentComplete(in: negative), 0)
        }
        XCTAssertEqual(negative, .empty)
    }

    func testCatalogIDsStayStableAndEveryLeaderboardUsesItsOwnCumulativeCount() throws {
        let expectedIDs = ["first_maze", "classic_25", "classic_100", "classic_500", "perfect_1",
                           "perfect_25", "perfect_100", "limited_25", "rush_10", "daily_1", "daily_7", "coins_100"]
        XCTAssertEqual(GameCenterAchievement.allCases.map(\.id), expectedIDs.map { "com.jonluca.prismroll.achievement.\($0)" })
        XCTAssertEqual(GameCenterAchievement.allCases.reduce(0) { $0 + $1.points }, 550)
        let snapshot = GameCenterProgressSnapshot(
            classicCompleted: 1, perfectCompleted: 2, limitedCompleted: 3,
            rushCompleted: 4, dailyCompleted: 5, mazeCoinsCollected: 6
        )
        XCTAssertEqual(GameCenterLeaderboard.allCases.map { $0.score(in: snapshot) }, [1, 2, 3, 4, 5])
        XCTAssertEqual(GameCenterLeaderboard.allCases.map(\.id),
                       ["classic_completed", "perfect_completed", "limited_completed", "rush_completed", "daily_completed"]
                        .map { "com.jonluca.prismroll.leaderboard.\($0)" })
        XCTAssertEqual(GameCenterProgressSnapshot(counters: snapshot.counters), snapshot)
        XCTAssertEqual(try JSONDecoder().decode(GameCenterProgressSnapshot.self, from: JSONEncoder().encode(snapshot)), snapshot)
    }

    private func decodeProgress(_ json: String) throws -> ProgressData {
        try JSONDecoder().decode(ProgressData.self, from: Data(json.utf8))
    }

    private func completedRun(number: Int = 10, mode: GameMode = .endless) -> MazeRun {
        let start = GridCell(row: 0, column: 0)
        let cells = Set((0..<2).flatMap { row in (0..<2).map { GridCell(row: row, column: $0) } })
        let level = MazeLevel(number: number, mode: mode, width: 2, height: 2,
                              openCells: cells, start: start, solution: [.right, .down, .left],
                              moveLimit: nil, coinCells: cells.subtracting([start]))
        var run = MazeRun(level: level)
        for direction in level.solution { run.move(direction) }
        XCTAssertTrue(run.isComplete)
        return run
    }
}
