#if canImport(UIKit)
import Combine
import XCTest
@testable import PrismRoll

@MainActor
final class GameCoachingTests: XCTestCase {
    func testIntroductoryHintsAreLimitedToTheUnfinishedFirstClassicMaze() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            XCTAssertTrue(store.offersIntroductoryHints)
            XCTAssertTrue(store.showsTutorial)
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertFalse(store.hasEnded)
            XCTAssertTrue(store.offersIntroductoryHints, "A first move must not remove the introductory hint allowance")

            for mode in [GameMode.timed, .challenge] {
                store.switchMode(mode)
                XCTAssertFalse(store.offersIntroductoryHints)
                XCTAssertFalse(store.showsTutorial)
            }
            store.switchMode(.endless)
            XCTAssertTrue(store.offersIntroductoryHints)
            store.openDaily()
            XCTAssertFalse(store.offersIntroductoryHints)
            XCTAssertFalse(store.showsTutorial)
            store.endSpecialSession()
            XCTAssertTrue(store.offersIntroductoryHints)
            store.openDuel(seed: 1, id: "coaching-scope")
            XCTAssertEqual(store.run.level.number, 1)
            XCTAssertFalse(store.offersIntroductoryHints, "A Duel generated from Classic level one is still competitive play")
            XCTAssertFalse(store.showsTutorial)
        }
    }

    func testCompletedFirstClassicMazeDoesNotRegainIntroductoryHintsOnReplay() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            complete(store)
            XCTAssertFalse(store.offersIntroductoryHints)
            XCTAssertFalse(store.showsTutorial)
            store.replay()
            XCTAssertEqual(store.run.level.number, 1)
            XCTAssertFalse(store.hasEnded)
            XCTAssertFalse(store.offersIntroductoryHints, "The completion ledger must prevent replay from renewing free introductory hints")
            XCTAssertFalse(store.showsTutorial)
            store.nextLevel()
            XCTAssertEqual(store.run.level.number, 2)
            XCTAssertFalse(store.offersIntroductoryHints)
            XCTAssertFalse(store.showsTutorial)
            let restored = makeStore(defaults: defaults)
            restored.openLevel(1)
            XCTAssertFalse(restored.offersIntroductoryHints)
            XCTAssertFalse(restored.showsTutorial)
        }
    }

    func testCompletingOtherModesDoesNotConsumeFirstClassicCoaching() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            for mode in [GameMode.challenge, .timed] {
                store.switchMode(mode)
                complete(store)
            }
            XCTAssertEqual(store.progress.completedLevels, 2)
            store.switchMode(.endless)
            XCTAssertEqual(store.run.level.number, 1)
            XCTAssertTrue(store.offersIntroductoryHints)
            XCTAssertTrue(store.showsTutorial)
        }
    }

    func testDismissingTutorialPersistsWithoutRemovingFreeHintsOrChangingTheRun() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            let before = store.run
            store.dismissTutorial()
            XCTAssertTrue(store.progress.tutorialDismissed)
            XCTAssertFalse(store.showsTutorial)
            XCTAssertTrue(store.offersIntroductoryHints)
            XCTAssertEqual(store.run, before)
            XCTAssertEqual(store.progress.points, 0)

            let restored = makeStore(defaults: defaults)
            XCTAssertFalse(restored.showsTutorial)
            XCTAssertTrue(restored.offersIntroductoryHints)
            restored.showHint()
            XCTAssertEqual(restored.hint, try XCTUnwrap(before.hintDirection))
            XCTAssertEqual(restored.run, before)
            XCTAssertEqual(restored.progress.points, 0)
        }
    }

    func testDirectionButtonPreferencePersistsBothWaysWithoutDismissingCoaching() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            XCTAssertFalse(store.progress.directionButtonsEnabled)
            store.setDirectionButtons(true)
            let enabled = makeStore(defaults: defaults)
            XCTAssertTrue(enabled.progress.directionButtonsEnabled)
            XCTAssertFalse(enabled.progress.tutorialDismissed)
            XCTAssertTrue(enabled.showsTutorial)
            enabled.setDirectionButtons(false)
            let disabled = makeStore(defaults: defaults)
            XCTAssertFalse(disabled.progress.directionButtonsEnabled)
            XCTAssertFalse(disabled.progress.tutorialDismissed)
            XCTAssertEqual(disabled.run, store.run)
            XCTAssertEqual(disabled.progress.points, store.progress.points)
        }
    }

    func testBlockedDirectionsGiveFeedbackWithoutMovesClockEventsOrCoins() throws {
        try withDefaults { defaults in
            var uptime = 0.0
            let store = makeStore(defaults: defaults, uptime: { uptime })
            var events: [GameMoveEvent] = []
            let subscription = store.moveEvents.sink { events.append($0) }
            defer { subscription.cancel() }
            for mode in GameMode.allCases {
                store.switchMode(mode)
                let blocked = try blockedDirection(in: store)
                let before = store.run
                let clock = store.clock
                let coins = store.progress.points
                for _ in 0..<3 { store.move(blocked, for: store.inputID) }
                uptime += 100
                store.tick()
                XCTAssertEqual(store.blockedDirection, blocked)
                XCTAssertEqual(store.run, before)
                XCTAssertEqual(store.run.moves, 0)
                XCTAssertEqual(store.clock, clock)
                XCTAssertFalse(store.clock?.hasStarted == true)
                XCTAssertFalse(store.clockRunning)
                XCTAssertEqual(store.progress.points, coins)
                XCTAssertTrue(events.isEmpty)
            }
        }
    }

    func testSuccessfulMoveHintAndReplayClearBlockedFeedback() throws {
        try withDefaults { defaults in
            let store = makeStore(defaults: defaults)
            let initialBlocked = try blockedDirection(in: store)
            store.move(initialBlocked)
            XCTAssertEqual(store.blockedDirection, initialBlocked)
            store.showHint()
            XCTAssertNil(store.blockedDirection)
            XCTAssertNotNil(store.hint)

            store.move(initialBlocked)
            XCTAssertEqual(store.blockedDirection, initialBlocked)
            store.move(try XCTUnwrap(store.run.hintDirection))
            XCTAssertEqual(store.run.moves, 1)
            XCTAssertNil(store.blockedDirection)
            XCTAssertNil(store.hint)

            let nextBlocked = try blockedDirection(in: store)
            store.move(nextBlocked)
            XCTAssertEqual(store.blockedDirection, nextBlocked)
            store.replay()
            XCTAssertNil(store.blockedDirection)
            XCTAssertEqual(store.run.moves, 0)
        }
    }

    func testStaleAndPausedInputsCannotSetBlockedFeedback() throws {
        for gate in 0..<5 {
            try withDefaults { defaults in
                let store = makeStore(defaults: defaults)
                let blocked = try blockedDirection(in: store)
                let previousRunInput = store.inputID
                store.replay()
                store.move(blocked, for: previousRunInput)
                XCTAssertNil(store.blockedDirection, "A stale run must not produce feedback on its replacement")
                let beforePause = store.inputID
                switch gate {
                case 0: store.setActivity(modal: true)
                case 1: store.setActivity(active: false)
                case 2: store.setActivity(visible: false)
                case 3: store.beginReward()
                default: store.setPresentationReady(false, for: store.runID)
                }
                XCTAssertFalse(store.acceptsGameplayInput)
                store.move(blocked, for: store.inputID)
                XCTAssertNil(store.blockedDirection, "Current-session input is still rejected while gate \(gate) is closed")
                switch gate {
                case 0: store.setActivity(modal: false)
                case 1: store.setActivity(active: true)
                case 2: store.setActivity(visible: true)
                case 3: store.finishReward()
                default: store.setPresentationReady(true, for: store.runID)
                }
                XCTAssertTrue(store.acceptsGameplayInput)
                store.move(blocked, for: beforePause)
                XCTAssertNil(store.blockedDirection, "A pre-pause touch must not produce feedback after resuming")
                XCTAssertEqual(store.run.moves, 0)
                store.move(blocked, for: store.inputID)
                XCTAssertEqual(store.blockedDirection, blocked, "Fresh active input still gives useful blocked-direction feedback")
            }
        }
    }

    private func blockedDirection(in store: GameStore) throws -> MoveDirection {
        try XCTUnwrap(MoveDirection.allCases.first {
            MazeSolver.path(from: store.run.position, direction: $0, in: store.run.level.openCells).isEmpty
        })
    }

    private func complete(_ store: GameStore, file: StaticString = #filePath, line: UInt = #line) {
        let mazeCount = store.isTimeRush ? store.timeRushMazeCount : 1
        for index in 0..<mazeCount {
            for direction in store.run.level.solution { store.move(direction) }
            XCTAssertTrue(store.run.isComplete, file: file, line: line)
            if index < mazeCount - 1 {
                XCTAssertTrue(store.advanceTimeRushMaze(after: store.runID), file: file, line: line)
            }
        }
        XCTAssertTrue(store.hasEnded, file: file, line: line)
    }

    private func makeStore(defaults: UserDefaults, uptime: @escaping () -> TimeInterval = { 0 }) -> GameStore {
        let store = GameStore(defaults: defaults, now: { Date(timeIntervalSince1970: 1_788_696_000) }, uptime: uptime)
        store.setHaptics(false)
        store.setSound(false)
        return store
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameCoachingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
#endif
