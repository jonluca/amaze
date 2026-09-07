#if canImport(UIKit) && canImport(CoreHaptics)
import Foundation
import XCTest
@testable import PrismRoll

final class HapticEngineWorkerTests: XCTestCase {
    private enum Failure: Error { case simulated }

    /// The harness accesses these fakes only on the injected worker queue.
    private final class Hardware: MazeHapticHardware, @unchecked Sendable {
        var calls: [String] = []
        var interruption: (@Sendable () -> Void)?
        var starts: [@Sendable (Error?) -> Void] = []
        var prepareFails = false
        var rollFails = false
        var stopFails = false

        func setInterruptionHandler(_ handler: @escaping @Sendable () -> Void) { interruption = handler }
        func start(completion: @escaping @Sendable (Error?) -> Void) {
            calls.append("start")
            starts.append(completion)
        }
        func preparePlayers() throws {
            calls.append("prepare")
            if prepareFails { throw Failure.simulated }
        }
        func startRolling() throws {
            calls.append("roll")
            if rollFails { throw Failure.simulated }
        }
        func stopRolling() throws {
            calls.append("idle")
            if stopFails { throw Failure.simulated }
        }
        func playCompletion() throws { calls.append("completion") }
        func stopPlayers() throws { calls.append("stop") }
        func shutdown() { calls.append("shutdown") }
        func completeStart(error: Error? = nil) { starts.removeFirst()(error) }
    }

    private final class Factory: @unchecked Sendable {
        let devices = (0..<4).map { _ in Hardware() }
        var creations = 0
        var creationFails = false
        var availability: [MazeHapticAvailability] = []
        var interruptions = 0

        func make() throws -> any MazeHapticHardware {
            let index = creations
            creations += 1
            if creationFails { throw Failure.simulated }
            return devices[min(index, devices.count - 1)]
        }
    }

    private final class Harness: @unchecked Sendable {
        let queue: DispatchQueue
        let factory: Factory
        let worker: MazeHapticEngineWorker
        let sessionID = UUID()

        init() {
            let queue = DispatchQueue(label: "prismroll.haptics.tests")
            let factory = Factory()
            self.queue = queue
            self.factory = factory
            worker = MazeHapticEngineWorker(queue: queue, makeHardware: { try factory.make() }, uptime: { 100 })
            worker.setHandlers(availability: { _, state in factory.availability.append(state) },
                               interruption: { _ in factory.interruptions += 1 })
        }

        func onQueue<Value: Sendable>(_ operation: @escaping @Sendable (Factory) -> Value) async -> Value {
            await withCheckedContinuation { continuation in
                queue.async { continuation.resume(returning: operation(self.factory)) }
            }
        }

        func drain() async { await onQueue { _ in () } }
        func ready() async {
            worker.prepare(sessionID: sessionID)
            await onQueue { $0.devices[0].completeStart() }
            await drain()
        }

        deinit { worker.shutdown() }
    }

