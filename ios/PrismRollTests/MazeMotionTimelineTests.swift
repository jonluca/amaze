#if canImport(UIKit) || MOTION_STANDALONE_TESTS
import XCTest
import simd
@testable import PrismRoll

final class MazeMotionTimelineTests: XCTestCase {
    func testSlideStartsImmediatelyAndSettlesWithoutOvershooting() {
        for length in [1, 4, 10] {
            let move = squareMoves(count: 1, length: length)[0]
            var timeline = MazeMotionTimeline()
            timeline.reset(position: move.origin, painted: [move.origin])
            timeline.enqueue(move)
            var previous: Float = 0
            var firstStep: Float = 0
            var lastStep: Float = 0
            let sampleCount = 1_000
            for sample in 1...sampleCount {
                let update = timeline.advance(by: move.duration / Double(sampleCount))
                let position = timeline.position.x
                let step = position - previous
                if sample == 1 { firstStep = step }
                if sample == sampleCount { lastStep = step }
                XCTAssertGreaterThan(step, 0, "A moving ball must not hesitate or reverse")
                XCTAssertLessThanOrEqual(position, Float(length), "The ball crossed a wall")
                XCTAssertGreaterThanOrEqual(position + 0.00001, Float(length * sample) / Float(sampleCount),
                                            "Easing must not lag behind the original linear movement")
                XCTAssertEqual(update.rotations.reduce(SIMD2<Float>.zero, +).x, step, accuracy: 0.00001,
                               "Rotation must follow the same distance as the ball")
                XCTAssertEqual(update.completedAt != nil, sample == sampleCount)
                previous = position
            }
            XCTAssertGreaterThan(firstStep, Float(length) * 0.0009, "Do not add a slow ease-in before responding")
            XCTAssertLessThan(lastStep, firstStep * 0.01, "The ball should decelerate into the final position")
            XCTAssertEqual(timeline.position.x, Float(length))
            XCTAssertFalse(timeline.isMoving)
        }
    }

    func testTrajectoryAndPaintAgreeAtCommonThirtySixtyAndOneTwentyHertzSamples() {
        for count in [1, 8, 32] {
            for length in [1, 4, 10] {
                let moves = squareMoves(count: count, length: length)
                var timelines = (0..<3).map { _ in MazeMotionTimeline() }
                for index in timelines.indices {
                    timelines[index].reset(position: moves[0].origin, painted: [moves[0].origin])
                    for move in moves { timelines[index].enqueue(move) }
                }
                for _ in 0..<4 {
                    for index in timelines.indices {
                        let subframes = 1 << index
                        for _ in 0..<subframes {
                            _ = timelines[index].advance(by: 1 / Double(30 * subframes))
                        }
                    }
                    for timeline in timelines.dropFirst() {
                        XCTAssertEqual(timeline.position.x, timelines[0].position.x, accuracy: 0.00001)
                        XCTAssertEqual(timeline.position.y, timelines[0].position.y, accuracy: 0.00001)
                        XCTAssertEqual(timeline.painted, timelines[0].painted,
                                       "Paint cannot depend on the display refresh rate")
                        XCTAssertEqual(timeline.pendingMoveCount, timelines[0].pendingMoveCount)
                    }
                }
                XCTAssertTrue(timelines.allSatisfy { !$0.isMoving })
            }
        }
    }

    func testPaintCrossingsFollowEasedPositionInsteadOfElapsedTime() {
        let move = squareMoves(count: 1, length: 4)[0]
        var timeline = MazeMotionTimeline()
        timeline.reset(position: move.origin, painted: [move.origin])
        timeline.enqueue(move)
        // At half the time, the ball has reached 2.5 cells. A linear paint
        // clock would still leave the third cell unpainted behind the ball.
        let update = timeline.advance(by: move.duration / 2)
        XCTAssertEqual(timeline.position.x, 2.5, accuracy: 0.00001)
        XCTAssertEqual(update.paintedCells, Array(move.path.prefix(3)))
        XCTAssertEqual(update.rotations, [SIMD2<Float>(2.5, 0)])
        XCTAssertNil(update.completedAt)
        let end = timeline.advance(by: move.duration / 2)
        XCTAssertEqual(end.paintedCells, [move.position])
        XCTAssertEqual(end.completedAt, move.position)
        XCTAssertEqual(timeline.painted, move.painted)
        XCTAssertFalse(timeline.isMoving)
    }

