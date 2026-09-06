import XCTest
@testable import PrismRoll

final class DailyRewardsTests: XCTestCase {
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return result
    }

    func testLoginRewardsAreOnceDailyAdvanceCapAndResetAfterMissedDay() throws {
        var progress = ProgressData()
        let first = date(month: 9, day: 6)
        XCTAssertTrue(progress.canClaimDailyReward(at: first, calendar: calendar))
        XCTAssertEqual(progress.dailyRewardAmount(at: first, calendar: calendar), 25)
        XCTAssertEqual(progress.claimDailyReward(at: first, calendar: calendar), 25)
        XCTAssertFalse(progress.canClaimDailyReward(at: first, calendar: calendar))
        XCTAssertEqual(progress.claimDailyReward(at: date(month: 9, day: 6, hour: 23), calendar: calendar), 0)
        for offset in 1...7 {
            let today = calendar.date(byAdding: .day, value: offset, to: first)!
            XCTAssertEqual(progress.claimDailyReward(at: today, calendar: calendar), 25 + 5 * min(offset, 6))
        }
        XCTAssertEqual(progress.dailyStreak, 8)
        let missed = calendar.date(byAdding: .day, value: 9, to: first)!
        XCTAssertEqual(progress.dailyCurrentStreak(at: missed, calendar: calendar), 0)
        XCTAssertEqual(progress.dailyRewardAmount(at: missed, calendar: calendar), 25)
        XCTAssertEqual(progress.claimDailyReward(at: missed, calendar: calendar), 25)
        XCTAssertEqual(progress.dailyStreak, 1)
        let saved = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
        XCTAssertEqual(restored, progress)
        XCTAssertEqual(restored.claimDailyReward(at: missed, calendar: calendar), 0)
    }

    func testConsecutiveCalendarDaysWorkAcrossSpringAndFallDaylightSaving() {
        for (month, day) in [(3, 7), (10, 31)] {
            var progress = ProgressData()
            let first = date(month: month, day: day)
            let next = calendar.date(byAdding: .day, value: 1, to: first)!
            XCTAssertNotEqual(next.timeIntervalSince(first), 86_400)
            XCTAssertEqual(progress.claimDailyReward(at: first, calendar: calendar), 25)
            XCTAssertEqual(progress.claimDailyReward(at: next, calendar: calendar), 30)
            XCTAssertEqual(progress.dailyCurrentStreak(at: next, calendar: calendar), 2)
        }
    }

    func testClockRollbackDoesNotAwardOrReduceStoredStreak() {
        var progress = ProgressData()
        progress.claimDailyReward(at: date(month: 9, day: 6), calendar: calendar)
        progress.claimDailyReward(at: date(month: 9, day: 7), calendar: calendar)
        let original = progress
        XCTAssertEqual(progress.claimDailyReward(at: date(month: 9, day: 5), calendar: calendar), 0)
        XCTAssertEqual(progress.claimDailyReward(at: date(month: 9, day: 7, hour: 11), calendar: calendar), 0)
        XCTAssertEqual(progress, original)
        XCTAssertEqual(progress.claimDailyReward(at: date(month: 9, day: 8), calendar: calendar), 35)
    }

    func testDailyChallengeIsDeterministicWithinLocalDateAndSolvable() {
        let first = date(month: 9, day: 6, hour: 1)
        let late = date(month: 9, day: 6, hour: 23)
        let challenge = DailyChallenge.generate(for: first, calendar: calendar)
        XCTAssertEqual(challenge.id, "2026-09-06")
        XCTAssertEqual(challenge, .generate(for: late, calendar: calendar))
        var otherCalendar = Calendar(identifier: .buddhist)
        otherCalendar.timeZone = calendar.timeZone
        XCTAssertEqual(challenge, .generate(for: first, calendar: otherCalendar))
        XCTAssertNotEqual(challenge.id, DailyChallenge.generate(for: date(month: 9, day: 7), calendar: calendar).id)
        for offset in 0..<100 {
            let today = calendar.date(byAdding: .day, value: offset, to: first)!
            let daily = DailyChallenge.generate(for: today, calendar: calendar)
            XCTAssertTrue(daily.level.coinCells.isEmpty)
            XCTAssertEqual(daily.level.mode, .challenge)
            var run = MazeRun(level: daily.level)
            for direction in daily.level.solution { run.move(direction) }
            XCTAssertTrue(run.isComplete)
            XCTAssertFalse(run.isFailed)
        }
    }

    func testDailyCompletionHasSeparateRewardsStreakAndRelaunchLedger() throws {
        var progress = ProgressData()
        let first = date(month: 9, day: 6)
        let next = date(month: 9, day: 7)
        let challenge = DailyChallenge.generate(for: first, calendar: calendar)
        XCTAssertEqual(progress.completeDailyChallenge(challenge, at: first, calendar: calendar), 100)
        XCTAssertEqual(progress.completeDailyChallenge(challenge, at: first, calendar: calendar), 0)
        XCTAssertTrue(progress.hasCompletedDailyChallenge(on: first, calendar: calendar))
        XCTAssertEqual(progress.dailyChallengeStreak, 1)
        XCTAssertEqual(progress.completedLevels, 0)
        XCTAssertEqual(progress.challengeLevel, 1)
        XCTAssertFalse(progress.hasCompleted(challenge.level))
        XCTAssertEqual(progress.claimDailyReward(at: first, calendar: calendar), 25)
        let tomorrow = DailyChallenge.generate(for: next, calendar: calendar)
        XCTAssertEqual(progress.completeDailyChallenge(tomorrow, at: first, calendar: calendar), 0)
        XCTAssertEqual(progress.completeDailyChallenge(tomorrow, at: next, calendar: calendar), 100)
        XCTAssertEqual(progress.dailyChallengeStreak, 2)
        let missed = date(month: 9, day: 9)
        XCTAssertEqual(progress.dailyChallengeCurrentStreak(at: missed, calendar: calendar), 0)
        let missedChallenge = DailyChallenge.generate(for: missed, calendar: calendar)
        XCTAssertEqual(progress.completeDailyChallenge(missedChallenge, at: missed, calendar: calendar), 100)
        XCTAssertEqual(progress.dailyChallengeStreak, 1)
        let rollback = date(month: 9, day: 8)
        XCTAssertEqual(progress.completeDailyChallenge(.generate(for: rollback, calendar: calendar),
                                                     at: rollback, calendar: calendar), 0)
        let saved = try JSONEncoder().encode(progress)
        var restored = try JSONDecoder().decode(ProgressData.self, from: saved)
        XCTAssertEqual(restored, progress)
        XCTAssertTrue(restored.hasCompletedDailyChallenge(challenge))
        XCTAssertEqual(restored.completeDailyChallenge(missedChallenge, at: missed, calendar: calendar), 0)
        XCTAssertEqual(restored.points, 325)
    }

    private func date(month: Int, day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }
}
