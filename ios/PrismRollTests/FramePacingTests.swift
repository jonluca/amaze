#if canImport(UIKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class FramePacingTests: XCTestCase {
    func testClockTracksUpcomingFramesWhenRefreshRateChanges() {
        var clock = MazeFrameClock()
        var timestamp = 100.0
        var advanced = 0.0
        for fps in [120.0, 120, 60, 80, 40, 30, 120] {
            let target = timestamp + 1 / fps
            let interval = clock.interval(timestamp: timestamp, targetTimestamp: target)
            XCTAssertEqual(interval, 1 / fps, accuracy: 0.000000001)
            advanced += interval
            timestamp = target
        }
        XCTAssertEqual(advanced, timestamp - 100, accuracy: 0.000000001)
    }

    func testResumeDoesNotConsumeTimeSpentPaused() {
        var clock = MazeFrameClock()
        _ = clock.interval(timestamp: 1, targetTimestamp: 1 + 1 / 120.0)
        clock.reset()
        XCTAssertEqual(clock.interval(timestamp: 91, targetTimestamp: 91 + 1 / 60.0),
                       1 / 60.0, accuracy: 0.000000001)
    }

    func testInvalidDuplicateAndStaleFramesCannotRewindOrPoisonClock() {
        var clock = MazeFrameClock()
        XCTAssertEqual(clock.interval(timestamp: .nan, targetTimestamp: .infinity), 0)
        XCTAssertEqual(clock.interval(timestamp: 1, targetTimestamp: 1.01), 0.01, accuracy: 0.000000001)
        XCTAssertEqual(clock.interval(timestamp: 1, targetTimestamp: 1.01), 0)
        XCTAssertEqual(clock.interval(timestamp: 0.9, targetTimestamp: 0.91), 0)
        XCTAssertEqual(clock.interval(timestamp: 1.01, targetTimestamp: .nan), 0)
        XCTAssertEqual(clock.interval(timestamp: 1.01, targetTimestamp: 1.02), 0.01, accuracy: 0.000000001)
    }

    func testFramePreferencesSupportProMotionAndStandardDisplays() {
        for maximum in [30, 60, 80, 120] {
            let range = SceneFrameRatePolicy.range(maximumFramesPerSecond: maximum)
            XCTAssertEqual(range.maximum, Float(maximum))
            XCTAssertEqual(range.preferred, Float(maximum))
            XCTAssertLessThanOrEqual(range.minimum, range.maximum)
        }
        XCTAssertEqual(SceneFrameRatePolicy.range(maximumFramesPerSecond: 240).maximum, 120)
        let view = SCNView()
        SceneFrameRatePolicy.apply(to: view)
        XCTAssertEqual(view.preferredFramesPerSecond, 120)
    }

    func testBuiltAppEnablesIPhoneHighRefreshRates() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool, true)
    }
}
#endif
