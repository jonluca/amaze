import Foundation
import XCTest
@testable import PrismRoll

final class MazeStateCacheConcurrencyTests: XCTestCase {
    func testIdenticalConcurrentRequestsShareOneNativeProof() async {
        let gate = SolverGate()
        let cache = MazeMinimumMoveCache(solver: { _, _, _ in gate.solve() })
        let level = line()
        let first = Task { await cache.minimumMoves(for: level) }
        let second = Task { await cache.minimumMoves(for: level) }
        defer { first.cancel(); second.cancel(); gate.release() }
        await fulfillment(of: [gate.started], timeout: 5)
        guard await waitForWaiters(2, in: cache) else { return }
        XCTAssertEqual(gate.callCount, 1)
        gate.release()
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, 1)
        XCTAssertEqual(secondResult, 1)
        XCTAssertEqual(gate.callCount, 1)
    }

    func testCancellingOneWaiterPreservesAnotherWaitersNativeProof() async {
        let gate = SolverGate()
        let cache = MazeMinimumMoveCache(solver: { _, _, _ in gate.solve() })
        let level = line()
        let first = Task { await cache.minimumMoves(for: level) }
        let second = Task { await cache.minimumMoves(for: level) }
        defer { first.cancel(); second.cancel(); gate.release() }
        await fulfillment(of: [gate.started], timeout: 5)
        guard await waitForWaiters(2, in: cache) else { return }

        first.cancel()
        let cancelled = await first.value
        XCTAssertNil(cancelled)
        guard await waitForWaiters(1, in: cache) else { return }
        gate.release()
        let surviving = await second.value
        XCTAssertEqual(surviving, 1)
        XCTAssertEqual(gate.callCount, 1)
        let cached = await cache.cachedMinimumMoves(for: level)
        XCTAssertEqual(cached, 1)
    }

    func testCancellingLastWaiterInterruptsNativeWorkAndAllowsRetry() async {
        let probe = CancellationSolver()
        let cache = MazeMinimumMoveCache(solver: { _, _, _ in probe.solve() })
        let level = line()
        let request = Task { await cache.minimumMoves(for: level) }
        defer { request.cancel() }
        await fulfillment(of: [probe.started], timeout: 5)
        request.cancel()
        let cancelled = await request.value
        XCTAssertNil(cancelled)
        await fulfillment(of: [probe.stopped], timeout: 5)
        let missing = await cache.cachedMinimumMoves(for: level)
        XCTAssertNil(missing)
        let retried = await cache.minimumMoves(for: level)
        XCTAssertEqual(retried, 1)
        XCTAssertEqual(probe.callCount, 2)
    }

    func testOnlyTwoNativeWorkersStartAndCancelledQueuedWorkNeverRuns() async {
        let workers = ControlledWorkers()
        let cache = MazeMinimumMoveCache(solver: { level, _, _ in workers.solve(number: level.number) })
        let firstLevel = line(number: 1), secondLevel = line(number: 2), queuedLevel = line(number: 3)
        let first = Task { await cache.minimumMoves(for: firstLevel) }
        let second = Task { await cache.minimumMoves(for: secondLevel) }
        defer { first.cancel(); second.cancel(); workers.releaseAll() }
        await fulfillment(of: [workers.firstTwoStarted], timeout: 5)
        let queued = Task { await cache.minimumMoves(for: queuedLevel) }
        defer { queued.cancel() }
        guard await waitForWaiters(3, in: cache) else { return }
        XCTAssertEqual(workers.callCount, 2)
        queued.cancel()
        let cancelled = await queued.value
        XCTAssertNil(cancelled)
        workers.releaseAll()
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, 1)
        XCTAssertEqual(secondResult, 1)
        XCTAssertEqual(workers.callCount, 2)
        XCTAssertEqual(workers.maximumConcurrent, 2)
    }

    func testCancelledWorkerKeepsItsSlotUntilExitAndCannotFinishItsReplacement() async {
        let workers = ControlledWorkers()
        let cache = MazeMinimumMoveCache(solver: { level, _, _ in workers.solve(number: level.number) })
        let firstLevel = line(number: 1), secondLevel = line(number: 2)
        let first = Task { await cache.minimumMoves(for: firstLevel) }
        let second = Task { await cache.minimumMoves(for: secondLevel) }
        defer { first.cancel(); second.cancel(); workers.releaseAll() }
        await fulfillment(of: [workers.firstTwoStarted], timeout: 5)
        first.cancel()
        let cancelled = await first.value
        XCTAssertNil(cancelled)

        let replacement = Task { await cache.minimumMoves(for: firstLevel) }
        defer { replacement.cancel() }
        guard await waitForWaiters(2, in: cache) else { return }
        XCTAssertEqual(workers.callCount, 2, "Cancelling a waiter must not release a still-running native slot")
        workers.release(number: 1)
        let replaced = await replacement.value
        XCTAssertEqual(replaced, 1, "A stale cancelled worker must not finish the replacement request")
        workers.releaseAll()
        let surviving = await second.value
        XCTAssertEqual(surviving, 1)
        XCTAssertEqual(workers.callCount, 3)
        XCTAssertEqual(workers.maximumConcurrent, 2)
    }

    func testInteractiveRequestRunsBeforeQueuedBackgroundMinimum() async {
        await assertInteractivePriority(upgradeExistingRequest: false)
    }

    func testInteractiveWaiterPromotesAnExistingQueuedBackgroundMinimum() async {
        await assertInteractivePriority(upgradeExistingRequest: true)
    }

    private func assertInteractivePriority(upgradeExistingRequest: Bool) async {
        let workers = ControlledWorkers()
        let cache = MazeMinimumMoveCache(solver: { level, _, _ in workers.solve(number: level.number) })
        let levels = (1...4).map { line(number: $0) }
        let first = Task { await cache.minimumMoves(for: levels[0]) }
        let second = Task { await cache.minimumMoves(for: levels[1]) }
        defer { first.cancel(); second.cancel(); workers.releaseAll() }
        await fulfillment(of: [workers.firstTwoStarted], timeout: 5)
        let background = Task { await cache.minimumMoves(for: levels[2]) }
        defer { background.cancel() }
        guard await waitForWaiters(3, in: cache) else { return }
        let promoted = upgradeExistingRequest ? Task { await cache.minimumMoves(for: levels[3]) } : nil
        defer { promoted?.cancel() }
        if upgradeExistingRequest {
            guard await waitForWaiters(4, in: cache) else { return }
        }
        let interactive = Task {
            await cache.solution(for: levels[3], position: levels[3].start, painted: [levels[3].start])
        }
        defer { interactive.cancel() }
        guard await waitForWaiters(upgradeExistingRequest ? 5 : 4, in: cache) else { return }
        workers.release(number: 1)
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while workers.callCount < 3, clock.now < deadline { await Task.yield() }
        XCTAssertEqual(workers.startedNumbers.last, 4, "Live hints must precede queued historical target proofs")
        workers.releaseAll()
        let interactiveResult = await interactive.value
        XCTAssertEqual(interactiveResult, .optimal(moves: 1, route: [.right]))
        _ = await first.value
        _ = await second.value
        _ = await background.value
        if let promoted { _ = await promoted.value }
        XCTAssertEqual(workers.callCount, 4, "Promotion must reuse the existing queued proof")
    }

    private func waitForWaiters(_ expected: Int, in cache: MazeMinimumMoveCache) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while await cache.pendingRequestCount != expected {
            guard clock.now < deadline else {
                XCTFail("Expected \(expected) registered cache waiters")
                return false
            }
            // Synchronize on actor-owned registration, never on an assumed
            // native solve duration or a delay that guesses task scheduling.
            await Task.yield()
        }
        return true
    }

    private func line(number: Int = 1) -> MazeLevel {
        let origin = GridCell(row: 0, column: 0)
        return MazeLevel(number: number, mode: .endless, width: number + 1, height: 1,
                         openCells: [origin, GridCell(row: 0, column: 1)],
                         start: origin, solution: [], moveLimit: nil)
    }

    private final class ControlledWorkers: @unchecked Sendable {
        let firstTwoStarted: XCTestExpectation = {
            let expectation = XCTestExpectation(description: "First two native workers started")
            expectation.expectedFulfillmentCount = 2
            return expectation
        }()
        private let condition = NSCondition()
        private var calls = 0
        private var numbers: [Int] = []
        private var active = 0
        private var peak = 0
        private var released: Set<Int> = []
        private var allReleased = false

        var callCount: Int {
            condition.lock()
            defer { condition.unlock() }
            return calls
        }

        var maximumConcurrent: Int {
            condition.lock()
            defer { condition.unlock() }
            return peak
        }

        var startedNumbers: [Int] {
            condition.lock()
            defer { condition.unlock() }
            return numbers
        }

        func solve(number: Int) -> MazeNativeOptimizer.Result {
            condition.lock()
            calls += 1
            numbers.append(number)
            active += 1
            peak = max(peak, active)
            let isInitialWorker = calls <= 2
            condition.unlock()
            if isInitialWorker { firstTwoStarted.fulfill() }
            condition.lock()
            while !allReleased, !released.contains(number) { condition.wait() }
            active -= 1
            condition.unlock()
            return Task.isCancelled ? .cancelled : .optimal(moves: 1, route: [.right])
        }

        func release(number: Int) {
            condition.lock()
            released.insert(number)
            condition.broadcast()
            condition.unlock()
        }

        func releaseAll() {
            condition.lock()
            allReleased = true
            condition.broadcast()
            condition.unlock()
        }
    }

    private final class SolverGate: @unchecked Sendable {
        let started = XCTestExpectation(description: "Native proof started")
        private let condition = NSCondition()
        private var calls = 0
        private var released = false

        var callCount: Int {
            condition.lock()
            defer { condition.unlock() }
            return calls
        }

        func solve() -> MazeNativeOptimizer.Result {
            condition.lock()
            calls += 1
            condition.unlock()
            started.fulfill()
            condition.lock()
            while !released { condition.wait() }
            condition.unlock()
            return Task.isCancelled ? .cancelled : .optimal(moves: 1, route: [.right])
        }

        func release() {
            condition.lock()
            released = true
            condition.broadcast()
            condition.unlock()
        }
    }

    private final class CancellationSolver: @unchecked Sendable {
        let started = XCTestExpectation(description: "Cancellable native proof started")
        let stopped = XCTestExpectation(description: "Native proof observed cancellation")
        private let lock = NSLock()
        private var calls = 0

        var callCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }

        func solve() -> MazeNativeOptimizer.Result {
            lock.lock()
            calls += 1
            let firstCall = calls == 1
            lock.unlock()
            guard firstCall else { return .optimal(moves: 1, route: [.right]) }
            started.fulfill()
            // Stand in for synchronous native search polling its interruption
            // callback. No timed sleep controls whether cancellation succeeds.
            let clock = ContinuousClock()
            let failureDeadline = clock.now.advanced(by: .seconds(5))
            while !Task.isCancelled, clock.now < failureDeadline {}
            guard Task.isCancelled else { return .failure }
            stopped.fulfill()
            return .cancelled
        }
    }
}
