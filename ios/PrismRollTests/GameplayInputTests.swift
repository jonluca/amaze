#if canImport(UIKit)
import Combine
import XCTest
@testable import PrismRoll

@MainActor
final class GameplayInputTests: XCTestCase {
    func testRapidMovesDeliverEveryTurnSynchronouslyWithoutDisplayUpdates() throws {
        for isDuel in [false, true] {
            try withStore { store, defaults in
                if isDuel { store.openDuel(seed: 100, id: "input-test") }
                let forward = try XCTUnwrap(store.run.hintDirection)
                let backward: MoveDirection
                switch forward {
                case .up: backward = .down
                case .down: backward = .up
                case .left: backward = .right
                case .right: backward = .left
                }
                var expected = store.run
                var events: [GameMoveEvent] = []
                let subscription = store.moveEvents.sink { events.append($0) }
                defer { subscription.cancel() }
                let session = store.inputID
                var milliseconds: [Double] = []
                for index in 0..<300 {
                    let direction = index.isMultiple(of: 2) ? forward : backward
                    let start = expected.position
                    let path = expected.move(direction)
                    XCTAssertFalse(path.isEmpty)
                    let began = ProcessInfo.processInfo.systemUptime
                    store.move(direction, for: session)
                    milliseconds.append((ProcessInfo.processInfo.systemUptime - began) * 1_000)
                    XCTAssertEqual(events.count, index + 1, "No run-loop turn is required for delivery")
                    let event = try XCTUnwrap(events.last)
                    XCTAssertEqual(event.runID, store.runID)
                    XCTAssertEqual(event.moves, index + 1)
                    XCTAssertEqual(event.start, start)
                    XCTAssertEqual(event.path, path)
                    XCTAssertEqual(event.position, expected.position)
                    XCTAssertEqual(event.painted, expected.painted)
                }
                XCTAssertEqual(store.run.position, expected.position)
                XCTAssertEqual(store.run.painted, expected.painted)
                XCTAssertEqual(store.run.moves, expected.moves)
                if !isDuel { XCTAssertEqual(GameStore(defaults: defaults).run, store.run) }
                milliseconds.sort()
                print(String(format: "[InputLatency] %@: 300 synchronous moves; median %.3f ms, p95 %.3f ms, max %.3f ms (store, event delivery and persistence; excludes rendering)",
                             isDuel ? "Duel level 100" : "Classic level 1", milliseconds[150], milliseconds[284], milliseconds[299]))
            }
        }
    }

    func testBlockedSwipeDoesNotPublishAndCompletionPublishesExactlyOnce() throws {
        try withStore { store, _ in
            var events: [GameMoveEvent] = []
            let subscription = store.moveEvents.sink { events.append($0) }
            defer { subscription.cancel() }
            let blocked = try XCTUnwrap(MoveDirection.allCases.first {
                MazeSolver.path(from: store.run.position, direction: $0, in: store.run.level.openCells).isEmpty
            })
            store.move(blocked)
            XCTAssertTrue(events.isEmpty)
            for direction in store.run.level.solution { store.move(direction) }
            XCTAssertTrue(store.run.isComplete)
            XCTAssertEqual(events.count, store.run.moves)
            XCTAssertEqual(events.filter(\.isComplete).count, 1)
            let completedCount = events.count
            for direction in MoveDirection.allCases { store.move(direction) }
            XCTAssertEqual(events.count, completedCount)
        }
    }

    func testFingerFromPreviousRunOrModalCannotMoveResumedBoard() throws {
        try withStore { store, _ in
            var eventCount = 0
            let subscription = store.moveEvents.sink { _ in eventCount += 1 }
            defer { subscription.cancel() }
            let beforeReset = store.inputID
            store.replay()
            let resetRun = store.run
            let direction = try XCTUnwrap(store.run.hintDirection)
            store.move(direction, for: beforeReset)
            XCTAssertEqual(store.run, resetRun)
            XCTAssertEqual(eventCount, 0)

            let beforeModal = store.inputID
            store.setActivity(modal: true)
            store.move(direction)
            XCTAssertFalse(store.acceptsGameplayInput)
            store.setActivity(modal: false)
            store.move(direction, for: beforeModal)
            XCTAssertEqual(store.run, resetRun)
            XCTAssertEqual(eventCount, 0)
            store.move(direction, for: store.inputID)
            XCTAssertEqual(eventCount, 1)

            let beforeMode = store.inputID
            store.switchMode(.challenge)
            let challengeRun = store.run
            store.move(try XCTUnwrap(store.run.hintDirection), for: beforeMode)
            XCTAssertEqual(store.run, challengeRun)
            XCTAssertEqual(eventCount, 1)
        }
    }

    func testHiddenInactiveRewardAndNoticeSuppressInputWithoutDeferredMoves() throws {
        try withStore { store, _ in
            let untouched = store.run
            let direction = try XCTUnwrap(store.run.hintDirection)
            let beforeHide = store.inputID
            store.setActivity(visible: false)
            store.move(direction)
            store.setActivity(visible: true)
            store.move(direction, for: beforeHide)
            let beforeBackground = store.inputID
            store.setActivity(active: false)
            store.move(direction)
            store.setActivity(active: true)
            store.move(direction, for: beforeBackground)
            let beforeReward = store.inputID
            store.beginReward()
            store.move(direction)
            store.finishReward()
            store.move(direction, for: beforeReward)
            store.notice = "A modal alert"
            store.move(direction)
            XCTAssertEqual(store.run, untouched)
            store.notice = nil
            XCTAssertTrue(store.acceptsGameplayInput)
            XCTAssertEqual(store.run, untouched, "Suppressed input must never be queued for later")
            store.move(direction)
            XCTAssertEqual(store.run.moves, 1)
        }
    }

    private func withStore(_ body: (GameStore, UserDefaults) throws -> Void) throws {
        let suite = "PrismRoll.GameplayInputTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, uptime: { 0 })
        store.setHaptics(false)
        store.setSound(false)
        try body(store, defaults)
    }
}
#endif
