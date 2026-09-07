#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameAutoAdvanceTests: XCTestCase {
    func testCompletedSoloModesAdvanceOnceAndKeepEarnedCoins() throws {
        try withStore { store, defaults in
            for mode in GameMode.allCases {
                store.switchMode(mode)
                let mazeCount = store.isTimeRush ? store.timeRushMazeCount : 1
                for index in 0..<mazeCount {
                    for move in store.run.level.solution { store.move(move) }
                    XCTAssertTrue(store.run.isComplete)
                    if index < mazeCount - 1 {
                        XCTAssertFalse(store.hasEnded)
                        XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID))
                    }
                }
                let completedID = store.runID
                XCTAssertTrue(store.hasEnded)
                let coins = store.progress.points
                XCTAssertTrue(store.advanceCompletedLevel(for: completedID))
                XCTAssertEqual(store.run.level.number, 2)
                XCTAssertEqual(store.run.moves, 0)
                XCTAssertFalse(store.hasEnded)
                XCTAssertEqual(store.progress.points, coins)
                XCTAssertFalse(store.advanceCompletedLevel(for: completedID))
                let restored = GameStore(defaults: defaults)
                XCTAssertEqual(restored.run, store.run)
                XCTAssertEqual(restored.progress.points, coins)
                if mode == .timed { XCTAssertFalse(store.clock?.hasStarted == true) }
            }
        }
    }

    func testIncompleteFailedAndReplacedRunsCannotBeAdvancedByOldCallbacks() throws {
        try withStore { store, _ in
            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            let previous = store.runID
            for move in store.run.level.solution { store.move(move) }
            store.replay()
            XCTAssertFalse(store.advanceCompletedLevel(for: previous))
            XCTAssertEqual(store.run.level.number, 1)
            store.switchMode(.challenge)
            let direction = try XCTUnwrap(store.run.hintDirection)
            let opposite: MoveDirection = switch direction {
            case .up: .down
            case .down: .up
            case .left: .right
            case .right: .left
            }
            for i in 0..<100 where !store.hasEnded { store.move(i.isMultiple(of: 2) ? direction : opposite) }
            XCTAssertTrue(store.isFailed)
            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            XCTAssertEqual(store.run.level.number, 1)
        }
    }

    func testDailyCompletionReturnsToSavedSoloRunAndPaysOnlyOnce() throws {
        try withStore { store, _ in
            store.move(try XCTUnwrap(store.run.hintDirection))
            let solo = store.run
            store.openDaily()
            for move in store.run.level.solution { store.move(move) }
            let coins = store.progress.points
            XCTAssertTrue(store.advanceCompletedLevel(for: store.runID))
            XCTAssertFalse(store.isDaily)
            XCTAssertEqual(store.run, solo)
            store.openDaily(replayCompleted: true)
            for move in store.run.level.solution { store.move(move) }
            XCTAssertTrue(store.advanceCompletedLevel(for: store.runID))
            XCTAssertEqual(store.progress.points, coins)
            XCTAssertEqual(store.run, solo)
        }
    }

    func testDuelWaitsForItsMatchResult() throws {
        try withStore { store, _ in
            store.openDuel(seed: 1, id: "autoadvance-test")
            for move in store.run.level.solution { store.move(move) }
            XCTAssertTrue(store.run.isComplete)
            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            XCTAssertTrue(store.isDuel)
        }
    }

    func testOptionalCompletionBonusRemainsClaimableAfterAutomaticAdvance() throws {
        try withStore { store, defaults in
            let level = store.run.level
            XCTAssertFalse(store.progress.canClaimAdBonus(number: 1, mode: .endless))
            for move in level.solution { store.move(move) }
            XCTAssertTrue(store.advanceCompletedLevel(for: store.runID))
            XCTAssertTrue(store.progress.canClaimAdBonus(number: 1, mode: .endless))
            XCTAssertFalse(store.progress.canClaimAdBonus(number: 1, mode: .challenge))
            let activeRun = store.run
            store.claimAdBonus(for: level)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertEqual(store.run, activeRun)
            XCTAssertFalse(store.progress.canClaimAdBonus(number: 1, mode: .endless))
            store.claimAdBonus(for: level)
            XCTAssertEqual(store.progress.points, 100)
            XCTAssertFalse(GameStore(defaults: defaults).progress.canClaimAdBonus(number: 1, mode: .endless))
        }
    }

    private func withStore(_ body: (GameStore, UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.AutoAdvanceTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, uptime: { 0 })
        store.setHaptics(false)
        store.setSound(false)
        try body(store, defaults)
    }
}
#endif
