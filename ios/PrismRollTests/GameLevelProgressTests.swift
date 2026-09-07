#if canImport(UIKit)
import XCTest
import Combine
@testable import PrismRoll

@MainActor
final class GameLevelProgressTests: XCTestCase {
    func testOptimalCompletionPersistsAndReplayCannotFarmCoins() async throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults)
        try complete(store)
        let moves = store.run.moves
        XCTAssertEqual(store.progress.bestMoves(number: 1, mode: .endless), moves)
        let result = await store.completedRunOptimality(for: store.runID)
        XCTAssertEqual(result, .optimal)
        XCTAssertTrue(store.progress.hasOptimalCompletion(number: 1, mode: .endless))

        let restored = makeStore(defaults)
        XCTAssertTrue(restored.progress.hasOptimalCompletion(number: 1, mode: .endless))
        XCTAssertEqual(restored.progress.bestMoves(number: 1, mode: .endless), moves)
        restored.openLevel(1)
        try complete(restored)
        _ = await restored.completedRunOptimality(for: restored.runID)
        XCTAssertEqual(restored.progress.points, 50)
        XCTAssertEqual(restored.progress.completedLevels, 1)
    }

    func testNonoptimalSolveGetsCheckmarkAndReplayCanEarnCrown() async throws {
        let store = makeStore(try makeDefaults())
        let first = try XCTUnwrap(store.run.hintDirection)
        let reverse: MoveDirection
        switch first {
        case .up: reverse = .down
        case .down: reverse = .up
        case .left: reverse = .right
        case .right: reverse = .left
        }
        store.move(first)
        store.move(reverse)
        store.move(first)
        try complete(store)
        let slowerMoves = store.run.moves
        let result = await store.completedRunOptimality(for: store.runID)
        XCTAssertEqual(result, .notOptimal)
        XCTAssertTrue(store.progress.hasCompleted(number: 1, mode: .endless))
        XCTAssertFalse(store.progress.hasOptimalCompletion(number: 1, mode: .endless))
        store.replay()
        try complete(store)
        _ = await store.completedRunOptimality(for: store.runID)
        XCTAssertEqual(store.progress.bestMoves(number: 1, mode: .endless), store.run.moves)
        XCTAssertLessThan(store.run.moves, slowerMoves)
        XCTAssertTrue(store.progress.hasOptimalCompletion(number: 1, mode: .endless))
        XCTAssertEqual(store.progress.points, 50)
    }

    func testSwitchingModesBeforeVerificationFinishesSavesOriginalLevel() async throws {
        let defaults = try makeDefaults()
        let store = makeStore(defaults)
        let crowned = expectation(description: "Original level crown saved after navigation")
        let observation = store.$progress.first { $0.hasOptimalCompletion(number: 1, mode: .endless) }
            .sink { _ in crowned.fulfill() }
        try complete(store)
        store.switchMode(.challenge)
        await fulfillment(of: [crowned], timeout: 5)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(store.mode, .challenge)
        XCTAssertFalse(store.progress.hasCompleted(number: 1, mode: .challenge))
        XCTAssertNil(store.progress.bestMoves(number: 1, mode: .challenge))
        XCTAssertTrue(makeStore(defaults).progress.hasOptimalCompletion(number: 1, mode: .endless))
    }

    func testSpecialMazesAndSkippedLevelsDoNotEarnCatalogRecords() async throws {
        let store = makeStore(try makeDefaults())
        store.openDuel(seed: 1, id: "catalog-test")
        try complete(store)
        _ = await store.completedRunOptimality(for: store.runID)
        XCTAssertFalse(store.progress.hasCompleted(number: 1, mode: .endless))
        XCTAssertNil(store.progress.bestMoves(number: 1, mode: .endless))
        store.endSpecialSession()
        store.applyReward(try XCTUnwrap(store.rewardRequest(.skip)))
        XCTAssertEqual(store.run.level.number, 2)
        XCTAssertFalse(store.progress.hasCompleted(number: 1, mode: .endless))
        XCTAssertFalse(store.progress.hasOptimalCompletion(number: 1, mode: .endless))
    }

    func testLegacyGridRefreshPreservesWalletLedgerAndOtherMatchingRun() throws {
        let defaults = try makeDefaults()
        var progress = ProgressData()
        progress.completeLevel(.generate(number: 1, mode: .endless))
        progress.points = 987
        progress.ownedSkinIDs.append("mint")
        let canonical = MazeLevel.generate(number: 10, mode: .endless)
        let old = MazeLevel(number: 10, mode: .endless, width: 2, height: 1,
                            openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)],
                            start: GridCell(row: 0, column: 0), solution: [.right], moveLimit: nil)
        var matching = MazeRun(level: .generate(number: 1, mode: .challenge))
        matching.move(try XCTUnwrap(matching.hintDirection))
        let snapshot = GameSnapshot(progress: progress, runs: ["endless": MazeRun(level: old), "challenge": matching],
                                    clocks: [:], mode: .endless, dailyRun: nil, dailyID: nil,
                                    dailyActive: false, themeID: "aurora")
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.run, MazeRun(level: canonical))
        XCTAssertEqual(store.progress, progress)
        store.switchMode(.challenge)
        XCTAssertEqual(store.run, matching)
        store.switchMode(.endless)
        XCTAssertEqual(store.run.level, canonical)
        XCTAssertEqual(GameStore(defaults: defaults).run.level, canonical)
    }

    func testLegacyTimeRushGridRefreshesWholeCourseAndRetainsEarnedTime() throws {
        let defaults = try makeDefaults()
        let course = TimeRushCourse.generate(number: 1)
        let wrong = MazeLevel(number: 1, mode: .timed, width: 2, height: 1,
                             openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)],
                             start: GridCell(row: 0, column: 0), solution: [.right], moveLimit: nil)
        var levels = course.levels
        levels[2] = wrong
        let session = TimeRushSession(course: TimeRushCourse(number: 1, levels: levels, timeLimit: course.timeLimit), stageIndex: 2)
        let snapshot = GameSnapshot(progress: ProgressData(), runs: ["timed": MazeRun(level: wrong)],
                                    clocks: ["timed": TimedRunState(remainingSeconds: 10, hasStarted: true, rewardedExtensions: 2)],
                                    mode: .timed, dailyRun: nil, dailyID: nil, dailyActive: false,
                                    themeID: "aurora", timeRushSession: session)
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.timeRushSession, TimeRushSession(course: course))
        XCTAssertEqual(store.run, MazeRun(level: course.levels[0]))
        XCTAssertEqual(store.clock?.remainingSeconds, course.timeLimit + 60)
        XCTAssertEqual(store.clock?.rewardedExtensions, 2)
        XCTAssertEqual(store.clock?.hasStarted, false)
    }

    func testLegacyLimitedMovesRefreshKeepsEarnedExtraMoves() throws {
        let defaults = try makeDefaults()
        let wrong = MazeLevel(number: 1, mode: .challenge, width: 2, height: 1,
                             openCells: [GridCell(row: 0, column: 0), GridCell(row: 0, column: 1)],
                             start: GridCell(row: 0, column: 0), solution: [.right], moveLimit: 3)
        var saved = MazeRun(level: wrong)
        saved.grantExtraMoves(count: 6)
        let snapshot = GameSnapshot(progress: ProgressData(), runs: ["challenge": saved], clocks: [:],
                                    mode: .challenge, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora")
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
        let store = GameStore(defaults: defaults)
        XCTAssertEqual(store.run.level, .generate(number: 1, mode: .challenge))
        XCTAssertEqual(store.run.extraMovesGranted, 6)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suite = "PrismRoll.GameLevelProgressTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }

    private func makeStore(_ defaults: UserDefaults) -> GameStore {
        let store = GameStore(defaults: defaults, uptime: { 0 })
        store.setHaptics(false)
        store.setSound(false)
        return store
    }

    private func complete(_ store: GameStore) throws {
        for _ in 0..<500 {
            if store.run.isComplete { return }
            store.move(try XCTUnwrap(store.run.hintDirection))
        }
        XCTFail("Maze did not complete within its hint route")
    }
}
#endif
