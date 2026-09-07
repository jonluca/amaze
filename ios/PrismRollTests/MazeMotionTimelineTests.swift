#if canImport(UIKit) || MOTION_STANDALONE_TESTS
import XCTest
import simd
@testable import PrismRoll

final class MazeMotionTimelineTests: XCTestCase {
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
