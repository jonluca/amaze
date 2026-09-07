#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameNavigationTests: XCTestCase {
    func testJourneyResumesEveryModeWithoutLosingMovesPaintOrRewards() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            for mode in GameMode.allCases {
                store.switchMode(mode)
                store.move(try XCTUnwrap(store.run.hintDirection))
                let before = store.run
                let balance = store.progress.points
                let oldInputID = store.inputID
                let oldRunID = store.runID
                let staleHint = try XCTUnwrap(store.rewardRequest(.hint))

                store.openLevel(before.level.number)

                XCTAssertEqual(store.run, before)
                XCTAssertEqual(store.progress.points, balance)
                XCTAssertNotEqual(store.inputID, oldInputID)
                XCTAssertNotEqual(store.runID, oldRunID)
                store.move(try XCTUnwrap(before.hintDirection), for: oldInputID)
                store.applyReward(staleHint)
                XCTAssertEqual(store.run, before, "A previous screen's touch must not move the resumed maze")
                XCTAssertNil(store.hint)
            }
        }
    }

    func testJourneyKeepsExactTimerAndEarnedExtensionAcrossRelaunch() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults: defaults, uptime: { uptime })
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            store.applyReward(try XCTUnwrap(store.rewardRequest(.extraTime)))
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            uptime += 2.25
            store.setActivity(visible: false)
            let savedRun = store.run
            let savedClock = try XCTUnwrap(store.clock)
            XCTAssertEqual(savedClock.remainingSeconds, initial - 2.25, accuracy: 0.001)

            uptime += 1_000
            store.openLevel(savedRun.level.number)
            XCTAssertEqual(store.run, savedRun)
            XCTAssertEqual(store.clock, savedClock)

            let restored = makeStore(defaults: defaults, uptime: { uptime })
            restored.openLevel(savedRun.level.number)
            XCTAssertEqual(restored.run, savedRun)
            XCTAssertEqual(restored.clock, savedClock)
            XCTAssertEqual(restored.clock?.rewardedExtensions, 1)
            uptime += 1
            restored.tick()
            XCTAssertEqual(try XCTUnwrap(restored.clock?.remainingSeconds), savedClock.remainingSeconds - 1, accuracy: 0.001)
        }
    }

    func testJourneyResumesFailedTimerInsteadOfGivingFreeTime() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults: defaults, uptime: { uptime })
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            uptime += 1_000
            store.tick()
            let failedRun = store.run
            XCTAssertTrue(store.isFailed)

            store.openLevel(failedRun.level.number)
            XCTAssertEqual(store.run, failedRun)
            XCTAssertEqual(store.clock?.remainingSeconds, 0)
            XCTAssertTrue(store.isFailed)
            store.replay()
            XCTAssertFalse(store.isFailed)
            XCTAssertEqual(store.run.moves, 0)
        }
    }

    func testJourneyCanRestoreSoloFromDailyAndPreserveBothRuns() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            store.switchMode(.challenge)
            store.move(try XCTUnwrap(store.run.hintDirection))
            store.applyReward(try XCTUnwrap(store.rewardRequest(.extraMoves)))
            let solo = store.run
            store.openDaily()
            store.move(try XCTUnwrap(store.run.hintDirection))
            let daily = store.run

            store.openLevel(solo.level.number)
            XCTAssertFalse(store.isDaily)
            XCTAssertEqual(store.run, solo)
            store.openDaily(replayCompleted: true)
            XCTAssertTrue(store.isDaily)
            XCTAssertEqual(store.run, daily, "Replay intent must retain an unfinished daily")
            let restored = makeStore(defaults: defaults)
            XCTAssertEqual(restored.run, daily)
            restored.endSpecialSession()
            XCTAssertEqual(restored.run, solo)
        }
    }

    func testJourneyFromDuelRestoresSoloWithoutSavingDuelAsProgress() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let solo = store.run
            store.openDuel(seed: 500, id: "navigation-test")
            store.move(try XCTUnwrap(store.run.hintDirection))

            store.openLevel(solo.level.number)
            XCTAssertFalse(store.isDuel)
            XCTAssertEqual(store.run, solo)
            XCTAssertEqual(makeStore(defaults: defaults).run, solo)
            XCTAssertEqual(store.progress.completedLevels, 0)
        }
    }

    func testCompletedJourneyLevelStartsFreshReplayWithoutAnotherAward() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            complete(store)
            let level = store.run.level
            let balance = store.progress.points

            store.openLevel(level.number)
            XCTAssertEqual(store.run, MazeRun(level: level))
            XCTAssertFalse(store.hasEnded)
            complete(store)
            XCTAssertEqual(store.progress.points, balance)
            XCTAssertEqual(store.progress.completedLevels, 1)
            XCTAssertEqual(store.earnedPoints, 0)
        }
    }

    func testCompletedDailyReplaysAfterRelaunchWithoutDuplicatePrize() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            store.openDaily()
            complete(store)
            let daily = store.dailyChallenge
            let balance = store.progress.points
            XCTAssertEqual(balance, daily.reward)

            let restored = makeStore(defaults: defaults)
            XCTAssertTrue(restored.run.isComplete)
            restored.openDaily(replayCompleted: true)
            XCTAssertTrue(restored.isDaily)
            XCTAssertEqual(restored.run, MazeRun(level: daily.level))
            XCTAssertFalse(restored.hasEnded)
            XCTAssertEqual(restored.earnedPoints, 0)
            XCTAssertTrue(restored.progress.hasCompletedDailyChallenge(daily))
            complete(restored)
            XCTAssertEqual(restored.progress.points, balance)
            XCTAssertEqual(restored.earnedPoints, 0)
            XCTAssertEqual(restored.progress.dailyChallengeStreak, 1)
            XCTAssertEqual(restored.progress.completedLevels, 0)
        }
    }

    func testSkinSelectionAndPurchaseUseEquippedStateWithoutSuccessAlert() throws {
        try withDefaults { defaults in
            var progress = ProgressData()
            let skin = try XCTUnwrap(BallSkin.catalog.first { $0.price > 0 })
            progress.points = skin.price
            defaults.set(try JSONEncoder().encode(progress), forKey: "prism.progress")
            let store = makeStore(defaults: defaults)
            store.selectSkin(skin)
            XCTAssertEqual(store.skin.id, skin.id)
            XCTAssertEqual(store.progress.points, 0)
            XCTAssertNil(store.notice)
            store.selectSkin(skin)
            XCTAssertEqual(store.progress.points, 0)
            XCTAssertNil(store.notice)
            XCTAssertEqual(makeStore(defaults: defaults).skin.id, skin.id)

            let other = try XCTUnwrap(BallSkin.catalog.first { $0.price > 0 && $0.id != skin.id })
            store.selectSkin(other)
            XCTAssertEqual(store.skin.id, skin.id)
            XCTAssertNotNil(store.notice)
        }
    }

    func testSceneLoadingPausesCountdownAndRejectsInputUntilFirstFrame() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults: defaults, uptime: { uptime })
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            let before = store.run
            let oldInput = store.inputID
            uptime += 1.25
            store.setPresentationReady(false, for: store.runID)
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 1.25, accuracy: 0.001)
            XCTAssertFalse(store.clockRunning)
            XCTAssertFalse(store.acceptsGameplayInput)

            uptime += 120
            store.tick()
            store.move(try XCTUnwrap(before.hintDirection))
            XCTAssertEqual(store.run, before)
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 1.25, accuracy: 0.001)
            store.setPresentationReady(true, for: store.runID)
            XCTAssertTrue(store.clockRunning)
            store.move(try XCTUnwrap(before.hintDirection), for: oldInput)
            XCTAssertEqual(store.run, before)
            uptime += 0.75
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 2, accuracy: 0.001)
        }
    }

    func testTrackedNavigationWaitsForNewSceneAndRejectsPreviousReadiness() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults: defaults, uptime: { uptime })
            store.setPresentationReady(true, for: store.runID)
            let initialRunID = store.runID
            store.switchMode(.timed)
            XCTAssertFalse(store.acceptsGameplayInput)
            store.setPresentationReady(true, for: initialRunID)
            XCTAssertFalse(store.acceptsGameplayInput)
            store.setPresentationReady(true, for: store.runID)
            store.move(try XCTUnwrap(store.run.hintDirection))
            let timed = store.run
            let timedRunID = store.runID
            let initial = try XCTUnwrap(store.clock?.remainingSeconds)
            store.switchMode(.endless)
            store.setPresentationReady(true, for: store.runID)
            store.switchMode(.timed)
            uptime += 120
            store.tick()
            XCTAssertEqual(store.run, timed)
            XCTAssertEqual(store.clock?.remainingSeconds, initial)
            XCTAssertFalse(store.clockRunning)
            store.setPresentationReady(true, for: timedRunID)
            XCTAssertFalse(store.clockRunning, "A previous presentation cannot resume this clock")
            store.setPresentationReady(true, for: store.runID)
            XCTAssertTrue(store.clockRunning)
            store.setPresentationReady(false, for: timedRunID)
            XCTAssertTrue(store.clockRunning, "A dismantled old presentation cannot pause the current clock")
            uptime += 1
            store.tick()
            XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), initial - 1, accuracy: 0.001)

            store.replay()
            XCTAssertFalse(store.acceptsGameplayInput)
            store.setPresentationReady(true, for: store.runID)
            XCTAssertTrue(store.acceptsGameplayInput)
            XCTAssertFalse(store.clockRunning, "A fresh maze still waits for its first move")
        }
    }

    private func complete(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
        for direction in store.run.level.solution { store.move(direction) }
        XCTAssertTrue(store.run.isComplete, file: file, line: line)
    }

    private func makeStore(defaults: UserDefaults, uptime: @escaping () -> TimeInterval = { 0 }) -> GameStore {
        let store = GameStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_788_696_000) }, uptime: uptime)
        store.setHaptics(false)
        store.setSound(false)
        return store
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameNavigationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
#endif
