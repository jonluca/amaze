#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameLifecycleTests: XCTestCase {
    func testTimerStartsOnFirstValidMoveAndUsesElapsedTime() throws {
        try withDefaults { defaults in
            var elapsed = 100.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            elapsed += 100
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, initial)
            XCTAssertFalse(store.clockRunning)
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertTrue(store.clockRunning)
            elapsed += 2.5
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 2.5, accuracy: 0.001)
        }
    }

    func testBackgroundHiddenAndModalTimeDoNotConsumeCountdown() throws {
        try withDefaults { defaults in
            var elapsed = 0.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            elapsed += 1
            store.setActivity(active: false)
            elapsed += 100
            store.setActivity(active: true)
            elapsed += 1
            store.setActivity(visible: false)
            elapsed += 100
            store.setActivity(visible: true)
            elapsed += 1
            store.setActivity(modal: true)
            elapsed += 100
            store.setActivity(modal: false)
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 3, accuracy: 0.001)
            elapsed += 2
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 5, accuracy: 0.001)
        }
    }

    func testRewardPresentationPausesTimerAndBlocksMovesUntilDismissal() throws {
        try withDefaults { defaults in
            var elapsed = 0.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let before = store.run
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            store.beginReward()
            elapsed += 120
            store.tick()
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertEqual(store.run, before)
            XCTAssertEqual(store.clock?.remainingSeconds, initial)
            store.finishReward() // An early close grants nothing.
            XCTAssertNil(store.hint)
            elapsed += 1
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 1, accuracy: 0.001)
        }
    }

    func testEarnedTimeRewardRevivesExpiredRunOnlyOnce() throws {
        try withDefaults { defaults in
            var elapsed = 0.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            elapsed += 1_000
            store.tick()
            XCTAssertTrue(store.isFailed)
            let request = try XCTUnwrap(store.rewardRequest(.extraTime))
            store.beginReward()
            elapsed += 100
            store.applyReward(request)
            store.applyReward(request)
            XCTAssertEqual(store.clock?.remainingSeconds, 30)
            XCTAssertEqual(store.clock?.rewardedExtensions, 1)
            XCTAssertFalse(store.isFailed)
            XCTAssertFalse(store.clockRunning, "An earned callback must not resume the clock while the ad is still open")
            store.finishReward()
            elapsed += 1
            store.tick()
            XCTAssertEqual(store.clock?.remainingSeconds, 29)
        }
    }

    func testExpiredCountdownCannotOfferHintBeforeNextUITick() throws {
        try withDefaults { defaults in
            var elapsed = 0.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            elapsed += 1_000
            XCTAssertNil(store.rewardRequest(.hint), "Ad eligibility must refresh elapsed time before promising a usable hint")
            XCTAssertTrue(store.isFailed)
            XCTAssertNotNil(store.rewardRequest(.extraTime))
        }
    }

    func testStaleRewardCannotAffectReplayedOrDifferentModeRun() throws {
        try withDefaults { defaults in
            let store = GameStore(defaults: defaults, uptime: { 0 })
            quiet(store)
            store.switchMode(.timed)
            let request = try XCTUnwrap(store.rewardRequest(.extraTime))
            store.replay()
            let resetClock = store.clock
            store.applyReward(request)
            XCTAssertEqual(store.clock, resetClock)
            let otherRequest = try XCTUnwrap(store.rewardRequest(.skip))
            store.switchMode(.challenge)
            let challenge = store.run
            store.applyReward(otherRequest)
            XCTAssertEqual(store.run, challenge)
            XCTAssertEqual(store.progress.challengeLevel, 1)
            XCTAssertEqual(store.progress.timedLevel, 1)
        }
    }

    func testHintRequiresMatchingPositionAndRewardCallback() async throws {
        try await withAsyncDefaults { defaults in
            let store = GameStore(defaults: defaults)
            quiet(store)
            let ready = await store.prepareOptimalHint()
            XCTAssertTrue(ready)
            let stale = try XCTUnwrap(store.rewardRequest(.hint))
            store.move(try XCTUnwrap(store.run.hintDirection))
            store.applyReward(stale)
            XCTAssertNil(store.hint)
            let nextReady = await store.prepareOptimalHint()
            XCTAssertTrue(nextReady)
            let request = try XCTUnwrap(store.rewardRequest(.hint))
            store.beginReward()
            XCTAssertNil(store.hint)
            store.applyReward(request)
            XCTAssertEqual(store.hint, store.run.hintDirection)
            XCTAssertNotNil(store.hint)
            store.finishReward()
        }
    }

    func testMoveRewardAndSkipAreIdempotentAndSkipDoesNotEarnCoins() throws {
        try withDefaults { defaults in
            let store = GameStore(defaults: defaults)
            quiet(store)
            store.switchMode(.challenge)
            let initialMoves = try XCTUnwrap(store.run.remainingMoves)
            let moves = try XCTUnwrap(store.rewardRequest(.extraMoves))
            store.applyReward(moves)
            store.applyReward(moves)
            XCTAssertEqual(store.run.remainingMoves, initialMoves + 3)
            let skip = try XCTUnwrap(store.rewardRequest(.skip))
            store.applyReward(skip)
            store.applyReward(skip)
            XCTAssertEqual(store.run.level.number, 2)
            XCTAssertEqual(store.progress.challengeLevel, 2)
            XCTAssertEqual(store.progress.points, 0)
            XCTAssertEqual(store.progress.completedLevels, 0)
        }
    }

    func testTimerRelaunchRestoresRemainingTimeWithoutChargingOfflineDuration() throws {
        try withDefaults { defaults in
            var elapsed = 0.0
            let store = GameStore(defaults: defaults, uptime: { elapsed })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            elapsed += 3.25
            store.setActivity(active: false)
            let remaining = try XCTUnwrap(store.clock?.remainingSeconds)
            elapsed += 10_000
            let restored = GameStore(defaults: defaults, uptime: { elapsed })
            restored.tick()
            XCTAssertEqual(restored.run, store.run)
            XCTAssertEqual(restored.clock?.remainingSeconds, remaining)
            XCTAssertEqual(restored.mode, .timed)
            elapsed += 1
            restored.tick()
            XCTAssertEqual(try XCTUnwrap(restored.clock?.remainingSeconds), remaining - 1, accuracy: 0.001)
        }
    }

    func testDailyClaimIsOncePerDayAcrossRelaunchAndStreakResetsAfterMiss() throws {
        try withDefaults { defaults in
            var date = Date(timeIntervalSince1970: 1_788_696_000)
            let store = GameStore(defaults: defaults, now: { date })
            quiet(store)
            store.claimDaily()
            let first = store.progress.points
            store.claimDaily()
            XCTAssertEqual(store.progress.points, first)
            let restored = GameStore(defaults: defaults, now: { date })
            XCTAssertFalse(restored.canClaimDaily)
            XCTAssertEqual(restored.currentStreak, 1)
            date = Calendar.current.date(byAdding: .day, value: 1, to: date)!
            restored.claimDaily()
            XCTAssertEqual(restored.currentStreak, 2)
            XCTAssertGreaterThan(restored.progress.points, first)
            date = Calendar.current.date(byAdding: .day, value: 2, to: date)!
            restored.claimDaily()
            XCTAssertEqual(restored.currentStreak, 1)
        }
    }

    func testDuelCannotGrantRewardsOrOverwriteSoloRun() throws {
        try withDefaults { defaults in
            let store = GameStore(defaults: defaults)
            quiet(store)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let solo = store.run
            store.openDuel(seed: 1, id: "test-duel")
            XCTAssertNil(store.rewardRequest(.hint))
            XCTAssertNil(store.rewardRequest(.skip))
            for direction in store.run.level.solution { store.move(direction) }
            XCTAssertTrue(store.run.isComplete)
            XCTAssertEqual(store.progress.points, 0)
            XCTAssertEqual(store.progress.completedLevels, 0)
            store.endSpecialSession()
            XCTAssertEqual(store.run, solo)
            XCTAssertEqual(GameStore(defaults: defaults).run, solo)
        }
    }

    func testMidnightTickRefreshesDailyClaimWithoutNavigation() throws {
        try withDefaults { defaults in
            let calendar = Calendar.current
            let midnight = try XCTUnwrap(calendar.date(byAdding: .day, value: 1,
                to: calendar.startOfDay(for: Date(timeIntervalSince1970: 1_788_696_000))))
            var date = midnight.addingTimeInterval(-1)
            let store = GameStore(defaults: defaults, now: { date }, uptime: { 0 })
            quiet(store)
            store.claimDaily()
            let oldDay = store.dailyChallenge.id
            let solo = store.run
            let balance = store.progress.points
            XCTAssertFalse(store.canClaimDaily)

            date = midnight.addingTimeInterval(1)
            store.tick()
            XCTAssertNotEqual(store.dailyChallenge.id, oldDay)
            XCTAssertTrue(store.canClaimDaily)
            XCTAssertEqual(store.run, solo, "Refreshing the calendar must not replace an ordinary solo run")
            XCTAssertEqual(store.progress.points, balance)
            store.claimDaily()
            XCTAssertEqual(store.currentStreak, 2)
            XCTAssertEqual(store.progress.points, balance + 30)
            store.tick()
            store.claimDaily()
            XCTAssertEqual(store.progress.points, balance + 30)
        }
    }

    func testMidnightSwipeRetiresDailyWithoutMovingRestoredSoloRun() throws {
        try withDefaults { defaults in
            let calendar = Calendar.current
            let midnight = try XCTUnwrap(calendar.date(byAdding: .day, value: 1,
                to: calendar.startOfDay(for: Date(timeIntervalSince1970: 1_788_696_000))))
            var date = midnight.addingTimeInterval(-1)
            let store = GameStore(defaults: defaults, now: { date }, uptime: { 0 })
            quiet(store)
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let solo = store.run
            let soloClock = store.clock
            let legalSoloDirection = try XCTUnwrap(solo.hintDirection)
            store.openDaily()
            let expiredRunID = store.runID
            let expiredDaily = store.dailyChallenge
            let staleReward = try XCTUnwrap(store.rewardRequest(.extraMoves))

            date = midnight.addingTimeInterval(1)
            store.move(legalSoloDirection)
            XCTAssertFalse(store.isDaily)
            XCTAssertNotEqual(store.runID, expiredRunID)
            XCTAssertNotEqual(store.dailyChallenge.id, expiredDaily.id)
            XCTAssertEqual(store.run, solo, "A swipe intended for the retired daily must not move the restored maze")
            XCTAssertEqual(store.clock, soloClock)
            XCTAssertNotNil(store.notice)
            XCTAssertEqual(store.progress.points, 0)
            XCTAssertFalse(store.progress.hasCompletedDailyChallenge(expiredDaily))
            store.applyReward(staleReward)
            XCTAssertEqual(store.run, solo)

            store.tick() // Calendar refresh -> special-session exit -> save must not recurse.
            XCTAssertEqual(store.run, solo)
            let restored = GameStore(defaults: defaults, now: { date }, uptime: { 0 })
            XCTAssertFalse(restored.isDaily)
            XCTAssertEqual(restored.run, solo)
            XCTAssertEqual(restored.dailyChallenge.id, store.dailyChallenge.id)
        }
    }

    func testMidnightRewardRequestCannotTargetReplacementSoloMaze() throws {
        try withDefaults { defaults in
            let calendar = Calendar.current
            let midnight = try XCTUnwrap(calendar.date(byAdding: .day, value: 1,
                to: calendar.startOfDay(for: Date(timeIntervalSince1970: 1_788_696_000))))
            var date = midnight.addingTimeInterval(-1)
            let store = GameStore(defaults: defaults, now: { date }, uptime: { 0 })
            quiet(store)
            let solo = store.run
            store.openDaily()
            date = midnight.addingTimeInterval(1)

            XCTAssertNil(store.rewardRequest(.hint), "The daily hint button must not start an ad for a different replacement maze")
            XCTAssertFalse(store.isDaily)
            XCTAssertEqual(store.run, solo)
            XCTAssertNil(store.hint)
            XCTAssertNotNil(store.notice)
        }
    }

    func testVersionOneProgressAndPartialRunMigrateWithoutDataLoss() throws {
        try withDefaults { defaults in
            let oldProgress = Data("""
            {"points":450,"endlessLevel":8,"challengeLevel":3,"ownedSkinIDs":["coral","mint"],"selectedSkinID":"mint","hapticsEnabled":false,"soundEnabled":false,"completedLevels":9,"rewardedLevelKeys":["endless:1"],"bonusLevelKeys":["endless:1"]}
            """.utf8)
            var oldRun = MazeRun(level: .generate(number: 8, mode: .endless))
            _ = oldRun.move(try XCTUnwrap(oldRun.hintDirection))
            var runJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(oldRun)) as? [String: Any])
            runJSON.removeValue(forKey: "extraMovesGranted")
            var levelJSON = try XCTUnwrap(runJSON["level"] as? [String: Any])
            levelJSON.removeValue(forKey: "timeLimit")
            levelJSON.removeValue(forKey: "coinCells")
            runJSON["level"] = levelJSON
            defaults.set(oldProgress, forKey: "prism.progress")
            defaults.set(try JSONSerialization.data(withJSONObject: ["endless": runJSON]), forKey: "prism.runs")
            defaults.set("endless", forKey: "prism.mode")
            let store = GameStore(defaults: defaults)
            XCTAssertEqual(store.progress.points, 450)
            XCTAssertEqual(store.progress.completedLevels, 9)
            XCTAssertEqual(store.progress.endlessLevel, 8)
            XCTAssertEqual(store.progress.timedLevel, 1)
            XCTAssertEqual(store.skin.id, "mint")
            XCTAssertEqual(store.run.position, oldRun.position)
            XCTAssertEqual(store.run.painted, oldRun.painted)
            XCTAssertEqual(store.run.extraMovesGranted, 0)
            store.setSound(false) // Persist the migrated snapshot.
            XCTAssertNotNil(defaults.data(forKey: "prism.snapshot.v2"))
            let restored = GameStore(defaults: defaults)
            XCTAssertEqual(restored.progress, store.progress)
            XCTAssertEqual(restored.run, store.run)
        }
    }

    private func quiet(_ store: GameStore) { store.setHaptics(false); store.setSound(false) }

    private func withAsyncDefaults(_ body: (UserDefaults) async throws -> Void) async throws {
        let suite = "PrismRoll.OptimalHintCompatibility.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try await body(defaults)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameLifecycleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
#endif