    func testChangingRefreshRatePreservesTrajectoryAndResetDropsOldTurns() {
        let moves = squareMoves(count: 8, length: 4)
        var adaptive = MazeMotionTimeline()
        var reference = MazeMotionTimeline()
        adaptive.reset(position: moves[0].origin, painted: [moves[0].origin])
        reference.reset(position: moves[0].origin, painted: [moves[0].origin])
        for move in moves {
            adaptive.enqueue(move)
            reference.enqueue(move)
        }
        for fps in [120, 120, 120, 60, 60, 80, 80, 120, 120] {
            let update = adaptive.advance(by: 1 / Double(fps))
            var referencePaint: [GridCell] = []
            var referenceCompletion: GridCell?
            for _ in 0..<(480 / fps) {
                let subframe = reference.advance(by: 1.0 / 480)
                referencePaint.append(contentsOf: subframe.paintedCells)
                referenceCompletion = subframe.completedAt ?? referenceCompletion
            }
            XCTAssertEqual(adaptive.position.x, reference.position.x, accuracy: 0.00001)
            XCTAssertEqual(adaptive.position.y, reference.position.y, accuracy: 0.00001)
            XCTAssertEqual(update.paintedCells, referencePaint)
            XCTAssertEqual(update.completedAt, referenceCompletion)
        }
        XCTAssertFalse(adaptive.isMoving)
        for move in moves { adaptive.enqueue(move) }
        _ = adaptive.advance(by: 1.0 / 80)
        XCTAssertTrue(adaptive.isMoving)
        adaptive.reset(position: moves[0].origin, painted: [moves[0].origin])
        let idle = adaptive.advance(by: 1.0 / 60)
        XCTAssertEqual(adaptive.position, .zero)
        XCTAssertEqual(adaptive.painted, [moves[0].origin])
        XCTAssertTrue(idle.rotations.isEmpty)
        XCTAssertNil(idle.completedAt)
        adaptive.enqueue(moves[0])
        _ = adaptive.advance(by: 1.0 / 120)
        XCTAssertGreaterThan(adaptive.position.x, 0)
        XCTAssertLessThan(adaptive.position.x, 1, "Reset must discard the earlier burst's catch-up rate")
    }

    func testIsolatedSlidesFinishWithinOneHundredMilliseconds() {
        for fps in [30.0, 60.0, 120.0] {
            for length in [1, 4, 10] {
                let move = squareMoves(count: 1, length: length)[0]
                var timeline = MazeMotionTimeline()
                timeline.reset(position: move.origin, painted: [move.origin])
                timeline.enqueue(move)
                var elapsed = 0.0
                while timeline.isMoving, elapsed < 1 {
                    let frame = timeline.advance(by: 1 / fps)
                    elapsed += 1 / fps
                    XCTAssertEqual(frame.completedAt != nil, !timeline.isMoving)
                }
                XCTAssertLessThanOrEqual(elapsed, 0.10 + 1 / fps + 0.000001)
                XCTAssertEqual(timeline.position, SIMD2(Float(move.position.column), Float(move.position.row)))
                XCTAssertEqual(timeline.painted, move.painted)
            }
        }
    }

    func testBurstDrainHasBoundedLatencyAndTraversesEveryOriginalSegment() {
        for fps in [30.0, 60.0, 120.0] {
            for count in [8, 32, 128] {
                let moves = squareMoves(count: count, length: 4)
                var timeline = MazeMotionTimeline()
                timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
                for move in moves { timeline.enqueue(move) }
                var elapsed = 0.0
                var distance: Float = 0
                var paintedInOrder: [GridCell] = []
                var completions = 0
                var previous = timeline.position
                while timeline.isMoving, elapsed < 1 {
                    let update = timeline.advance(by: 1 / fps)
                    elapsed += 1 / fps
                    for delta in update.rotations {
                        XCTAssertTrue(abs(delta.x) < 0.0001 || abs(delta.y) < 0.0001, "A turn cut across a wall")
                        previous += delta
                        XCTAssertTrue(abs(previous.x) < 0.0001 || abs(previous.y) < 0.0001
                                      || abs(previous.x - 4) < 0.0001 || abs(previous.y - 4) < 0.0001)
                        distance += simd_length(delta)
                    }
                    paintedInOrder.append(contentsOf: update.paintedCells)
                    if update.completedAt != nil {
                        completions += 1
                        XCTAssertFalse(timeline.isMoving, "Completion arrived before the last accepted turn")
                    }
                }
                XCTAssertLessThanOrEqual(elapsed, 0.10 + 1 / fps + 0.000001, "Burst length must not create a long animation queue")
                XCTAssertFalse(timeline.isMoving)
                XCTAssertEqual(distance, Float(count * 4), accuracy: 0.001, "Revisited paths still need their complete movement")
                XCTAssertEqual(timeline.painted, moves.last!.painted)
                var seen: Set<GridCell> = [moves[0].origin]
                let expectedPaint = moves.flatMap(\.path).filter { seen.insert($0).inserted }
                XCTAssertEqual(paintedInOrder, expectedPaint, "Catch-up reordered or dropped a painted tile")
                XCTAssertEqual(completions, 1)
                XCTAssertNil(timeline.advance(by: 1 / fps).completedAt)
            }
        }
    }

