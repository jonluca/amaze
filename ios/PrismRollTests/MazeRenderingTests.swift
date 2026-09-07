#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeRenderingTests: XCTestCase {
    func testRapidTurnsStayInCorridorsAndReachEveryAcceptedDestination() {
        var timeline = MazeMotionTimeline()
        let start = GridCell(row: 0, column: 0)
        timeline.reset(position: start, painted: [start])
        let corners = [start, GridCell(row: 0, column: 4), GridCell(row: 4, column: 4), GridCell(row: 4, column: 0), start]
        var painted: Set<GridCell> = [start]
        for index in 0..<32 {
            let origin = corners[index % 4]
            let target = corners[index % 4 + 1]
            let path = (1...4).map { step in GridCell(row: origin.row + (target.row - origin.row) * step / 4,
                                                      column: origin.column + (target.column - origin.column) * step / 4) }
            painted.formUnion(path)
            timeline.enqueue(MazeSceneMove(origin: origin, path: path, position: target, painted: painted, isComplete: index == 31))
        }
        var distance: Float = 0
        var completed: GridCell?
        for _ in 0..<90 {
            let frame = timeline.advance(by: 1.0 / 60)
            for segment in frame.rotations {
                XCTAssertTrue(abs(segment.x) < 0.0001 || abs(segment.y) < 0.0001, "A turn cut diagonally across a wall")
                distance += simd_length(segment)
            }
            let point = timeline.position
            XCTAssertTrue(abs(point.x) < 0.0001 || abs(point.y) < 0.0001 || abs(point.x - 4) < 0.0001 || abs(point.y - 4) < 0.0001)
            completed = frame.completedAt ?? completed
        }
        XCTAssertFalse(timeline.isMoving, "A burst retained more than 1.5 seconds of visual debt")
        XCTAssertEqual(distance, 128, accuracy: 0.001, "Every slide must be traversed, including revisits")
        XCTAssertEqual(timeline.painted, painted)
        XCTAssertEqual(completed, start)
    }

    func testReplayDiscardsOldMovementAndPaintEvenWhenResetPaintIsUnchanged() {
        let start = GridCell(row: 0, column: 0)
        let path = (1...5).map { GridCell(row: 0, column: $0) }
        var timeline = MazeMotionTimeline()
        timeline.reset(position: start, painted: [start])
        timeline.enqueue(MazeSceneMove(origin: start, path: path, position: path.last!, painted: Set(path + [start]), isComplete: true))
        _ = timeline.advance(by: 1.0 / 60)
        timeline.reset(position: start, painted: [start])
        let frame = timeline.advance(by: 1)
        XCTAssertEqual(timeline.position, .zero)
        XCTAssertEqual(timeline.painted, [start])
        XCTAssertTrue(frame.paintedCells.isEmpty)
        XCTAssertNil(frame.completedAt)
        XCTAssertFalse(timeline.isMoving)
    }

    func testSceneIsNotRevealedBeforeMaterialsAndViewportAreReady() async {
        let coordinator = MazeSceneCoordinator(onSwipe: { _ in XCTFail("Input before readiness") })
        let view = MazeCanvasView(frame: .zero)
        coordinator.configure(view)
        let level = MazeLevel.generate(number: 18, mode: .endless)
        let ready = expectation(description: "Asynchronous texture preparation")
        coordinator.renderer.onResourcesReady = { ready.fulfill() }
        let start = Date()
        coordinator.renderer.update(level: level, position: level.start, painted: [level.start], skin: BallSkin.catalog[0], isComplete: false, theme: .timber)
        print("PRISM_CPU_AFTER synchronousUpdate=\(Date().timeIntervalSince(start))")
        XCTAssertNil(view.scene)
        XCTAssertTrue(view.isPreparing)
        XCTAssertFalse(coordinator.isReady)
        await fulfillment(of: [ready], timeout: 10)
        XCTAssertNil(view.scene, "A zero-size viewport cannot reveal the board")
        XCTAssertFalse(coordinator.isReady, "Material completion is not a displayed first frame")
        coordinator.stop()
    }

    func testStaleSwiftUISnapshotCannotRewindOrderedMoveStream() async throws {
        let renderer = MazeSceneRenderer()
        renderer.consumesMoveEvents = true
        let runID = UUID()
        var run = MazeRun(level: MazeLevel.generate(number: 18, mode: .endless))
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted, skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        var snapshots: [MazeRun] = []
        for direction in run.level.solution.prefix(3) {
            let start = run.position
            let path = run.move(direction)
            XCTAssertFalse(path.isEmpty)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position, painted: run.painted, isComplete: run.isComplete, moves: run.moves))
            snapshots.append(run)
        }
        let old = try XCTUnwrap(snapshots.first)
        renderer.update(level: old.level, position: old.position, painted: old.painted, skin: BallSkin.catalog[0], isComplete: old.isComplete, resetID: runID)
        XCTAssertEqual(renderer.acceptedMoveCount, 3)
        XCTAssertEqual(renderer.pendingMoveCount, 3)
        for _ in 0..<60 { renderer.advance(by: 1.0 / 60) }
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(run.position.column), Float(run.position.row)))
        XCTAssertEqual(renderer.renderedPainted, run.painted)
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        renderer.stop()
    }

    func testEnablingReduceMotionSettlesQueuedTurnsAndRemovesExistingEffects() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let runID = UUID()
        var run = MazeRun(level: MazeLevel.generate(number: 5, mode: .endless))
        XCTAssertFalse(run.level.coinCells.isEmpty)
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted,
                        skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        let board = try XCTUnwrap(renderer.scene.rootNode.childNode(withName: "maze-board", recursively: false))
        XCTAssertTrue(board.childNodes.contains { $0.action(forKey: "coin-spin") != nil })
        for direction in run.level.solution.prefix(3) {
            let start = run.position
            let path = run.move(direction)
            XCTAssertFalse(path.isEmpty)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                           painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        }
        renderer.advance(by: 1.0 / 60)
        renderer.advance(by: 1.0 / 60)
        XCTAssertGreaterThan(renderer.pendingMoveCount, 0)
        XCTAssertNotNil(board.childNode(withName: "paint-effect", recursively: false))

        renderer.setReduceMotion(true)

        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(run.position.column), Float(run.position.row)))
        XCTAssertEqual(renderer.renderedPainted, run.painted)
        XCTAssertNil(board.childNode(withName: "paint-effect", recursively: false))
        XCTAssertNil(board.childNode(withName: "celebration", recursively: false))
        renderer.scene.rootNode.enumerateChildNodes { node, _ in
            XCTAssertFalse(node.hasActions, "Reduce Motion left an existing SceneKit action running")
        }
        for direction in run.level.solution.dropFirst(3) {
            let start = run.position
            let path = run.move(direction)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                           painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        }
        XCTAssertTrue(run.isComplete)
        renderer.advance(by: 1)
        XCTAssertTrue(renderer.resultReady)
        XCTAssertEqual(renderer.renderedPainted, run.level.openCells)
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        renderer.scene.rootNode.enumerateChildNodes { node, _ in XCTAssertFalse(node.hasActions) }
    }

    func testCompletionWaitsForEveryQueuedTurnAndReplayClearsIt() async {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let runID = UUID()
        var run = MazeRun(level: MazeLevel.generate(number: 1, mode: .endless))
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted,
                        skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        renderer.onResourcesReady = nil
        for direction in run.level.solution {
            let start = run.position
            let path = run.move(direction)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                           painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        }
        XCTAssertTrue(run.isComplete)
        XCTAssertGreaterThan(renderer.pendingMoveCount, 0)
        XCTAssertFalse(renderer.resultReady, "The result must not obscure accepted turns still animating")
        for _ in 0..<120 {
            if renderer.pendingMoveCount == 0 { break }
            XCTAssertFalse(renderer.resultReady)
            renderer.advance(by: 1.0 / 60)
        }
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(renderer.resultReady)
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(run.position.column), Float(run.position.row)))
        XCTAssertEqual(renderer.renderedPainted, run.level.openCells)
        renderer.update(level: run.level, position: run.level.start, painted: [run.level.start],
                        skin: BallSkin.catalog[0], isComplete: false, resetID: UUID())
        XCTAssertFalse(renderer.resultReady, "A new run cannot inherit the previous completion")
    }

    func testBallPreviewStopsAndResumesWhenReduceMotionChanges() throws {
        let coordinator = BallSceneCoordinator()
        defer { coordinator.stop() }
        let sphere = try XCTUnwrap(coordinator.scene.rootNode.childNodes.first { $0.geometry is SCNSphere })
        coordinator.update(skin: BallSkin.catalog[0], isAnimated: true, reduceMotion: false)
        XCTAssertNotNil(sphere.action(forKey: "turntable"))
        coordinator.update(skin: BallSkin.catalog[0], isAnimated: true, reduceMotion: true)
        XCTAssertNil(sphere.action(forKey: "turntable"))
        coordinator.update(skin: BallSkin.catalog[0], isAnimated: true, reduceMotion: false)
        XCTAssertNotNil(sphere.action(forKey: "turntable"))
    }

    func testFailedLastMoveSettlesAndStaleSnapshotCannotClearFailure() async throws {
        let cells = Set((0..<4).flatMap { row in
            (0..<4).compactMap { column in
                row == 0 || row == 3 || column == 0 || column == 3 ? GridCell(row: row, column: column) : nil
            }
        })
        let level = MazeLevel(number: 1, mode: .challenge, width: 4, height: 4,
                              openCells: cells, start: GridCell(row: 0, column: 0),
                              solution: [.right, .down, .left, .up], moveLimit: 4)
        var run = MazeRun(level: level)
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let runID = UUID()
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: level, position: run.position, painted: run.painted, skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: false, moveCount: run.moves, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        renderer.onResourcesReady = nil
        var old: MazeRun?
        for direction in [MoveDirection.right, .left, .right, .left] {
            let start = run.position
            let path = run.move(direction)
            XCTAssertFalse(path.isEmpty)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                           painted: run.painted, isComplete: run.isComplete, moves: run.moves))
            if run.moves == 2 { old = run }
        }
        XCTAssertTrue(run.isFailed)
        renderer.update(level: level, position: run.position, painted: run.painted, skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: true, moveCount: run.moves, resetID: runID)
        XCTAssertTrue(renderer.hasResult)
        XCTAssertFalse(renderer.resultReady, "The failure overlay must wait for the last allowed slide")
        let stale = try XCTUnwrap(old)
        XCTAssertEqual(stale.position, run.position)
        XCTAssertEqual(stale.painted, run.painted)
        renderer.update(level: level, position: stale.position, painted: stale.painted, skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: false, moveCount: stale.moves, resetID: runID)
        XCTAssertTrue(renderer.hasResult, "Position/paint equality cannot make an older move snapshot authoritative")
        for _ in 0..<120 {
            if renderer.pendingMoveCount == 0 { break }
            XCTAssertFalse(renderer.resultReady)
            renderer.advance(by: 1.0 / 60)
        }
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(renderer.resultReady)
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(run.position.column), Float(run.position.row)))

        XCTAssertTrue(run.grantExtraMoves(count: 1))
        renderer.update(level: level, position: run.position, painted: run.painted, skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: false, moveCount: run.moves, resetID: runID)
        XCTAssertFalse(renderer.hasResult, "A rewarded extension must clear the earlier result in the same run")
        let start = run.position
        let path = run.move(.right)
        renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                       painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        XCTAssertTrue(run.isFailed)
        renderer.update(level: level, position: run.position, painted: run.painted, skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: true, moveCount: run.moves, resetID: runID)
        XCTAssertFalse(renderer.resultReady)
        renderer.setReduceMotion(true)
        XCTAssertTrue(renderer.resultReady, "Reduce Motion can present the new failure after immediately settling its move")
        renderer.update(level: level, position: level.start, painted: [level.start], skin: BallSkin.catalog[0],
                        isComplete: false, isFailed: false, moveCount: 0, resetID: UUID())
        XCTAssertFalse(renderer.resultReady)
    }

    func testCameraFitsActualBoardBoundsOnPhoneCompactAndTablet() {
        for viewport in [CGSize(width: 393, height: 460), CGSize(width: 375, height: 220), CGSize(width: 720, height: 750)] {
            let renderer = MazeSceneRenderer()
            let view = SCNView(frame: CGRect(origin: .zero, size: viewport))
            let level = MazeLevel.generate(number: 18, mode: .endless)
            renderer.update(level: level, position: level.start, painted: [level.start], skin: BallSkin.catalog[0], isComplete: false)
            renderer.resize(to: viewport)
            view.scene = renderer.scene
            view.pointOfView = renderer.cameraNode
            let bounds = renderer.scene.rootNode.childNode(withName: "maze-board", recursively: false)!.boundingBox
            var projected: [SCNVector3] = []
            for x in [bounds.min.x, bounds.max.x] {
                for y in [bounds.min.y, bounds.max.y] {
                    for z in [bounds.min.z, bounds.max.z] { projected.append(view.projectPoint(SCNVector3(x, y, z))) }
                }
            }
            let width = projected.map(\.x).max()! - projected.map(\.x).min()!
            let height = projected.map(\.y).max()! - projected.map(\.y).min()!
            XCTAssertGreaterThan(width, 0)
            XCTAssertLessThanOrEqual(width / Float(viewport.width), 0.69)
            XCTAssertLessThanOrEqual(height / Float(viewport.height), 0.79)
            renderer.stop()
            view.scene = nil
        }
    }

    func testPathMarkersFollowDisplayedPaintThroughRapidMovesAndLiveToggle() async {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let runID = UUID()
        var run = MazeRun(level: MazeLevel.generate(number: 1, mode: .endless))
        let ready = expectation(description: "Materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted,
                        skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        XCTAssertTrue(renderer.markedUnpaintedCells.isEmpty, "Normal appearance must not add path markers")
        for direction in run.level.solution {
            let start = run.position
            let path = run.move(direction)
            renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                           painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        }
        XCTAssertTrue(run.isComplete)
        XCTAssertGreaterThan(renderer.pendingMoveCount, 0)
        renderer.setDifferentiateWithoutColor(true)
        XCTAssertEqual(renderer.markedUnpaintedCells, run.level.openCells.subtracting([run.level.start]),
                       "Accepted input cannot hide markers before its paint is rendered")
        renderer.advance(by: 1.0 / 60)
        let position = renderer.renderedCellPosition
        let pending = renderer.pendingMoveCount
        renderer.setDifferentiateWithoutColor(false)
        XCTAssertTrue(renderer.markedUnpaintedCells.isEmpty)
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "unpainted-marker", recursively: true))
        renderer.setDifferentiateWithoutColor(true)
        XCTAssertEqual(renderer.renderedCellPosition, position, "A display preference must not interrupt a slide")
        XCTAssertEqual(renderer.pendingMoveCount, pending)
        for _ in 0..<120 {
            XCTAssertEqual(renderer.markedUnpaintedCells, run.level.openCells.subtracting(renderer.renderedPainted))
            if renderer.pendingMoveCount == 0 { break }
            renderer.advance(by: 1.0 / 60)
        }
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(renderer.markedUnpaintedCells.isEmpty)
        XCTAssertEqual(renderer.renderedPainted, run.level.openCells)
    }

    func testPathMarkersRestoreOnReplayAndRebuildAcrossThemes() {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        renderer.setDifferentiateWithoutColor(true)
        let level = MazeLevel.generate(number: 18, mode: .endless)
        for theme in BoardTheme.allCases {
            renderer.update(level: level, position: level.start, painted: level.openCells,
                            skin: BallSkin.catalog[0], isComplete: true, theme: theme, resetID: UUID())
            XCTAssertTrue(renderer.markedUnpaintedCells.isEmpty)
            renderer.update(level: level, position: level.start, painted: [level.start],
                            skin: BallSkin.catalog[0], isComplete: false, theme: theme, resetID: UUID())
            XCTAssertEqual(renderer.markedUnpaintedCells, level.openCells.subtracting([level.start]))
            let board = renderer.scene.rootNode.childNode(withName: "maze-board", recursively: false)
            XCTAssertEqual(board?.childNodes.filter { $0.name == "unpainted-marker" }.count, level.openCells.count,
                           "A rebuild must create exactly one marker per path cell and none on walls")
        }
        renderer.setDifferentiateWithoutColor(false)
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "unpainted-marker", recursively: true))
    }
}
#endif
