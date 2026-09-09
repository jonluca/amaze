#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GameOptimalHintTests: XCTestCase {
    func testHintsAndHintAdsWaitForAProvenRoute() async throws {
        try await withStore { store, solver in
            await solver.waitForRequests(1)
            XCTAssertTrue(store.isPreparingOptimalHint)
            XCTAssertFalse(store.hasOptimalHint)
            XCTAssertNil(store.rewardRequest(.hint))

            store.showHint()
            XCTAssertTrue(store.isHintPending)
            XCTAssertNil(store.hint)
            let before = store.run
            await solver.complete(0, route: before.level.solution)
            let ready = await store.prepareOptimalHint()

            XCTAssertTrue(ready)
            XCTAssertFalse(store.isPreparingOptimalHint)
            XCTAssertFalse(store.isHintPending)
            XCTAssertEqual(store.hint, before.level.solution.first)
            XCTAssertTrue(store.run.hintIsOptimal)
            XCTAssertNotNil(store.rewardRequest(.hint))
            XCTAssertEqual(store.run.position, before.position)
            XCTAssertEqual(store.run.painted, before.painted)
            XCTAssertEqual(store.run.moves, before.moves)
            XCTAssertEqual(store.progress.points, 0)
        }
    }

    func testReplayingCancelsAndRejectsAnOldProofForTheSamePosition() async throws {
        try await withStore { store, solver in
            await solver.waitForRequests(1)
            store.showHint()
            let started = expectation(description: "Awaiting original board")
            let oldWaiter = Task {
                started.fulfill()
                return await store.prepareOptimalHint()
            }
            await fulfillment(of: [started], timeout: 1)
            let route = store.run.level.solution

            store.replay()
            await solver.waitForRequests(2)
            await solver.complete(0, route: route)
            let oldReady = await oldWaiter.value

            XCTAssertFalse(oldReady)
            XCTAssertFalse(store.hasOptimalHint)
            XCTAssertNil(store.hint)
            XCTAssertFalse(store.isHintPending)
            XCTAssertTrue(store.isPreparingOptimalHint)
            await solver.complete(1, route: route)
            let ready = await store.prepareOptimalHint()
            XCTAssertTrue(ready)
            XCTAssertNil(store.hint, "A hint requested on the old run must not appear on the replay")
        }
    }

    func testFollowingProofReusesTheSuffixAndDeviationSolvesTheCurrentPaint() async throws {
        try await withStore { store, solver in
            await solver.waitForRequests(1)
            await solver.complete(0, route: store.run.level.solution)
            let initialReady = await store.prepareOptimalHint()
            XCTAssertTrue(initialReady)
            let first = try XCTUnwrap(store.run.hintDirection)
            store.move(first)

            XCTAssertTrue(store.hasOptimalHint)
            XCTAssertFalse(store.isPreparingOptimalHint)
            let count = await solver.requestCount
            XCTAssertEqual(count, 1, "A suffix of a shortest route is already proved optimal")

            let deviation = try XCTUnwrap(MoveDirection.allCases.first {
                $0 != store.run.hintDirection
                    && !MazeSolver.path(from: store.run.position, direction: $0, in: store.run.level.openCells).isEmpty
            })
            store.move(deviation)
            XCTAssertFalse(store.hasOptimalHint)
            XCTAssertNil(store.rewardRequest(.hint))
            await solver.waitForRequests(2)
            let request = await solver.request(at: 1)
            XCTAssertEqual(request.position, store.run.position)
            XCTAssertEqual(request.painted, store.run.painted)
            let route = try XCTUnwrap(MazeSolver.coveringRoute(
                openCells: request.level.openCells, position: request.position, painted: request.painted
            ))
            await solver.complete(1, route: route)
            let ready = await store.prepareOptimalHint()
            XCTAssertTrue(ready)
        }
    }

    func testMovingBeforeAProofFinishesRejectsItsResult() async throws {
        try await withStore { store, solver in
            await solver.waitForRequests(1)
            store.showHint()
            let original = store.run
            let started = expectation(description: "Awaiting pre-move board")
            let oldWaiter = Task {
                started.fulfill()
                return await store.prepareOptimalHint()
            }
            await fulfillment(of: [started], timeout: 1)
            store.move(try XCTUnwrap(original.hintDirection))
            await solver.waitForRequests(2)
            await solver.complete(0, route: original.level.solution)
            let oldReady = await oldWaiter.value

            XCTAssertFalse(oldReady)
            XCTAssertNil(store.hint)
            XCTAssertFalse(store.hasOptimalHint)
            XCTAssertTrue(store.isPreparingOptimalHint)
            let request = await solver.request(at: 1)
            XCTAssertEqual(request.position, store.run.position)
            XCTAssertEqual(request.painted, store.run.painted)
            let route = try XCTUnwrap(MazeSolver.coveringRoute(
                openCells: request.level.openCells, position: request.position, painted: request.painted
            ))
            await solver.complete(1, route: route)
            let ready = await store.prepareOptimalHint()
            XCTAssertTrue(ready)
            XCTAssertNil(store.hint)
        }
    }

    func testUnavailableProofCannotExposeOrChargeForAnUnprovenHint() async throws {
        try await withStore { store, solver in
            await solver.waitForRequests(1)
            store.showHint()
            let started = expectation(description: "Awaiting unavailable proof")
            let waiter = Task {
                started.fulfill()
                return await store.prepareOptimalHint()
            }
            await fulfillment(of: [started], timeout: 1)
            await solver.fail(0)
            let ready = await waiter.value
            XCTAssertFalse(ready)
            XCTAssertFalse(store.hasOptimalHint)
            XCTAssertNil(store.hint)
            XCTAssertNil(store.rewardRequest(.hint))
            XCTAssertFalse(store.isHintPending)
        }
    }

    private func withStore(_ body: (GameStore, SolverGate) async throws -> Void) async throws {
        let suite = "PrismRoll.GameOptimalHintTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let solver = SolverGate()
        let store = GameStore(defaults: defaults, uptime: { 0 }, optimalHintSolver: { level, position, painted in
            await solver.solve(level: level, position: position, painted: painted)
        })
        store.setHaptics(false)
        store.setSound(false)
        try await body(store, solver)
    }

    private actor SolverGate {
        struct Request: Sendable {
            let level: MazeLevel
            let position: GridCell
            let painted: Set<GridCell>
        }

        private var requests: [Request] = []
        private var completions: [Int: CheckedContinuation<MazeNativeOptimizer.Result?, Never>] = [:]
        private var observers: [CheckedContinuation<Void, Never>] = []

        var requestCount: Int { requests.count }
        func request(at index: Int) -> Request { requests[index] }

        func solve(level: MazeLevel, position: GridCell, painted: Set<GridCell>) async -> MazeNativeOptimizer.Result? {
            await withCheckedContinuation { completion in
                completions[requests.count] = completion
                requests.append(Request(level: level, position: position, painted: painted))
                let pending = observers
                observers.removeAll()
                for observer in pending { observer.resume() }
            }
        }

        func waitForRequests(_ count: Int) async {
            while requests.count < count {
                await withCheckedContinuation { observers.append($0) }
            }
        }

        func complete(_ index: Int, route: [MoveDirection]) {
            completions.removeValue(forKey: index)?.resume(returning: .optimal(moves: route.count, route: route))
        }

        func fail(_ index: Int) {
            completions.removeValue(forKey: index)?.resume(returning: nil)
        }
    }
}
#endif