    func testSustainedSwipesDoNotLeaveASlowAnimationTail() {
        for fps in [30.0, 60.0, 120.0] {
            for spacing in [0.025, 0.05, 0.09] {
                let moves = squareMoves(count: 64, length: 4)
                var timeline = MazeMotionTimeline()
                timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
                var arrivals: [Double] = []
                var elapsed = 0.0
                var settled = 0
                while settled < moves.count, elapsed < 10 {
                    while arrivals.count < moves.count, Double(arrivals.count) * spacing <= elapsed + 0.000001 {
                        timeline.enqueue(moves[arrivals.count])
                        arrivals.append(elapsed)
                    }
                    _ = timeline.advance(by: 1 / fps)
                    elapsed += 1 / fps
                    let nowSettled = arrivals.count - timeline.pendingMoveCount
                    for index in settled..<nowSettled {
                        XCTAssertLessThanOrEqual(elapsed - arrivals[index], 0.10 + 1 / fps + 0.000001,
                                                 "A continuing burst left an older input waiting")
                    }
                    settled = nowSettled
                }
                XCTAssertEqual(settled, moves.count)
                XCTAssertEqual(timeline.painted, moves.last!.painted)
                XCTAssertLessThanOrEqual(elapsed - arrivals.last!, 0.10 + 1 / fps + 0.000001)
            }
        }
    }

    func testNewestQueuedMoveStartsWithinOneProMotionInterval() {
        for count in [2, 8, 32, 128] {
            for length in [1, 4, 10] {
                let moves = squareMoves(count: count, length: length)
                var timeline = MazeMotionTimeline()
                timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
                for move in moves { timeline.enqueue(move) }

                _ = timeline.advance(by: 1.0 / 120 + 0.000001)
                XCTAssertEqual(timeline.pendingMoveCount, 1, "Older swipes delayed the newest turn")
                let final = moves.last!
                let origin = SIMD2<Float>(Float(final.origin.column), Float(final.origin.row))
                XCTAssertGreaterThan(simd_distance(timeline.position, origin), 0, "The newest move has not started")
                // Catching up must leave the latest swipe visibly rolling.
                XCTAssertLessThan(simd_distance(timeline.position, origin), Float(length) / 4)
            }
        }
    }

    func testMidSlideInputDoesNotRewindOrWaitForTheOldStop() {
        for length in [1, 4, 10] {
            for fraction in [0.1, 0.5, 0.9] {
                let moves = squareMoves(count: 2, length: length)
                var timeline = MazeMotionTimeline()
                timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
                timeline.enqueue(moves[0])
                // Subdivide to keep even late arrivals inside the frame cap.
                for _ in 0..<10 { _ = timeline.advance(by: moves[0].duration * fraction / 10) }
                let before = timeline.position
                timeline.enqueue(moves[1])
                XCTAssertEqual(timeline.position, before, "Receiving input cannot teleport the ball")
                let frame = timeline.advance(by: 0.000001)
                XCTAssertGreaterThanOrEqual(timeline.position.x, before.x, "Changing easing rewound the ball")
                XCTAssertLessThan(timeline.position.x - before.x, 0.01, "Rebasing introduced a position jump")
                XCTAssertTrue(frame.rotations.allSatisfy { $0.x >= 0 && $0.y == 0 })

                _ = timeline.advance(by: 1.0 / 120)
                XCTAssertEqual(timeline.pendingMoveCount, 1)
                XCTAssertEqual(timeline.position.x, Float(length))
                XCTAssertGreaterThan(timeline.position.y, 0, "The next turn waited at the wall")
            }
        }
    }

