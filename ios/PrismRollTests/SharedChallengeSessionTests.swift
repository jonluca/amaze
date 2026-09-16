#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class SharedChallengeSessionTests: XCTestCase {
    func testSolvingLockedSharedPuzzlePreservesSoloDailyAndCurrencyAcrossRelaunch() throws {
        let suite = "SharedChallengeTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, completionVerifier: { _ in .undetermined })
        store.move(store.run.level.solution[0])
        let solo = store.run
        store.openDaily()
        store.move(store.run.level.solution[0])
        let daily = store.run
        let balance = store.progress.points
        let savedSnapshot = defaults.data(forKey: "prism.snapshot.v2")
        let challenge = try ChallengeLink.make(level: .generate(number: 100, mode: .endless), title: "A friend's maze")
        let session = SharedChallengeSession(challenge: challenge, analytics: RecordingGameAnalytics())
        for direction in session.run.level.solution { session.move(direction, for: session.runID) }
        XCTAssertTrue(session.run.isComplete)
        XCTAssertEqual(store.run, daily)
        XCTAssertEqual(store.progress.points, balance)
        XCTAssertEqual(store.currentUnlockedLevel, 1)
        XCTAssertEqual(defaults.data(forKey: "prism.snapshot.v2"), savedSnapshot)
        let restored = GameStore(defaults: defaults, completionVerifier: { _ in .undetermined })
        XCTAssertTrue(restored.isDaily)
        XCTAssertEqual(restored.run, daily)
        restored.endSpecialSession()
        XCTAssertEqual(restored.run, solo)
    }

    func testRestartRejectsAnOldGestureAndRemovesCompletion() throws {
        let challenge = try ChallengeLink.make(level: .generate(number: 1, mode: .endless), title: "A friend's maze")
        let session = SharedChallengeSession(challenge: challenge, analytics: RecordingGameAnalytics())
        let oldID = session.runID
        for direction in challenge.level.solution { session.move(direction, for: oldID) }
        XCTAssertTrue(session.run.isComplete)
        session.restart()
        session.move(challenge.level.solution[0], for: oldID)
        XCTAssertEqual(session.run.moves, 0)
        XCTAssertFalse(session.run.isComplete)
        session.move(challenge.level.solution[0], for: session.runID)
        XCTAssertEqual(session.run.moves, 1)
    }

    func testSharedPresentationPausesAndRestoresExistingTimeRushClock() throws {
        let suite = "SharedChallengeClockTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var uptime: TimeInterval = 100
        let store = GameStore(defaults: defaults, uptime: { uptime }, completionVerifier: { _ in .undetermined })
        store.switchMode(.timed)
        store.move(store.run.level.solution[0])
        let originalRun = store.run
        let remaining = try XCTUnwrap(store.clock?.remainingSeconds)
        store.setActivity(modal: true)
        let challenge = try ChallengeLink.make(level: .generate(number: 1, mode: .endless), title: "A friend's maze")
        let session = SharedChallengeSession(challenge: challenge, analytics: RecordingGameAnalytics())
        uptime += 90
        for direction in challenge.level.solution { session.move(direction, for: session.runID) }
        store.tick()
        XCTAssertEqual(store.clock?.remainingSeconds, remaining)
        XCTAssertEqual(store.run, originalRun)
        store.setActivity(modal: false)
        uptime += 1
        store.tick()
        XCTAssertEqual(try XCTUnwrap(store.clock?.remainingSeconds), remaining - 1, accuracy: 0.01)
        XCTAssertEqual(store.run, originalRun)
    }

    func testReviewStorePersistsConsumedRequestAcrossInstances() throws {
        let suite = "ReviewPromptTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        let prompts = ReviewPromptStore(defaults: defaults)
        for day in 0..<3 { prompts.recordEngagement(at: start.addingTimeInterval(Double(day) * 86_400)) }
        XCTAssertTrue(prompts.consumeRequest(completedLevels: 10, at: start.addingTimeInterval(2 * 86_400)))
        let restored = ReviewPromptStore(defaults: defaults)
        XCTAssertFalse(restored.consumeRequest(completedLevels: 50, at: start.addingTimeInterval(3 * 86_400)))
    }
}
#endif
