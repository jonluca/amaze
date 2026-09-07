import Foundation
import XCTest
@testable import PrismRoll

final class SwipeDirectionTests: XCTestCase {
    func testInitialThumbWobbleDoesNotLockTheWrongAxis() {
        for xSign: CGFloat in [-1, 1] {
            for ySign: CGFloat in [-1, 1] {
                for prefix in [CGPoint(x: 5, y: 7), CGPoint(x: 6, y: 7), CGPoint(x: 1, y: 8)] {
                    var horizontal = SwipeSequence<Int>()
                    horizontal.begin(1, at: .zero)
                    XCTAssertNil(horizontal.direction(for: 1, at: CGPoint(x: prefix.x * xSign, y: prefix.y * ySign)))
                    XCTAssertEqual(horizontal.direction(for: 1, at: CGPoint(x: 30 * xSign, y: 8 * ySign)), xSign > 0 ? .right : .left)
                    XCTAssertNil(horizontal.end(1, at: CGPoint(x: 40 * xSign, y: 9 * ySign)))

                    var vertical = SwipeSequence<Int>()
                    vertical.begin(1, at: .zero)
                    XCTAssertNil(vertical.direction(for: 1, at: CGPoint(x: prefix.y * xSign, y: prefix.x * ySign)))
                    XCTAssertEqual(vertical.direction(for: 1, at: CGPoint(x: 8 * xSign, y: 30 * ySign)), ySign > 0 ? .down : .up)
                    XCTAssertNil(vertical.end(1, at: CGPoint(x: 9 * xSign, y: 40 * ySign)))
                }
            }
        }
    }

    func testStraightEightPointSwipesStillStartBeforeLiftOff() {
        for (point, direction) in [(CGPoint(x: 8, y: 0), MoveDirection.right),
                                   (CGPoint(x: -8, y: 0), .left), (CGPoint(x: 0, y: 8), .down),
                                   (CGPoint(x: 0, y: -8), .up)] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.direction(for: 1, at: point), direction)
            XCTAssertNil(sequence.end(1, at: point))
        }
    }

    func testNewestClearSampleOverridesObsoletePerpendicularHistoryInTheSameEvent() {
        for sign: CGFloat in [-1, 1] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            // The obsolete vertical sample even has a larger absolute axis
            // lead (9 versus 8). Recency must win over maximum confidence.
            let samples = [SwipeSample(contact: 1, point: CGPoint(x: 0, y: 9), timestamp: 1),
                           SwipeSample(contact: 1, point: CGPoint(x: 12 * sign, y: 4), timestamp: 2)]
            XCTAssertEqual(sequence.consume(samples), [sign > 0 ? .right : .left])
            XCTAssertEqual(sequence.consume(samples, ending: true), [])
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testLiftOffUsesCompleteDisplacementBeforeHistoricalAxisLock() {
        for sign: CGFloat in [-1, 1] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: CGPoint(x: 100, y: 200))
            XCTAssertEqual(sequence.consume([
                SwipeSample(contact: 1, point: CGPoint(x: 100, y: 191), timestamp: 1),
                SwipeSample(contact: 1, point: CGPoint(x: 100 + 12 * sign, y: 189), timestamp: 2)
            ], ending: true), [sign > 0 ? .right : .left])
            XCTAssertFalse(sequence.hasActiveContacts)
        }
    }

    func testCoalescedOutAndBackDoesNotDisappear() {
        for ending in [false, true] {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            XCTAssertEqual(sequence.consume([
                SwipeSample(contact: 1, point: CGPoint(x: 0, y: -9), timestamp: 1),
                SwipeSample(contact: 1, point: CGPoint(x: 0, y: -1), timestamp: 2)
            ], ending: ending), [.up])
            XCTAssertNil(sequence.end(1, at: .zero))
        }
    }

    func testShortAngledOutAndBackResolvesAtLiftOff() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 7, y: 4), timestamp: 1),
            SwipeSample(contact: 1, point: .zero, timestamp: 2)
        ], ending: true), [.right])
        XCTAssertFalse(sequence.hasActiveContacts)
    }

    func testOverlappingContactsUseRecognitionTimestampsRatherThanDictionaryOrder() {
        for _ in 0..<100 {
            var sequence = SwipeSequence<Int>()
            sequence.begin(1, at: .zero)
            sequence.begin(2, at: .zero)
            XCTAssertEqual(sequence.consume([
                SwipeSample(contact: 1, point: CGPoint(x: 0, y: -9), timestamp: 1),
                SwipeSample(contact: 1, point: CGPoint(x: 12, y: 4), timestamp: 3),
                SwipeSample(contact: 2, point: CGPoint(x: 0, y: 8), timestamp: 2)
            ]), [.down, .right])
        }
    }

    func testHistoryFallbackRetainsItsOriginalTimestampBetweenContacts() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.begin(2, at: .zero)
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 0, y: -9), timestamp: 1),
            SwipeSample(contact: 2, point: CGPoint(x: 8, y: 0), timestamp: 2),
            SwipeSample(contact: 1, point: CGPoint(x: 0, y: -1), timestamp: 3)
        ]), [.up, .right])
    }

    func testRedundantNewerSampleDoesNotReverseTwoAlreadyClearSwipes() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.begin(2, at: .zero)
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 1),
            SwipeSample(contact: 2, point: CGPoint(x: 0, y: 8), timestamp: 2),
            SwipeSample(contact: 1, point: CGPoint(x: 24, y: 0), timestamp: 3)
        ]), [.right, .down])
    }

    func testUncertainDiagonalOnlyGetsItsDirectionAtLiftOff() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.begin(2, at: .zero)
        XCTAssertEqual(sequence.consume([
            SwipeSample(contact: 1, point: CGPoint(x: 12, y: 11), timestamp: 1),
            SwipeSample(contact: 2, point: CGPoint(x: 0, y: 8), timestamp: 2),
            SwipeSample(contact: 1, point: CGPoint(x: 13, y: 11), timestamp: 3)
        ], ending: true), [.down, .right])
    }

    func testDuplicateSamplesAndLateLiftOffNeverRepeatAMove() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        let sample = SwipeSample(contact: 1, point: CGPoint(x: 8, y: 0), timestamp: 1)
        XCTAssertEqual(sequence.consume(Array(repeating: sample, count: 100)), [.right])
        XCTAssertTrue(sequence.hasActiveContacts)
        XCTAssertEqual(sequence.consume([sample], ending: true), [])
        XCTAssertFalse(sequence.hasActiveContacts)
        XCTAssertEqual(sequence.consume([sample], ending: true), [])
    }

    func testCancelledOrResetContactCannotReturnThroughCoalescedHistory() {
        var sequence = SwipeSequence<Int>()
        sequence.begin(1, at: .zero)
        sequence.cancel(1)
        let sample = SwipeSample(contact: 1, point: CGPoint(x: 20, y: 0), timestamp: 1)
        XCTAssertEqual(sequence.consume([sample], ending: true), [])
        sequence.begin(1, at: .zero)
        sequence = SwipeSequence()
        XCTAssertEqual(sequence.consume([sample]), [])
        XCTAssertFalse(sequence.hasEmitted)
    }
}