    func testQueuedWallContactKeepsMovingAndFinalSlideStillSettles() {
        let moves = squareMoves(count: 2, length: 10)
        var timeline = MazeMotionTimeline()
        timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
        for move in moves { timeline.enqueue(move) }
        let step = 1.0 / 120 / 1_000
        _ = timeline.advance(by: 1.0 / 120 - 2 * step)
        let first = timeline.advance(by: step).rotations.reduce(SIMD2<Float>.zero, +).x
        let wall = timeline.advance(by: step).rotations.reduce(SIMD2<Float>.zero, +).x
        XCTAssertGreaterThan(wall, 0.009, "A pending turn must not ease to a stop at the wall")
        XCTAssertEqual(wall, first, accuracy: 0.00001)
        XCTAssertEqual(timeline.pendingMoveCount, 1)
        _ = timeline.advance(by: 1.0 / 120)
        XCTAssertGreaterThan(timeline.position.y, 0)
        XCTAssertLessThan(timeline.position.y, 2, "The newest move was compressed into a snap")
        for _ in 0..<12 { _ = timeline.advance(by: 1.0 / 120) }
        XCTAssertFalse(timeline.isMoving)
        XCTAssertEqual(timeline.position, SIMD2<Float>(10, 10))
    }

    func testSustainedInputStartsNewestTurnWithinOneDisplayFrame() {
        for fps in [30.0, 60.0, 120.0] {
            let moves = squareMoves(count: 128, length: 10)
            var timeline = MazeMotionTimeline()
            timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
            for move in moves {
                timeline.enqueue(move)
                _ = timeline.advance(by: 1 / fps)
                XCTAssertLessThanOrEqual(timeline.pendingMoveCount, 1, "A continuing burst left old input queued")
            }
            for _ in 0..<12 { _ = timeline.advance(by: 1 / fps) }
            XCTAssertFalse(timeline.isMoving)
            XCTAssertEqual(timeline.painted, moves.last!.painted)
        }
    }

    func testCatchUpRateResetsAfterIdleAndReplay() {
        for reset in [false, true] {
            let moves = squareMoves(count: 32, length: 4)
            var timeline = MazeMotionTimeline()
            timeline.reset(position: moves[0].origin, painted: [moves[0].origin])
            for move in moves { timeline.enqueue(move) }
            _ = timeline.advance(by: 1 / 60)
            if reset { timeline.reset(position: moves[0].origin, painted: [moves[0].origin]) }
            else { for _ in 0..<10 { _ = timeline.advance(by: 1 / 60) } }
            XCTAssertFalse(timeline.isMoving)
            timeline.enqueue(moves[0])
            let frame = timeline.advance(by: 1 / 60)
            XCTAssertTrue(timeline.isMoving, "An earlier burst cannot make a fresh gesture snap instantly")
            XCTAssertGreaterThan(timeline.position.x, 0)
            XCTAssertLessThan(timeline.position.x, 2)
            XCTAssertNil(frame.completedAt)
        }
    }

    func testInvalidIntervalsCannotConsumeAcceptedMovement() {
        let move = squareMoves(count: 1, length: 4)[0]
        var timeline = MazeMotionTimeline()
        timeline.reset(position: move.origin, painted: [move.origin])
        timeline.enqueue(move)
        for interval in [0, -1, Double.nan, Double.infinity] {
            let frame = timeline.advance(by: interval)
            XCTAssertEqual(timeline.position, .zero)
            XCTAssertEqual(timeline.pendingMoveCount, 1)
            XCTAssertTrue(frame.rotations.isEmpty)
            XCTAssertTrue(frame.paintedCells.isEmpty)
            XCTAssertNil(frame.completedAt)
        }
    }

    private func squareMoves(count: Int, length: Int) -> [MazeSceneMove] {
        let start = GridCell(row: 0, column: 0)
        let corners = [start, GridCell(row: 0, column: length), GridCell(row: length, column: length),
                       GridCell(row: length, column: 0), start]
        var painted: Set<GridCell> = [start]
        return (0..<count).map { index in
            let origin = corners[index % 4]
            let target = corners[index % 4 + 1]
            let path = (1...length).map { step in
                GridCell(row: origin.row + (target.row - origin.row) * step / length,
                         column: origin.column + (target.column - origin.column) * step / length)
            }
            painted.formUnion(path)
            return MazeSceneMove(origin: origin, path: path, position: target, painted: painted, isComplete: index == count - 1)
        }
    }
}
#endif