    func testColdShortRollFinishesBeforeEngineStartWithoutLatePlayback() async {
        let h = Harness()
        h.worker.prepare(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        h.worker.setRolling(false, sessionID: h.sessionID)
        await h.onQueue { $0.devices[0].completeStart() }
        await h.drain()
        let calls = await h.onQueue { $0.devices[0].calls }
        XCTAssertEqual(calls, ["start", "prepare"])
        h.worker.setRolling(true, sessionID: h.sessionID)
        let nextCalls = await h.onQueue { $0.devices[0].calls }
        XCTAssertEqual(nextCalls.last, "roll", "The prepared engine must serve the next short roll immediately")
    }

    func testWarmEngineAndPlayersAreReusedAcrossIdleFramesAndRunResets() async {
        let h = Harness()
        await h.ready()
        for _ in 0..<20 {
            h.worker.setRolling(true, sessionID: h.sessionID)
            h.worker.setRolling(false, sessionID: h.sessionID)
        }
        h.worker.stop(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        let result = await h.onQueue { ($0.creations, $0.devices[0].calls) }
        XCTAssertEqual(result.0, 1)
        XCTAssertEqual(result.1.filter { $0 == "start" }.count, 1)
        XCTAssertEqual(result.1.filter { $0 == "prepare" }.count, 1)
        XCTAssertEqual(result.1.filter { $0 == "roll" }.count, 21)
        XCTAssertFalse(result.1.contains("shutdown"))
    }

    func testFailedStartPublishesUnavailableAndRetriesOnlyOnNextRollingInterval() async {
        let h = Harness()
        h.worker.prepare(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        await h.onQueue { $0.devices[0].completeStart(error: Failure.simulated) }
        await h.drain()
        for _ in 0..<120 { h.worker.setRolling(true, sessionID: h.sessionID) }
        let failed = await h.onQueue { ($0.creations, $0.availability.last, $0.devices[0].calls) }
        XCTAssertEqual(failed.0, 1)
        XCTAssertEqual(failed.1, .unavailable)
        XCTAssertEqual(failed.2.last, "shutdown")
        h.worker.setRolling(false, sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        await h.onQueue { $0.devices[1].completeStart() }
        await h.drain()
        let recovered = await h.onQueue { ($0.creations, $0.devices[1].calls) }
        XCTAssertEqual(recovered.0, 2)
        XCTAssertEqual(recovered.1, ["start", "prepare", "roll"])
    }

    func testPlayerPreparationFailureIsReportedAndDoesNotPretendToRoll() async {
        let h = Harness()
        await h.onQueue { $0.devices[0].prepareFails = true }
        h.worker.prepare(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        await h.onQueue { $0.devices[0].completeStart() }
        await h.drain()
        let result = await h.onQueue { ($0.availability.last, $0.devices[0].calls) }
        XCTAssertEqual(result.0, .unavailable)
        XCTAssertEqual(result.1, ["start", "prepare", "shutdown"])
    }

    func testPatternStartFailureCannotCausePerFrameEngineCreation() async {
        let h = Harness()
        await h.ready()
        await h.onQueue { $0.devices[0].rollFails = true }
        for _ in 0..<120 { h.worker.setRolling(true, sessionID: h.sessionID) }
        let result = await h.onQueue { ($0.creations, $0.availability.last, $0.devices[0].calls) }
        XCTAssertEqual(result.0, 1)
        XCTAssertEqual(result.1, .unavailable)
        XCTAssertEqual(result.2.suffix(2), ["roll", "shutdown"])
    }

    func testSuspensionReleasesHardwareAndRejectsLateStartFromPreviousSession() async {
        let h = Harness()
        h.worker.prepare(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        h.worker.suspend(sessionID: h.sessionID)
        let nextSession = UUID()
        h.worker.prepare(sessionID: nextSession)
        h.worker.setRolling(true, sessionID: nextSession)
        await h.onQueue {
            $0.devices[0].completeStart()
            $0.devices[1].completeStart()
        }
        await h.drain()
        h.worker.setRolling(false, sessionID: h.sessionID)
        let result = await h.onQueue { ($0.devices[0].calls, $0.devices[1].calls) }
        XCTAssertEqual(result.0, ["start", "shutdown"])
        XCTAssertEqual(result.1, ["start", "prepare", "roll"])
    }

    func testResetCancelsPendingFeedbackWhileKeepingPreparedHardware() async {
        let h = Harness()
        h.worker.prepare(sessionID: h.sessionID)
        h.worker.setRolling(true, sessionID: h.sessionID)
        h.worker.stop(sessionID: h.sessionID)
        await h.onQueue { $0.devices[0].completeStart() }
        await h.drain()
        let before = await h.onQueue { $0.devices[0].calls }
        XCTAssertEqual(before, ["start", "stop", "prepare"])
        h.worker.setRolling(true, sessionID: h.sessionID)
        let after = await h.onQueue { ($0.creations, $0.devices[0].calls.last) }
        XCTAssertEqual(after.0, 1)
        XCTAssertEqual(after.1, "roll")
    }

    func testDelayedInterruptionFromRetiredHardwareCannotStopNewRoll() async {
        let h = Harness()
        await h.ready()
        h.worker.setRolling(true, sessionID: h.sessionID)
        await h.onQueue { $0.devices[0].interruption?() }
        await h.drain()
        h.worker.setRolling(true, sessionID: h.sessionID)
        await h.onQueue { $0.devices[1].completeStart() }
        await h.drain()
        await h.onQueue { $0.devices[0].interruption?() }
        await h.drain()
        let result = await h.onQueue { ($0.interruptions, $0.devices[1].calls) }
        XCTAssertEqual(result.0, 1)
        XCTAssertEqual(result.1, ["start", "prepare", "roll"])
    }

    func testEngineCreationFailureIsVisibleAndDoesNotSpin() async {
        let h = Harness()
        await h.onQueue { $0.creationFails = true }
        h.worker.prepare(sessionID: h.sessionID)
        for _ in 0..<120 { h.worker.setRolling(true, sessionID: h.sessionID) }
        let result = await h.onQueue { ($0.creations, $0.availability.last) }
        XCTAssertEqual(result.0, 2, "One preparation attempt and one fresh roll attempt")
        XCTAssertEqual(result.1, .unavailable)
    }

    func testFailedStopShutsDownHardwareInsteadOfOrphaningContinuousLoop() async {
        let h = Harness()
        await h.ready()
        await h.onQueue { $0.devices[0].stopFails = true }
        h.worker.setRolling(true, sessionID: h.sessionID)
        h.worker.setRolling(false, sessionID: h.sessionID)
        let result = await h.onQueue { ($0.availability.last, $0.devices[0].calls) }
        XCTAssertEqual(result.0, .unavailable)
        XCTAssertEqual(result.1.suffix(3), ["roll", "idle", "shutdown"])
    }
}
#endif
