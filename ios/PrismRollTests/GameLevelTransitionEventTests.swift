#if canImport(UIKit)
import Combine
import XCTest
@testable import PrismRoll

@MainActor
final class GameLevelTransitionEventTests: XCTestCase {
    func testAutomaticSoloAdvancePublishesCompletedBoardBeforeReplacingItOnce() throws {
        try withStore { store in
            for mode in [GameMode.endless, .challenge] {
                store.switchMode(mode)
                for move in store.run.level.solution { store.move(move) }
                let completedRun = store.run
                let completedID = store.runID
                var events: [UUID] = []
                let subscription = store.levelTransitionEvents.sink { runID in
                    events.append(runID)
                    XCTAssertEqual(runID, completedID)
                    XCTAssertEqual(store.runID, completedID)
                    XCTAssertEqual(store.run, completedRun)
                    XCTAssertTrue(store.run.isComplete)
                }

                XCTAssertTrue(store.advanceCompletedLevel(for: completedID))
                XCTAssertEqual(events, [completedID])
                XCTAssertNotEqual(store.runID, completedID)
                XCTAssertFalse(store.run.isComplete)
                XCTAssertFalse(store.advanceCompletedLevel(for: completedID))
                XCTAssertEqual(events, [completedID])
                subscription.cancel()
            }
        }
    }

    func testTimeRushEntryPublishesPreviousStageAndClockBeforeMutation() throws {
        try withStore { store in
            store.switchMode(.timed)
            for move in store.run.level.solution { store.move(move) }
            let completedID = store.runID
            let completedRun = store.run
            let previousSession = store.timeRushSession
            let previousClock = store.clock
            var events: [UUID] = []
            let subscription = store.levelTransitionEvents.sink { runID in
                events.append(runID)
                XCTAssertEqual(store.runID, completedID)
                XCTAssertEqual(store.run, completedRun)
                XCTAssertEqual(store.timeRushSession, previousSession)
                XCTAssertEqual(store.clock, previousClock)
                XCTAssertTrue(store.run.isComplete)
                XCTAssertEqual(store.timeRushMazeNumber, 1)
            }
            defer { subscription.cancel() }

            XCTAssertTrue(store.advanceTimeRushMaze(after: completedID))
            XCTAssertEqual(events, [completedID])
            XCTAssertEqual(store.timeRushMazeNumber, 2)
            XCTAssertNotEqual(store.runID, completedID)
            XCTAssertFalse(store.advanceTimeRushMaze(after: completedID))
            XCTAssertFalse(store.advanceTimeRushMaze(after: store.runID))
            XCTAssertEqual(events, [completedID])
        }
    }

    func testDailyAdvancePublishesDailyBoardBeforeRestoringSoloRun() throws {
        try withStore { store in
            let soloRun = store.run
            store.openDaily()
            for move in store.run.level.solution { store.move(move) }
            let completedID = store.runID
            var events: [UUID] = []
            let subscription = store.levelTransitionEvents.sink { runID in
                events.append(runID)
                XCTAssertTrue(store.isDaily)
                XCTAssertTrue(store.run.isComplete)
                XCTAssertEqual(store.runID, runID)
            }
            defer { subscription.cancel() }

            XCTAssertTrue(store.advanceCompletedLevel(for: completedID))
            XCTAssertEqual(events, [completedID])
            XCTAssertFalse(store.isDaily)
            XCTAssertEqual(store.run, soloRun)
        }
    }

    func testManualNavigationAndInvalidCallbacksDoNotRequestEntryAnimation() throws {
        try withStore { store in
            var events: [UUID] = []
            let subscription = store.levelTransitionEvents.sink { events.append($0) }
            defer { subscription.cancel() }

            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            XCTAssertFalse(store.advanceTimeRushMaze(after: store.runID))
            for move in store.run.level.solution { store.move(move) }
            let staleID = store.runID
            store.replay()
            XCTAssertFalse(store.advanceCompletedLevel(for: staleID))
            store.switchMode(.challenge)
            store.openLevel(1)
            store.nextLevel()
            store.openDaily()
            store.endSpecialSession()
            XCTAssertTrue(events.isEmpty)
        }
    }

    func testCompletedDuelDoesNotPublishSoloTransition() throws {
        try withStore { store in
            store.openDuel(seed: 1, id: "entry-event-test")
            for move in store.run.level.solution { store.move(move) }
            var events: [UUID] = []
            let subscription = store.levelTransitionEvents.sink { events.append($0) }
            defer { subscription.cancel() }

            XCTAssertTrue(store.run.isComplete)
            XCTAssertFalse(store.advanceCompletedLevel(for: store.runID))
            XCTAssertFalse(store.advanceTimeRushMaze(after: store.runID))
            XCTAssertTrue(events.isEmpty)
        }
    }

    private func withStore(_ body: (GameStore) throws -> Void) throws {
        let suite = "PrismRoll.LevelTransitionEvents.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, uptime: { 0 })
        store.setHaptics(false)
        store.setSound(false)
        try body(store)
    }
}
#endif
