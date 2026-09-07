import Foundation
import XCTest
@testable import PrismRoll

final class SwipeSequenceTests: XCTestCase {
    func testShortFlickAtLiftOffEmitsWithoutAnIntermediateMoveSample() {
        for distance: CGFloat in [8, 9, 10, 11] {
            var sequence = SwipeSequence<Int>()
            XCTAssertTrue(sequence.begin(1, at: .zero))
            XCTAssertEqual(sequence.end(1, at: CGPoint(x: distance, y: 1)), .right)
            XCTAssertTrue(sequence.hasEmitted)
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testSubthresholdTravelDoesNotBecomeAMoveAtLiftOff() {
        for point in [CGPoint(x: 7.99, y: 0), CGPoint(x: 0, y: -7.99),
                      CGPoint(x: 5.6, y: 5.6), CGPoint(x: -5.6, y: -5.6)] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertNil(sequence.end(1, at: point))
            XCTAssertFalse(sequence.hasEmitted)
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testFastOverlappingStrokeSurvivesFirstFingerLift() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
        // The next thumb starts before the previous thumb has left the screen.
        XCTAssertTrue(sequence.begin(2, at: CGPoint(x: 100, y: 100)))
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 40, y: 0)))
        XCTAssertTrue(sequence.hasActiveContacts)
        XCTAssertEqual(sequence.end(2, at: CGPoint(x: 100, y: 91)), .up)
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testHeldFingerDoesNotRepeatOrCancelSeveralNewStrokes() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
        for contact in 2 ... 101 {
            XCTAssertTrue(sequence.begin(contact, at: .zero))
            XCTAssertEqual(sequence.direction(for: contact, at: CGPoint(x: 0, y: -8)), .up)
            XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: -100, y: 100)))
            XCTAssertNil(sequence.end(contact, at: CGPoint(x: 0, y: -40)))
        }
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 100, y: 0)))
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testOverlappingFingerIsTrackedBeforeFirstDirectionIsKnown() {
        var sequence = SwipeSequence<Int>()
        XCTAssertTrue(sequence.begin(1, at: .zero))
        XCTAssertTrue(sequence.begin(2, at: CGPoint(x: 100, y: 100)))
        XCTAssertEqual(sequence.direction(for: 2, at: CGPoint(x: 100, y: 80)), .up)
        XCTAssertNil(sequence.end(2, at: CGPoint(x: 100, y: 70)))
        XCTAssertTrue(sequence.contains(1))
        XCTAssertEqual(sequence.end(1, at: CGPoint(x: -8, y: 0)), .left)
    }

    func testFastAngledFlicksResolveAtLiftOffAcrossTheWholeCircle() {
        for degrees in 0..<360 {
            let angle = Double(degrees) * .pi / 180
            let point = CGPoint(x: cos(angle) * 9, y: sin(angle) * 9)
            let expected: MoveDirection = abs(point.x) > abs(point.y)
                ? (point.x > 0 ? .right : .left) : (point.y > 0 ? .down : .up)
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.end(1, at: point), expected, "Dropped flick at \(degrees) degrees")
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testDiagonalWaitsForClarityButCannotDisappearAtLiftOff() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 11, y: 12)))
        XCTAssertEqual(sequence.end(1, at: CGPoint(x: 11, y: 12)), .down)
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 11, y: 12)))
    }

    func testShortAngledFlickUsesTravelDistanceRatherThanAnAxisAlignedSquare() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 7, y: 4)), .right)
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 7, y: 4)))
    }

    func testUnrecognizedHeldContactAndCancelledContactDoNotBlockFreshFlicks() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.begin(2, at: .zero)
        sequence.cancel(2)
        for contact in 3..<103 {
            XCTAssertTrue(sequence.begin(contact, at: .zero))
            XCTAssertEqual(sequence.end(contact, at: CGPoint(x: 0, y: -9)), .up)
        }
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 1, y: 1)))
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testRapidSequentialStrokesHaveNoCooldownAndKeepEveryDirection() {
        var sequence = SwipeSequence<Int>()
        let directions: [(CGPoint, MoveDirection)] = [
            (CGPoint(x: 8, y: 0), .right), (CGPoint(x: 0, y: -8), .up),
            (CGPoint(x: -8, y: 0), .left), (CGPoint(x: 0, y: 8), .down)
        ]
        for contact in 0 ..< 1_000 {
            let (point, direction) = directions[contact % directions.count]
            XCTAssertTrue(sequence.begin(contact, at: .zero))
            XCTAssertEqual(sequence.end(contact, at: point), direction)
        }
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testCoalescedHistoryPreservesEarlyClearDirectionBeforeLatestSampleTurnsDiagonal() {
        let points = [CGPoint(x: 3, y: 0), CGPoint(x: 8, y: 1), CGPoint(x: 20, y: 20)]
        var latestOnly = SwipeStroke(origin: .zero)
        XCTAssertNil(latestOnly.direction(at: points.last!))

        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        let directions = points.compactMap { sequence.direction(for: 1, at: $0) }
        XCTAssertEqual(directions, [.right])
        XCTAssertNil(sequence.end(1, at: points.last!))
    }

    func testCancellationDoesNotDiscardAnotherActiveStroke() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
        sequence.begin(2, at: .zero)
        sequence.cancel(1)
        XCTAssertTrue(sequence.hasActiveContacts)
        XCTAssertEqual(sequence.end(2, at: CGPoint(x: 0, y: 8)), .down)
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testCancelledAndResetContactsCannotEmitLaterSamples() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.cancel(1)
        XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 100, y: 0)))
        XCTAssertFalse(sequence.hasEmitted)
        sequence.begin(2, at: .zero)
        sequence = SwipeSequence()
        XCTAssertNil(sequence.end(2, at: CGPoint(x: 0, y: 100)))
        XCTAssertFalse(sequence.hasEmitted)
        XCTAssertTrue(sequence.begin(3, at: .zero))
        XCTAssertEqual(sequence.end(3, at: CGPoint(x: 0, y: -8)), .up)
    }
}
