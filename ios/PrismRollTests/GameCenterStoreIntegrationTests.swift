#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameCenterStoreIntegrationTests: XCTestCase {
    func testGamesLaunchRestartsFailedTimeRushAndRestoresSoloAfterDaily() throws {
        let suite = "GameCenterActivity.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var uptime: TimeInterval = 0
        let store = GameStore(defaults: defaults, uptime: { uptime },
                              completionVerifier: { _ in .undetermined }, optimalHintSolver: { _, _, _ in nil })
        let solo = store.run
        store.openGameCenterActivity(.daily)
        XCTAssertTrue(store.isDaily)
        store.openGameCenterActivity(.classic)
        XCTAssertFalse(store.isDaily)
        XCTAssertEqual(store.run, solo)
        store.openGameCenterActivity(.timeRush)
        store.move(try XCTUnwrap(store.run.level.solution.first))
        uptime = 100_000
        store.tick()
        XCTAssertTrue(store.isFailed)
        store.openGameCenterActivity(.timeRush)
        XCTAssertFalse(store.isFailed)
        XCTAssertEqual(store.timeRushMazeNumber, 1)
        XCTAssertEqual(store.run.moves, 0)
        XCTAssertEqual(store.gameCenterProgress.rushCompleted, 0)
    }

    func testCompletedMazeUpdatesSavedReportingSnapshotAndRestoresIt() throws {
        let suite = "GameCenterStore.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = GameStore(defaults: defaults, completionVerifier: { _ in .undetermined },
                              optimalHintSolver: { _, _, _ in nil })
        let route = store.run.level.solution
        for move in route { store.move(move) }
        XCTAssertTrue(store.run.isComplete)
        XCTAssertEqual(store.gameCenterProgress.classicCompleted, 1)
        let restored = GameStore(defaults: defaults, completionVerifier: { _ in .undetermined },
                                 optimalHintSolver: { _, _, _ in nil })
        XCTAssertEqual(restored.gameCenterProgress, store.gameCenterProgress)
        store.replay()
        for move in route { store.move(move) }
        XCTAssertEqual(store.gameCenterProgress.classicCompleted, 1)
    }

    func testFailedSaveCannotPublishCompletedScore() throws {
        let suite = "GameCenterFailedSave.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory.appending(path: suite)
        let corrupt = Data("preserve corrupt save evidence".utf8)
        try corrupt.write(to: url)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: url)
        }
        let store = GameStore(defaults: defaults, progressFileURL: url,
                              completionVerifier: { _ in .undetermined }, optimalHintSolver: { _, _, _ in nil })
        for move in store.run.level.solution { store.move(move) }
        XCTAssertTrue(store.run.isComplete)
        XCTAssertEqual(store.gameCenterProgress, .empty)
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }
}
#endif
