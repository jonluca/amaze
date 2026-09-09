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
        XCTAssertEqual(store.completedRunOptimalityIfReady(for: store.runID), .optimal)
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

    func testPendingProofAllowsNextLevelAndSavesItsCrownLater() async throws {
        let defaults = try makeDefaults()
        let proof = AsyncStream<MazeOptimality.Result>.makeStream()
        defer { proof.continuation.finish() }
        let store = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in
            for await result in proof.stream { return result }
            return .undetermined
        })
        store.setHaptics(false)
        store.setSound(false)
        let crowned = expectation(description: "Delayed proof crowns the original level")
        let observation = store.$progress.first { $0.hasOptimalCompletion(number: 1, mode: .endless) }
            .sink { _ in crowned.fulfill() }
        try complete(store)
        let completedRunID = store.runID
        XCTAssertNil(store.completedRunOptimalityIfReady(for: completedRunID))
        XCTAssertTrue(store.advanceCompletedLevel(for: completedRunID))
        XCTAssertEqual(store.run.level.number, 2)
        XCTAssertFalse(store.progress.hasOptimalCompletion(number: 1, mode: .endless))

        proof.continuation.yield(.optimal)
        await fulfillment(of: [crowned], timeout: 5)
        withExtendedLifetime(observation) {}
        XCTAssertNil(store.completedRunOptimalityIfReady(for: completedRunID))
        XCTAssertNil(store.completedRunOptimalityIfReady(for: store.runID))
        XCTAssertTrue(makeStore(defaults).progress.hasOptimalCompletion(number: 1, mode: .endless))
    }

    func testPendingProofAllowsNextTimeRushMaze() throws {
        let proof = AsyncStream<MazeOptimality.Result>.makeStream()
        defer { proof.continuation.finish() }
        let store = GameStore(defaults: try makeDefaults(), uptime: { 0 }, completionVerifier: { _ in
            for await result in proof.stream { return result }
            return .undetermined
        })
        store.setHaptics(false)
        store.setSound(false)
        store.switchMode(.timed)
        try complete(store)
        let completedRunID = store.runID
        let remainingSeconds = store.clock?.remainingSeconds
        XCTAssertNil(store.completedRunOptimalityIfReady(for: completedRunID))
        XCTAssertTrue(store.advanceTimeRushMaze(after: completedRunID))
        XCTAssertEqual(store.timeRushMazeNumber, 2)
        XCTAssertEqual(store.clock?.remainingSeconds, remainingSeconds)
        proof.continuation.yield(.optimal)
    }

    func testStoreDeallocationCancelsProofsFromEveryCompletedLevel() async throws {
        let started = expectation(description: "Both completion proofs started")
        started.expectedFulfillmentCount = 2
        let cancelled = expectation(description: "Both owned proofs cancelled")
        cancelled.expectedFulfillmentCount = 2
        var store: GameStore? = GameStore(defaults: try makeDefaults(), uptime: { 0 }, completionVerifier: { _ in
            // Each proof owns its wait; cancelling one must not finish the other.
            let proof = AsyncStream<MazeOptimality.Result>.makeStream()
            defer { proof.continuation.finish() }
            started.fulfill()
            return await withTaskCancellationHandler {
                for await result in proof.stream { return result }
                return .undetermined
            } onCancel: {
                cancelled.fulfill()
            }
        })
        store?.setHaptics(false)
        store?.setSound(false)
        try complete(try XCTUnwrap(store))
        XCTAssertTrue(store!.advanceCompletedLevel(for: store!.runID))
        try complete(try XCTUnwrap(store))
        await fulfillment(of: [started], timeout: 5)
        weak var releasedStore = store
        store = nil
        XCTAssertNil(releasedStore, "Pending proofs must not retain the game store")
        await fulfillment(of: [cancelled], timeout: 5)
    }

    func testPendingCrownResumesAfterAdvancingAndRestoringStore() async throws {
        let defaults = try makeDefaults()
        let started = expectation(description: "Original proof started")
        let proof = AsyncStream<MazeOptimality.Result>.makeStream()
        defer { proof.continuation.finish() }
        var original: GameStore? = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in
            started.fulfill()
            for await result in proof.stream { return result }
            return .undetermined
        })
        original?.setHaptics(false)
        original?.setSound(false)
        try complete(try XCTUnwrap(original))
        XCTAssertTrue(original!.advanceCompletedLevel(for: original!.runID))
        await fulfillment(of: [started], timeout: 5)
        XCTAssertEqual(try snapshot(defaults).pendingCompletions?.count, 1)
        weak var released = original
        original = nil
        XCTAssertNil(released)

        let resumed = expectation(description: "Original board proof resumed")
        let restored = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { run in
            XCTAssertEqual(run.level.number, 1)
            XCTAssertEqual(run.moves, 8)
            resumed.fulfill()
            return .optimal
        })
        let crowned = expectation(description: "Restored proof awarded the original crown")
        let observation = restored.$progress.first { $0.hasOptimalCompletion(number: 1, mode: .endless) }
            .sink { _ in crowned.fulfill() }
        await fulfillment(of: [resumed, crowned], timeout: 5)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(restored.run.level.number, 2)
        XCTAssertEqual(restored.run.moves, 0)
        XCTAssertNil(restored.completedRunOptimalityIfReady(for: restored.runID))
        XCTAssertNil(try snapshot(defaults).pendingCompletions)
        XCTAssertEqual(restored.progress.points, 50)
    }

    func testRestoredCompletedRunSharesItsPendingProofAndRetriesFailure() async throws {
        let defaults = try makeDefaults()
        var original: GameStore? = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in .undetermined })
        original?.setHaptics(false)
        original?.setSound(false)
        try complete(try XCTUnwrap(original))
        let failed = await original!.completedRunOptimality(for: original!.runID)
        XCTAssertEqual(failed, .undetermined)
        XCTAssertEqual(try snapshot(defaults).pendingCompletions?.count, 1)
        original = nil

        let resumed = expectation(description: "Only one resumed verification runs")
        resumed.assertForOverFulfill = true
        let restored = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in
            resumed.fulfill()
            return .optimal
        })
        let result = await restored.completedRunOptimality(for: restored.runID)
        await fulfillment(of: [resumed], timeout: 5)
        XCTAssertEqual(result, .optimal)
        XCTAssertEqual(restored.completedRunOptimalityIfReady(for: restored.runID), .optimal)
        XCTAssertTrue(restored.progress.hasOptimalCompletion(number: 1, mode: .endless))
        XCTAssertNil(try snapshot(defaults).pendingCompletions)
    }

    func testLeavingSpecialSessionCancelsItsUnsavedProof() async throws {
        for daily in [false, true] {
            let defaults = try makeDefaults()
            let started = expectation(description: "Special proof started")
            let cancelled = expectation(description: "Special proof cancelled on navigation")
            let proof = AsyncStream<MazeOptimality.Result>.makeStream()
            defer { proof.continuation.finish() }
            let store = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in
                started.fulfill()
                return await withTaskCancellationHandler {
                    for await result in proof.stream { return result }
                    return .undetermined
                } onCancel: {
                    cancelled.fulfill()
                }
            })
            store.setHaptics(false)
            store.setSound(false)
            if daily { store.openDaily() }
            else { store.openDuel(seed: 1, id: "cancel-proof") }
            try complete(store)
            await fulfillment(of: [started], timeout: 5)
            store.endSpecialSession()
            await fulfillment(of: [cancelled], timeout: 5)
            XCTAssertNil(try snapshot(defaults).pendingCompletions)
            XCTAssertFalse(store.progress.hasOptimalCompletion(number: 1, mode: .endless))
        }
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

    private func snapshot(_ defaults: UserDefaults) throws -> GameSnapshot {
        try JSONDecoder().decode(GameSnapshot.self, from: XCTUnwrap(defaults.data(forKey: "prism.snapshot.v2")))
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
