#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameAnalyticsTests: XCTestCase {
    func testAcceptedPlayStartsAndCompletesOnceWithoutBlockedOrStaleInputEvents() throws {
        try withDefaults { defaults in
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder)
            XCTAssertTrue(recorder.recorded.isEmpty)
            let blocked = try XCTUnwrap(MoveDirection.allCases.first {
                MazeSolver.path(from: store.run.position, direction: $0, in: store.run.level.openCells).isEmpty
            })
            store.move(blocked)
            store.move(try XCTUnwrap(store.run.hintDirection), for: UUID())
            XCTAssertTrue(recorder.recorded.isEmpty)

            for direction in store.run.level.solution { store.move(direction) }
            store.move(.up)
            XCTAssertTrue(store.run.isComplete)
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_end").count, 1)
            XCTAssertEqual(recorder.events("level_end").first?.parameters["success"] as? Int, 1)
            XCTAssertEqual(recorder.events("level_end").first?.parameters["moves"] as? Int, store.run.moves)
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, 1)

            let restored = makeStore(defaults, analytics: recorder)
            restored.tick()
            XCTAssertEqual(recorder.events("level_end").count, 1, "Loading completed boards and proof recovery must not fabricate wins")
        }
    }

    func testModeAndRelaunchResumeDoNotCreateNewLevelStarts() throws {
        try withDefaults { defaults in
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder)
            let solution = store.run.level.solution
            XCTAssertGreaterThan(solution.count, 2)
            store.move(solution[0])
            store.switchMode(.challenge)
            store.switchMode(.endless)
            store.move(solution[1])
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_resumed").count, 1)
            XCTAssertEqual(recorder.events("mode_selected").count, 2)

            let restored = makeStore(defaults, analytics: recorder)
            restored.move(solution[2])
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_resumed").count, 2)
        }
    }

    func testDailyOpeningPlayingResumingAndRolloverKeepStartsAccurate() throws {
        try withDefaults { defaults in
            let calendar = Calendar.current
            var date = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_788_696_000)).addingTimeInterval(43_200)
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder, now: { date })
            store.openDaily()
            XCTAssertEqual(recorder.events("daily_opened").count, 1)
            XCTAssertTrue(recorder.events("level_start").isEmpty, "Opening the daily is navigation, not accepted play")
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_start").first?.parameters["play_context"] as? String, "daily")

            store.endSpecialSession()
            store.openDaily()
            XCTAssertEqual(recorder.events("daily_opened").last?.parameters["resumed"] as? Int, 1)
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertEqual(recorder.events("level_resumed").count, 1)
            XCTAssertEqual(recorder.events("level_start").count, 1)
            let restored = makeStore(defaults, analytics: recorder, now: { date })
            restored.move(try XCTUnwrap(restored.run.hintDirection))
            XCTAssertEqual(recorder.events("level_resumed").count, 2)
            XCTAssertEqual(recorder.events("level_resumed").last?.parameters["play_context"] as? String, "daily")

            date = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))
            restored.move(.up)
            XCTAssertFalse(restored.isDaily, "A rollover retires the previous daily before accepting its stale input")
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_resumed").count, 2)
            restored.openDaily()
            XCTAssertEqual(recorder.events("daily_opened").count, 3)
            XCTAssertEqual(recorder.events("daily_opened").last?.parameters["resumed"] as? Int, 0)
            XCTAssertEqual(recorder.events("level_start").count, 1)
            restored.move(try XCTUnwrap(restored.run.hintDirection))
            XCTAssertEqual(recorder.events("level_start").count, 2)
            XCTAssertTrue(recorder.events("level_start").allSatisfy { $0.parameters["play_context"] as? String == "daily" })
        }
    }

    func testMazePickupCurrencyMatchesWalletAndCannotBeEarnedAgainOnReplay() throws {
        try withDefaults { defaults in
            var progress = ProgressData()
            progress.endlessLevel = 5
            defaults.set(try JSONEncoder().encode(progress), forKey: "prism.progress")
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder)
            let level = store.run.level
            XCTAssertFalse(level.coinCells.isEmpty)
            for direction in level.solution {
                store.move(direction)
                let reportedCoins = recorder.events("earn_virtual_currency").reduce(0) {
                    $0 + ($1.parameters["value"] as? Int ?? 0)
                }
                XCTAssertEqual(reportedCoins, store.progress.points, "Every persisted pickup and completion credit must be represented")
            }
            let pickups = recorder.events("earn_virtual_currency").filter { $0.parameters["source"] as? String == "maze_pickup" }
            XCTAssertFalse(pickups.isEmpty)
            XCTAssertLessThanOrEqual(pickups.count, MazeLevel.maximumCoinCount)
            XCTAssertEqual(pickups.reduce(0) { $0 + ($1.parameters["value"] as? Int ?? 0) }, level.coinCells.count * MazeLevel.coinValue)
            let earnedEventCount = recorder.events("earn_virtual_currency").count
            let earnedBalance = store.progress.points
            store.replay()
            for direction in level.solution { store.move(direction) }
            XCTAssertEqual(store.progress.points, earnedBalance)
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, earnedEventCount)

            let restored = makeStore(defaults, analytics: recorder)
            restored.replay()
            for direction in level.solution { restored.move(direction) }
            XCTAssertEqual(restored.progress.points, earnedBalance)
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, earnedEventCount)
        }
    }

    func testTimeRushSeparatesFiveMazeCompletionsFromOneRoundWin() throws {
        try withDefaults { defaults in
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder)
            store.switchMode(.timed)
            for stage in 1...store.timeRushMazeCount {
                for direction in store.run.level.solution { store.move(direction) }
                XCTAssertEqual(recorder.events("time_rush_maze_completed").count, stage)
                if stage < store.timeRushMazeCount {
                    XCTAssertTrue(recorder.events("level_end").isEmpty)
                    XCTAssertTrue(recorder.events("earn_virtual_currency").isEmpty)
                    let completedID = store.runID
                    XCTAssertTrue(store.advanceTimeRushMaze(after: completedID))
                    XCTAssertFalse(store.advanceTimeRushMaze(after: completedID))
                }
            }
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("time_rush_maze_started").count, 5)
            XCTAssertEqual(recorder.events("level_end").count, 1)
            XCTAssertEqual(recorder.events("level_end").first?.parameters["stage_index"] as? Int, 5)
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, 1)
        }
    }

    func testTimerFailureCanReviveAndWinWithoutRepeatedFailuresOrRewards() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder, uptime: { uptime })
            store.switchMode(.timed)
            let firstSolution = store.run.level.solution
            store.move(try XCTUnwrap(firstSolution.first))
            uptime += 1_000
            store.tick()
            store.tick()
            XCTAssertEqual(recorder.events("level_failed").count, 1)
            XCTAssertEqual(recorder.events("level_failed").first?.parameters["reason"] as? String, "time_expired")
            XCTAssertTrue(recorder.events("level_end").isEmpty)

            let reward = try XCTUnwrap(store.rewardRequest(.extraTime))
            store.beginReward()
            store.applyReward(reward)
            store.applyReward(reward)
            store.finishReward()
            XCTAssertEqual(recorder.events("level_revived").count, 1)
            XCTAssertEqual(recorder.events("gameplay_reward_earned").count, 1)
            for direction in firstSolution.dropFirst() { store.move(direction) }
            while store.isAwaitingTimeRushMaze {
                XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
                for direction in store.run.level.solution { store.move(direction) }
            }
            XCTAssertTrue(store.run.isComplete)
            XCTAssertEqual(recorder.events("level_start").count, 1)
            XCTAssertEqual(recorder.events("level_end").count, 1)
        }
    }

    func testPausedTimeCannotProduceFailuresAndRestartAndSkipAreDistinct() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder, uptime: { uptime })
            store.switchMode(.timed)
            store.move(try XCTUnwrap(store.run.hintDirection))
            store.setActivity(active: false)
            uptime += 1_000
            store.setActivity(active: true)
            store.setActivity(visible: false)
            uptime += 1_000
            store.setActivity(visible: true)
            store.setActivity(modal: true)
            uptime += 1_000
            store.setActivity(modal: false)
            XCTAssertTrue(recorder.events("level_failed").isEmpty)
            store.replay()
            XCTAssertEqual(recorder.events("level_restarted").count, 1)
            let skip = try XCTUnwrap(store.rewardRequest(.skip))
            store.applyReward(skip)
            store.applyReward(skip)
            XCTAssertEqual(recorder.events("level_skipped").count, 1)
            XCTAssertEqual(store.run.level.number, 2)
            XCTAssertTrue(recorder.events("level_end").isEmpty)
        }
    }

    func testMoveLimitFailureAndRevivalRecordOnlyActualTransitions() throws {
        try withDefaults { defaults in
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder)
            store.switchMode(.challenge)
            let forward = try XCTUnwrap(store.run.hintDirection)
            let backward: MoveDirection = switch forward {
            case .up: .down
            case .down: .up
            case .left: .right
            case .right: .left
            }
            for index in 0..<100 where !store.hasEnded {
                store.move(index.isMultiple(of: 2) ? forward : backward)
            }
            XCTAssertTrue(store.isFailed)
            store.move(forward)
            store.tick()
            XCTAssertEqual(recorder.events("level_failed").count, 1)
            XCTAssertEqual(recorder.events("level_failed").first?.parameters["reason"] as? String, "move_limit")
            let reward = try XCTUnwrap(store.rewardRequest(.extraMoves))
            store.applyReward(reward)
            store.applyReward(reward)
            XCTAssertFalse(store.isFailed)
            XCTAssertEqual(recorder.events("level_revived").count, 1)
            XCTAssertEqual(recorder.events("gameplay_reward_earned").count, 1)
            XCTAssertTrue(recorder.events("level_end").isEmpty)
        }
    }

    func testCurrencyAndCollectionEventsFollowActualIdempotentCreditsAndSpending() throws {
        try withDefaults { defaults in
            let directory = FileManager.default.temporaryDirectory.appending(path: "GameAnalytics-\(UUID())")
            defer { try? FileManager.default.removeItem(at: directory) }
            let recorder = RecordingGameAnalytics()
            let store = makeStore(defaults, analytics: recorder, progressFileURL: directory.appending(path: "progress.json"))
            store.claimDaily()
            store.claimDaily()
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, 1)
            let request = try XCTUnwrap(store.beginCoinReward())
            XCTAssertEqual(store.claimCoinReward(request), GameStore.videoCoinReward)
            XCTAssertEqual(store.claimCoinReward(request), 0)
            store.finishReward()
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, 2)

            let pack = try XCTUnwrap(CoinPack.catalog.first)
            let purchase = CoinPurchase(transactionID: "not-for-analytics", productID: pack.id, quantity: 1)
            _ = try store.deliverCoinPurchase(purchase)
            _ = try store.deliverCoinPurchase(purchase)
            XCTAssertEqual(recorder.events("earn_virtual_currency").count, 3)
            let skin = try XCTUnwrap(BallSkin.catalog.first { $0.id == "mint" })
            store.selectSkin(skin)
            store.selectSkin(skin)
            XCTAssertEqual(recorder.events("spend_virtual_currency").count, 1)
            XCTAssertEqual(recorder.events("spend_virtual_currency").first?.parameters["value"] as? Int, skin.price)
            XCTAssertEqual(recorder.events("skin_unlocked").count, 1)
            XCTAssertEqual(recorder.events("skin_equipped").count, 1)
            XCTAssertFalse(recorder.recorded.contains { $0.parameters.values.contains { String(describing: $0).contains("not-for-analytics") } })
        }
    }

    private func makeStore(_ defaults: UserDefaults, analytics: RecordingGameAnalytics,
                           uptime: @escaping () -> TimeInterval = { 0 }, progressFileURL: URL? = nil,
                           now: @escaping () -> Date = Date.init) -> GameStore {
        let store = GameStore(defaults: defaults, progressFileURL: progressFileURL, now: now, uptime: uptime,
                              completionVerifier: { _ in .undetermined },
                              optimalHintSolver: { _, _, _ in nil }, analytics: analytics)
        store.setHaptics(false)
        store.setSound(false)
        return store
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameAnalyticsTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
#endif
