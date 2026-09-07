#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class BallTrailTests: XCTestCase {
    func testEveryCatalogBallHasDistinctTrailArtwork() throws {
        var artwork: Set<Data> = []
        for skin in BallSkin.catalog {
            let style = try XCTUnwrap(BallTrailStyle(rawValue: skin.id), "Missing trail for \(skin.name)")
            let images = BallTrailTexture.make(for: style)
            XCTAssertFalse(images.isEmpty)
            var bytes = Data()
            for image in images {
                XCTAssertGreaterThan(image.size.width, 0)
                bytes.append(try XCTUnwrap(image.pngData()))
            }
            XCTAssertTrue(artwork.insert(bytes).inserted, "\(skin.name) duplicates another ball's trail artwork")
        }
        XCTAssertEqual(artwork.count, 12)
    }

    func testTrailEmitsOnAlreadyPaintedRevisitsAndDrainsWhileBallIsIdle() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        let runID = UUID()
        var run = MazeRun(level: trailLevel())
        await prepare(renderer, run: run, runID: runID)

        move(.right, run: &run, renderer: renderer, runID: runID)
        for _ in 0..<4 { renderer.advance(by: 1.0 / 60) }
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)
        for _ in 0..<150 { renderer.advance(by: 1.0 / 60) }
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty,
                      "Particles must keep aging after movement finishes")

        let painted = renderer.renderedPainted
        move(.left, run: &run, renderer: renderer, runID: runID)
        for _ in 0..<4 { renderer.advance(by: 1.0 / 60) }
        XCTAssertEqual(renderer.renderedPainted, painted)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty,
                       "Travel over existing paint must produce a fresh trail")
        for _ in 0..<150 { renderer.advance(by: 1.0 / 60) }
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty)
    }

    func testReplaySkinChangeAndStopClearExistingTrail() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        var runID = UUID()
        var run = MazeRun(level: trailLevel())
        await prepare(renderer, run: run, runID: runID)
        move(.right, run: &run, renderer: renderer, runID: runID)
        renderer.advance(by: 1.0 / 30)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)

        await prepare(renderer, run: run, runID: runID, skin: BallSkin.catalog[4])
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty,
                      "Changing balls must discard the previous ball's particles")
        renderer.advance(by: 1.0 / 30)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)

        run = MazeRun(level: run.level)
        runID = UUID()
        await prepare(renderer, run: run, runID: runID, skin: BallSkin.catalog[4])
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty)
        move(.right, run: &run, renderer: renderer, runID: runID)
        renderer.advance(by: 1.0 / 30)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)
        renderer.stop()
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty)
    }

    func testReduceMotionClearsCurrentTrailAndSuppressesNewParticlesUntilDisabled() async {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        let runID = UUID()
        var run = MazeRun(level: trailLevel())
        await prepare(renderer, run: run, runID: runID)
        move(.right, run: &run, renderer: renderer, runID: runID)
        renderer.advance(by: 1.0 / 30)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)

        renderer.setReduceMotion(true)
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty)
        move(.left, run: &run, renderer: renderer, runID: runID)
        renderer.advance(by: 1.0 / 30)
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertTrue(visibleParticles(in: renderer.scene.rootNode).isEmpty)

        renderer.setReduceMotion(false)
        move(.right, run: &run, renderer: renderer, runID: runID)
        renderer.advance(by: 1.0 / 30)
        XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty)
    }

    func testRapidQueuedTurnsLeaveParticlesOnlyAlongTraversedCorridors() async throws {
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        let level = trailLevel(width: 9, height: 7)
        let runID = UUID()
        await prepare(renderer, run: MazeRun(level: level), runID: runID)
        var position = level.start
        var painted: Set<GridCell> = [position]
        let directions: [MoveDirection] = [.right, .down, .left, .up]
        for index in 0..<40 {
            let path = MazeSolver.path(from: position, direction: directions[index % 4], in: level.openCells)
            let target = try XCTUnwrap(path.last)
            painted.formUnion(path)
            renderer.receive(GameMoveEvent(runID: runID, start: position, path: path, position: target,
                                           painted: painted, isComplete: false, moves: index + 1))
            position = target
        }
        let board = try XCTUnwrap(renderer.scene.rootNode.childNode(withName: "maze-board", recursively: false))
        var observedParticles = 0
        for _ in 0..<120 {
            renderer.advance(by: 1.0 / 120)
            let active = visibleParticles(in: board)
            observedParticles += active.count
            XCTAssertLessThanOrEqual(active.count, MazeBallTrailEffects.capacity)
            for particle in active { assertInsideCorridor(particle, root: board, level: level) }
        }
        XCTAssertGreaterThan(observedParticles, 0)
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertEqual(renderer.renderedCellPosition, SIMD2(Float(position.column), Float(position.row)))
        XCTAssertLessThanOrEqual(particles(in: board).count, MazeBallTrailEffects.capacity)
        XCTAssertTrue(visibleParticles(in: board).isEmpty)
    }

    func testParticleAndPerFrameBudgetsReusePreparedResourcesAcrossRepeatedBursts() throws {
        let effects = MazeBallTrailEffects()
        effects.setSkin(BallSkin.catalog[0])
        let prepared = effects.preparationResources.compactMap { $0 as? SCNGeometry }
        let resourceIDs = prepared.map(ObjectIdentifier.init)
        XCTAssertFalse(prepared.isEmpty, "Particle geometry should be prepared before the first moving frame")
        let level = trailLevel(width: 9, height: 7)
        let root = SCNNode()
        let corners: [SIMD2<Float>] = [SIMD2(8, 0), SIMD2(0, 6), SIMD2(-8, 0), SIMD2(0, -6)]
        let segments = (0..<80).map { corners[$0 % 4] }
        effects.emit(from: .zero, segments: segments, level: level, root: root, interval: 1.0 / 120)
        XCTAssertGreaterThan(effects.activeParticleCount, 0)
        XCTAssertLessThanOrEqual(effects.activeParticleCount, MazeBallTrailEffects.maxEmissionsPerFrame)
        for _ in 0..<12 {
            effects.advance(by: 1.0 / 120)
            effects.emit(from: .zero, segments: segments, level: level, root: root, interval: 1.0 / 120)
        }
        let allocated = Set(particles(in: root).map(ObjectIdentifier.init))
        XCTAssertLessThanOrEqual(allocated.count, MazeBallTrailEffects.capacity)
        for _ in 0..<120 {
            effects.advance(by: 1.0 / 120)
            effects.emit(from: .zero, segments: segments, level: level, root: root, interval: 1.0 / 120)
            XCTAssertLessThanOrEqual(effects.activeParticleCount, MazeBallTrailEffects.capacity)
            XCTAssertTrue(Set(particles(in: root).map(ObjectIdentifier.init)).isSubset(of: allocated),
                          "Continuous movement allocated more particle nodes")
            XCTAssertEqual(effects.preparationResources.compactMap { $0 as? SCNGeometry }.map(ObjectIdentifier.init), resourceIDs)
        }
        effects.reset()
        XCTAssertFalse(effects.hasParticles)
        XCTAssertEqual(effects.activeParticleCount, 0)
        XCTAssertTrue(visibleParticles(in: root).isEmpty)
    }

    func testRenderEveryBallTrailForVisualReview() async throws {
        let cellSize = CGSize(width: 360, height: 296)
        let viewport = CGSize(width: cellSize.width, height: cellSize.height - 36)
        var previews: [(String, UIImage)] = []
        for skin in BallSkin.catalog {
            let renderer = MazeSceneRenderer()
            let runID = UUID()
            var run = MazeRun(level: trailLevel(width: 7, height: 5))
            await prepare(renderer, run: run, runID: runID, skin: skin)
            renderer.resize(to: viewport)
            move(.right, run: &run, renderer: renderer, runID: runID)
            for _ in 0..<10 { renderer.advance(by: 1.0 / 120) }
            XCTAssertFalse(visibleParticles(in: renderer.scene.rootNode).isEmpty, skin.name)
            let snapshotter = SCNRenderer(device: nil, options: nil)
            snapshotter.scene = renderer.scene
            snapshotter.pointOfView = renderer.cameraNode
            let prepared = await withCheckedContinuation { continuation in
                snapshotter.prepare(renderer.preparationResources) { success in
                    continuation.resume(returning: success)
                }
            }
            XCTAssertTrue(prepared, "SceneKit could not prepare \(skin.name) for its snapshot")
            let snapshot = snapshotter.snapshot(atTime: 1, with: viewport, antialiasingMode: .multisampling4X)
            previews.append((skin.name, snapshot))
            print("PRISM_BALL_TRAIL_CAPTURE=\(skin.id)")
            renderer.stop()
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let montage = UIGraphicsImageRenderer(size: CGSize(width: cellSize.width * 4, height: cellSize.height * 3), format: format).image { context in
            UIColor(red: 0.94, green: 0.96, blue: 1, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: cellSize.width * 4, height: cellSize.height * 3))
            for (index, preview) in previews.enumerated() {
                let origin = CGPoint(x: CGFloat(index % 4) * cellSize.width, y: CGFloat(index / 4) * cellSize.height)
                preview.1.draw(in: CGRect(origin: origin, size: viewport))
                let label = NSAttributedString(string: preview.0, attributes: [
                    .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.12, green: 0.18, blue: 0.3, alpha: 1)
                ])
                label.draw(at: CGPoint(x: origin.x + (cellSize.width - label.size().width) / 2, y: origin.y + viewport.height + 4))
            }
        }
        let attachment = XCTAttachment(image: montage)
        attachment.name = "All twelve moving ball trails"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prismroll-ball-trails.png")
        try XCTUnwrap(montage.pngData()).write(to: url)
        print("PRISM_BALL_TRAILS_MONTAGE=\(url.path)")
    }

    private func prepare(_ renderer: MazeSceneRenderer, run: MazeRun, runID: UUID,
                         skin: BallSkin = BallSkin.catalog[0]) async {
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let ready = expectation(description: "\(skin.name) materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted, skin: skin,
                        isComplete: run.isComplete, resetID: runID)
        await fulfillment(of: [ready], timeout: 10)
        renderer.onResourcesReady = nil
    }

    private func move(_ direction: MoveDirection, run: inout MazeRun, renderer: MazeSceneRenderer, runID: UUID) {
        let start = run.position
        let path = run.move(direction)
        XCTAssertFalse(path.isEmpty)
        renderer.receive(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                       painted: run.painted, isComplete: run.isComplete, moves: run.moves))
    }

    private func particles(in root: SCNNode) -> [SCNNode] {
        var nodes: [SCNNode] = []
        root.enumerateChildNodes { node, _ in
            if node.name == "ball-trail-particle" { nodes.append(node) }
        }
        return nodes
    }

    private func visibleParticles(in root: SCNNode) -> [SCNNode] {
        particles(in: root).filter { !$0.isHidden && $0.opacity > 0.0001 }
    }

    private func assertInsideCorridor(_ particle: SCNNode, root: SCNNode, level: MazeLevel,
                                      file: StaticString = #filePath, line: UInt = #line) {
        let world = particle.convertPosition(SCNVector3Zero, to: root)
        let column = world.x + Float(level.width - 1) / 2
        let row = world.z + Float(level.height - 1) / 2
        let cell = GridCell(row: Int(row.rounded()), column: Int(column.rounded()))
        XCTAssertTrue(level.openCells.contains(cell), "A trail cut across a closed cell at \(column), \(row)", file: file, line: line)
    }

    private func trailLevel(width: Int = 9, height: Int = 5) -> MazeLevel {
        let cells = Set((0..<height).flatMap { row in
            (0..<width).compactMap { column in
                row == 0 || row == height - 1 || column == 0 || column == width - 1
                    ? GridCell(row: row, column: column) : nil
            }
        })
        return MazeLevel(number: 1, mode: .endless, width: width, height: height, openCells: cells,
                         start: GridCell(row: 0, column: 0), solution: [.right, .down, .left, .up], moveLimit: nil)
    }
}
#endif
