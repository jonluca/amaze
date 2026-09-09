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
            XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)))
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

    func testShortAngledFlickWaitsForLiftOffWithoutLosingTravelSensitivity() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 7, y: 4)))
        XCTAssertEqual(sequence.end(1, at: CGPoint(x: 7, y: 4)), .right)
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
        let points = [CGPoint(x: 3, y: 0), CGPoint(x: 9, y: 1), CGPoint(x: 20, y: 20)]
        var latestOnly = SwipeStroke(origin: .zero)
        XCTAssertNil(latestOnly.direction(at: points.last!))

        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        let directions = sequence.consume(points.enumerated().map {
            SwipeSample(contact: 1, point: $0.element, timestamp: Double($0.offset))
        })
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

    func testHeldFingerTurnsAtEveryCornerWithoutLifting() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
        XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 100, y: 0)))
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 100, y: 30)), .down)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 70, y: 30)), .left)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 70, y: 0)), .up)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 100, y: 0)), .right)
        XCTAssertTrue(sequence.hasActiveContacts)
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 100, y: 0)))
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testHeldFingerReversesFromItsLatestPositionAfterLongStraightTravel() {
        for sign: CGFloat in [-1, 1] {
            var horizontal = SwipeSequence<Int>()
            horizontal.begin(1, at: .zero)
            XCTAssertEqual(horizontal.direction(for: 1, at: CGPoint(x: 8 * sign, y: 0)), sign > 0 ? .right : .left)
            XCTAssertNil(horizontal.direction(for: 1, at: CGPoint(x: 1_000 * sign, y: 0)))
            XCTAssertNil(horizontal.direction(for: 1, at: CGPoint(x: 977 * sign, y: 0)))
            XCTAssertEqual(horizontal.direction(for: 1, at: CGPoint(x: 976 * sign, y: 0)), sign > 0 ? .left : .right)

            var vertical = SwipeSequence<Int>()
            vertical.begin(1, at: .zero)
            XCTAssertEqual(vertical.direction(for: 1, at: CGPoint(x: 0, y: 8 * sign)), sign > 0 ? .down : .up)
            XCTAssertNil(vertical.direction(for: 1, at: CGPoint(x: 0, y: 1_000 * sign)))
            XCTAssertNil(vertical.direction(for: 1, at: CGPoint(x: 0, y: 977 * sign)))
            XCTAssertEqual(vertical.direction(for: 1, at: CGPoint(x: 0, y: 976 * sign)), sign > 0 ? .up : .down)
        }
    }

    func testShallowCornerAccumulatesDespiteSmallForwardDrift() {
        for sign: CGFloat in [-1, 1] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
            for step in 1..<8 {
                XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 8 + CGFloat(step) * 0.1, y: CGFloat(step) * 3 * sign)))
            }
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8.8, y: 24 * sign)), sign > 0 ? .down : .up)
        }
    }

    func testDiagonalDriftDoesNotDelayTheNextDeliberateCorner() {
        for samples in [1, 10, 100] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
            XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 108, y: 96)))
            for sample in 1...samples {
                let fraction = CGFloat(sample) / CGFloat(samples)
                XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: 108 + 80 * fraction, y: 96 + 88 * fraction)))
            }
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 188, y: 214)), .down)
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 188, y: 184)), .up)
        }
    }

    func testSlowHeldTurnAccumulatesThroughSmallSidewaysJitter() {
        for sign: CGFloat in [-1, 1] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 80, y: 0)), .right)
            var directions: [MoveDirection] = []
            for step in 1...20 {
                let point = CGPoint(x: step.isMultiple(of: 2) ? 80 : 82, y: CGFloat(step) * 3 * sign)
                if let direction = sequence.direction(for: 1, at: point) { directions.append(direction) }
            }
            XCTAssertEqual(directions, [sign > 0 ? .down : .up])
            XCTAssertNil(sequence.end(1, at: CGPoint(x: 80, y: 60 * sign)))
        }
    }

    func testStraightTravelAndHeldFingerJitterNeverRepeatMoves() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
        for x in stride(from: 9, through: 100, by: 1) {
            XCTAssertNil(sequence.direction(for: 1, at: CGPoint(x: x, y: 0)))
        }
        for _ in 0..<100 {
            for point in [CGPoint(x: 100, y: 0), CGPoint(x: 97, y: -3),
                          CGPoint(x: 100, y: 3), CGPoint(x: 100, y: 0)] {
                XCTAssertNil(sequence.direction(for: 1, at: point))
            }
        }
        XCTAssertNil(sequence.end(1, at: CGPoint(x: 100, y: 0)))
    }

    func testLiftOffCannotAddAnotherDirectionAfterASwipe() {
        for point in [CGPoint(x: 8, y: 8), CGPoint(x: 8, y: 7.99),
                      CGPoint(x: 15, y: 8), CGPoint(x: 8, y: 40)] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: 8, y: 0)), .right)
            XCTAssertNil(sequence.end(1, at: point))
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testHeldFingerCoalescedTurnsFollowTimestampOrderWithoutReplayingHistory() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        let initial = SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 1)
        XCTAssertEqual(sequence.consume([initial]), [.right])
        let down = SwipeSample(contact: 1, point: CGPoint(x: 8, y: 32), timestamp: 2)
        let left = SwipeSample(contact: 1, point: CGPoint(x: -24, y: 32), timestamp: 3)
        let up = SwipeSample(contact: 1, point: CGPoint(x: -24, y: 0), timestamp: 4)
        XCTAssertEqual(sequence.consume([up, initial, left, down, down]), [.down, .left, .up])
        XCTAssertEqual(sequence.consume([down, left, up, initial]), [])
        XCTAssertEqual(sequence.consume([up, SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 5)]), [.right])
        XCTAssertEqual(sequence.consume([down, left, up], ending: true), [])
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testOverlappingHeldFingersKeepTheirTurnsInTimestampOrder() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.begin(2, at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 1),
            SwipeSample(contact: 2, point: CGPoint(x: 100, y: 108), timestamp: 2)
        ]), [.right, .down])
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 32), timestamp: 4),
            SwipeSample(contact: 2, point: CGPoint(x: 68, y: 76), timestamp: 5),
            SwipeSample(contact: 2, point: CGPoint(x: 68, y: 108), timestamp: 3)
        ]), [.left, .down, .up])
        XCTAssertNil(sequence.end(2, at: CGPoint(x: 68, y: 76)))
        XCTAssertTrue(sequence.hasActiveContacts)
        XCTAssertEqual(sequence.direction(for: 1, at: CGPoint(x: -24, y: 32)), .left)
    }

    func testEndingCoalescedHistoryPreservesMotionRecordedBeforeLiftOff() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 1)
        ]), [.right])
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 36), timestamp: 3),
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 32), timestamp: 2)
        ], ending: true), [.down])
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testUnrecognizedAngledHistoryCanStillResolveWhenReplayedAtLiftOff() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        let angled = SwipeSample(contact: 1, point: CGPoint(x: 7, y: 4), timestamp: 1)
        XCTAssertEqual(sequence.consume([angled]), [])
        XCTAssertEqual(sequence.consume([
            angled, SwipeSample(contact: 1, point: .zero, timestamp: 2)
        ], ending: true), [.right])
        XCTAssertFalse(sequence.hasActiveContacts)
    }
}
