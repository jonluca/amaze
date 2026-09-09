#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeBallImpactTests: XCTestCase {
    func testImpactCompressesAlongEachWallAndPreservesVolumeAndFloorContact() {
        for direction in [SIMD2<Float>(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0, -1)] {
            var impact = MazeBallImpact()
            impact.begin(direction: direction)
            let scale = impact.scale
            XCTAssertLessThan(direction.x == 0 ? scale.z : scale.x, 0.85)
            XCTAssertGreaterThan(scale.y, 1)
            XCTAssertEqual(scale.x * scale.y * scale.z, 1, accuracy: 0.0001)
            XCTAssertEqual(0.423 + impact.offset.y - 0.405 * scale.y, 0.018, accuracy: 0.0001)
        }
    }

    func testReboundsThenSettlesAtAllDisplayRatesWithoutDelayingMovement() {
        for rate in [30.0, 60, 80, 120] {
            var impact = MazeBallImpact()
            impact.begin(direction: SIMD2(1, 0))
            var rebounded = false
            for _ in 0..<Int(ceil(MazeBallImpact.duration * rate) + 1) {
                impact.advance(by: 1 / rate)
                if impact.scale.x > 1 { rebounded = true }
            }
            XCTAssertTrue(rebounded)
            XCTAssertFalse(impact.isPlaying)
            XCTAssertEqual(impact.scale, SIMD3(repeating: 1))
            XCTAssertEqual(impact.offset, .zero)
        }
    }

    func testTimelineReportsWallOnlyWhenSlideReachesItsDestination() {
        let start = GridCell(row: 0, column: 0)
        let path = (1...4).map { GridCell(row: 0, column: $0) }
        var motion = MazeMotionTimeline()
        motion.reset(position: start, painted: [start])
        motion.enqueue(MazeSceneMove(origin: start, path: path, position: path.last!,
                                     painted: Set(path + [start]), isComplete: false))
        XCTAssertNil(motion.advance(by: 0.02).wallImpactDirection)
        XCTAssertEqual(motion.advance(by: 0.06).wallImpactDirection, SIMD2(4, 0))
        XCTAssertFalse(motion.isMoving)
        XCTAssertNil(motion.advance(by: 0.02).wallImpactDirection)
    }

    func testNewDirectionAndResetCannotRetainPreviousDeformation() {
        var impact = MazeBallImpact()
        impact.begin(direction: SIMD2(1, 0))
        impact.advance(by: 0.03)
        impact.begin(direction: SIMD2(0, -1))
        XCTAssertLessThan(impact.scale.z, 1)
        XCTAssertGreaterThan(impact.scale.x, 1)
        for step in [0.0, -1, .nan, .infinity] { impact.advance(by: step) }
        XCTAssertTrue(impact.isPlaying)
        impact.reset()
        XCTAssertFalse(impact.isPlaying)
        XCTAssertEqual(impact.scale, SIMD3(repeating: 1))
    }

    func testQueuedTurnDoesNotSquashAwayFromThePreviousWall() {
        var motion = MazeMotionTimeline()
        let start = GridCell(row: 0, column: 0)
        let horizontal = (1...10).map { GridCell(row: 0, column: $0) }
        let vertical = (1...10).map { GridCell(row: $0, column: 10) }
        motion.reset(position: start, painted: [start])
        motion.enqueue(MazeSceneMove(origin: start, path: horizontal, position: horizontal.last!,
                                     painted: Set(horizontal + [start]), isComplete: false))
        motion.enqueue(MazeSceneMove(origin: horizontal.last!, path: vertical, position: vertical.last!,
                                     painted: Set(horizontal + vertical + [start]), isComplete: false))
        let turningFrame = motion.advance(by: 1.0 / 60)
        XCTAssertGreaterThan(motion.position.y, 0)
        XCTAssertNil(turningFrame.wallImpactDirection)
        var lastImpact: SIMD2<Float>?
        while motion.isMoving {
            lastImpact = motion.advance(by: 1.0 / 60).wallImpactDirection ?? lastImpact
        }
        XCTAssertEqual(lastImpact, SIMD2(0, 10))
    }

    func testRendererSquashesOnArrivalAndReduceMotionClearsIt() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let runID = UUID()
        var run = MazeRun(level: MazeLevel.generate(number: 16, mode: .endless))
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted,
                        skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        let origin = run.position
        let path = run.move(run.level.solution[0])
        renderer.receive(GameMoveEvent(runID: runID, start: origin, path: path, position: run.position,
                                       painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        while renderer.pendingMoveCount > 0 { renderer.advance(by: 1.0 / 120) }
        let shape = try XCTUnwrap(renderer.scene.rootNode.childNode(withName: "ball-impact", recursively: true))
        XCTAssertNotEqual(shape.simdScale, SIMD3(repeating: 1))
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(run.position.column), Float(run.position.row)))
        renderer.setReduceMotion(true)
        XCTAssertEqual(shape.simdScale, SIMD3(repeating: 1))
        XCTAssertEqual(shape.position.y, 0.423, accuracy: 0.0001)
    }
}
#endif
