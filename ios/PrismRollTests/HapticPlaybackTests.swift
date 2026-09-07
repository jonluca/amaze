#if canImport(UIKit) && canImport(CoreHaptics)
import CoreHaptics
import XCTest
@testable import PrismRoll

@MainActor
final class HapticPlaybackTests: XCTestCase {
    private final class RecordingOutput: MazeHapticOutput {
        var calls: [String] = []
        var onInterruption: (() -> Void)?
        func prepare() { calls.append("prepare") }
        func setRolling(_ rolling: Bool) { calls.append(rolling ? "roll" : "idle") }
        func playCompletion() { calls.append("completion") }
        func stop() { calls.append("stop") }
    }

    func testInactiveSceneCannotPrepareRollOrCelebrate() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.prepare()
        player.setRolling(true)
        player.playCompletion()
        XCTAssertTrue(output.calls.isEmpty)
    }

    func testContinuousMotionStartsOnceAndStopsOnFirstIdleFrame() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        for _ in 0..<120 { player.setRolling(true) }
        for _ in 0..<120 { player.setRolling(false) }
        XCTAssertEqual(output.calls, ["prepare", "roll", "idle"])
    }

    func testPauseStopsOutputAndDoesNotReplayItWhenResumed() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.setRolling(true)
        player.setActive(false)
        player.setRolling(true)
        player.playCompletion()
        player.setActive(true)
        XCTAssertEqual(output.calls, ["prepare", "roll", "stop", "prepare"])
        player.setRolling(true)
        XCTAssertEqual(output.calls.last, "roll", "Only current displayed motion can restart feedback")
    }

    func testDisablingHapticsCancelsCurrentAndFutureOutputUntilEnabled() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.setRolling(true)
        player.setEnabled(false)
        player.prepare()
        player.setRolling(true)
        player.playCompletion()
        XCTAssertEqual(output.calls, ["prepare", "roll", "stop"])
        player.setEnabled(true)
        XCTAssertEqual(output.calls.last, "prepare")
        XCTAssertEqual(output.calls.filter { $0 == "roll" }.count, 1)
    }

    func testCompletionStopsRollingAndPlaysOnceUntilNextRun() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.setRolling(true)
        player.playCompletion()
        for _ in 0..<120 {
            player.playCompletion()
            player.setRolling(true)
        }
        XCTAssertEqual(output.calls, ["prepare", "roll", "idle", "completion"])
        player.reset()
        player.setRolling(true)
        player.playCompletion()
        XCTAssertEqual(output.calls.suffix(4), ["stop", "roll", "idle", "completion"])
    }

    func testPauseResumeCannotRepeatCompletedRunCelebration() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.playCompletion()
        player.setActive(false)
        player.setActive(true)
        player.playCompletion()
        XCTAssertEqual(output.calls.filter { $0 == "completion" }.count, 1)
    }

    func testTeardownSilencesAndRejectsSubsequentFrameCallbacks() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.setRolling(true)
        player.stop()
        player.setRolling(true)
        player.playCompletion()
        player.prepare()
        XCTAssertEqual(output.calls, ["prepare", "roll", "stop"])
    }

    func testResetStopsAnInFlightCelebrationButKeepsSceneActive() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.playCompletion()
        player.reset()
        XCTAssertEqual(output.calls.last, "stop")
        player.setRolling(true)
        XCTAssertEqual(output.calls.last, "roll")
    }

    func testRepeatedVisibilityAndPreferenceSnapshotsDoNotPrepareAgain() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        for _ in 0..<120 {
            player.setEnabled(true)
            player.setActive(true)
        }
        XCTAssertEqual(output.calls, ["prepare"])
    }

    func testHardwareInterruptionRequiresFreshVisibleMotionToRestart() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.setRolling(true)
        output.onInterruption?()
        XCTAssertEqual(output.calls, ["prepare", "roll"])
        player.setRolling(true)
        XCTAssertEqual(output.calls, ["prepare", "roll", "roll"])
        player.setActive(false)
        output.onInterruption?()
        player.setRolling(true)
        XCTAssertEqual(output.calls.last, "stop", "Recovery cannot bypass a paused scene")
    }

    func testHardwareInterruptionCannotReplayAnInterruptedCelebration() {
        let output = RecordingOutput()
        let player = MazeHapticPlayer(output: output)
        player.setActive(true)
        player.playCompletion()
        output.onInterruption?()
        player.setRolling(true)
        player.playCompletion()
        XCTAssertEqual(output.calls, ["prepare", "idle", "completion"])
    }

    func testRollingPatternIsContinuousHapticsOnlyWithSeamlessTexture() throws {
        let pattern = try MazeHapticPatterns.rolling()
        XCTAssertEqual(pattern.duration, MazeHapticPatterns.rollingDuration, accuracy: 0.0001)
        let entries = try XCTUnwrap(try pattern.exportDictionary()[.pattern] as? [[String: Any]])
        let events = entries.compactMap { $0["Event"] as? [String: Any] }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["EventType"] as? String, "HapticContinuous")
        let curve = try XCTUnwrap(entries.compactMap { $0["ParameterCurve"] as? [String: Any] }.first)
        let points = try XCTUnwrap(curve["ParameterCurveControlPoints"] as? [[String: Any]])
        XCTAssertEqual(points.count, 9)
        XCTAssertEqual(points.first?["ParameterValue"] as? Double, points.last?["ParameterValue"] as? Double)
        XCTAssertEqual(points.first?["Time"] as? Double, 0)
        XCTAssertEqual(try XCTUnwrap(points.last?["Time"] as? Double), pattern.duration, accuracy: 0.0001)
    }

    func testCompletionPatternIsBriefRisingSequenceWithoutAudioOrLoop() throws {
        let pattern = try MazeHapticPatterns.completion()
        XCTAssertLessThanOrEqual(pattern.duration, 0.34)
        let entries = try XCTUnwrap(try pattern.exportDictionary()[.pattern] as? [[String: Any]])
        let events = entries.compactMap { $0["Event"] as? [String: Any] }
        XCTAssertEqual(events.count, 4)
        var previousIntensity = 0.0
        var previousTime = -1.0
        for event in events {
            XCTAssertEqual(event["EventType"] as? String, "HapticTransient")
            let time = try XCTUnwrap(event["Time"] as? Double)
            XCTAssertGreaterThan(time, previousTime)
            previousTime = time
            let parameters = try XCTUnwrap(event["EventParameters"] as? [[String: Any]])
            let intensity = try XCTUnwrap(parameters.first { ($0["ParameterID"] as? String) == "HapticIntensity" }?["ParameterValue"] as? Double)
            XCTAssertGreaterThan(intensity, previousIntensity)
            XCTAssertLessThanOrEqual(intensity, 1)
            previousIntensity = intensity
        }
    }
}
#endif
