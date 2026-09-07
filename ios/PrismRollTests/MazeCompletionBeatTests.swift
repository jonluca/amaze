import XCTest
@testable import PrismRoll

final class MazeCompletionBeatTests: XCTestCase {
    func testCelebrationHasOneBeatPerRunAndEndsAtEveryDisplayRate() {
        for refreshRate in [30.0, 60, 80, 120] {
            var beat = MazeCompletionBeat()
            XCTAssertTrue(beat.begin())
            XCTAssertFalse(beat.begin())
            let frames = Int(ceil(MazeCompletionBeat.duration * refreshRate))
            for _ in 0..<(frames - 1) { beat.advance(by: 1 / refreshRate) }
            XCTAssertTrue(beat.isPlaying, "The final move should remain visible during the completion rhythm")
            beat.advance(by: 1 / refreshRate)
            XCTAssertFalse(beat.isPlaying)
            XCTAssertFalse(beat.begin(), "Repeated ready callbacks must not replay the completion")
        }
    }

    func testInvalidClockStepsDoNotConsumeBeatAndNewRunResetsIt() {
        var beat = MazeCompletionBeat()
        XCTAssertTrue(beat.begin())
        beat.advance(by: 0.1)
        let remaining = beat.remaining
        for interval in [0.0, -1, .nan, .infinity] { beat.advance(by: interval) }
        XCTAssertEqual(beat.remaining, remaining)
        beat = MazeCompletionBeat()
        XCTAssertFalse(beat.isPlaying)
        XCTAssertFalse(beat.hasStarted)
        XCTAssertTrue(beat.begin())
        XCTAssertEqual(beat.remaining, MazeCompletionBeat.duration)
    }
}
