#if canImport(UIKit) && canImport(SceneKit)
import SceneKit
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class MazeMotionPolishVisualTests: XCTestCase {
    func testRenderMotionAndCompletionStatesForVisualReview() async throws {
        let viewport = CGSize(width: 480, height: 384)
        let renderer = MazeSceneRenderer()
        defer { renderer.stop() }
        let runID = UUID()
        var run = MazeRun(level: loopLevel())
        await prepare(renderer, run: run, runID: runID)
        renderer.resize(to: viewport)
        renderer.scene.background.contents = UIColor(red: 0.94, green: 0.96, blue: 1, alpha: 1)
        let snapshotter = SCNRenderer(device: nil, options: nil)
        snapshotter.scene = renderer.scene
        snapshotter.pointOfView = renderer.cameraNode
        let prepared = await withCheckedContinuation { continuation in
            snapshotter.prepare(renderer.preparationResources) { success in
                continuation.resume(returning: success)
            }
        }
        XCTAssertTrue(prepared)
        let impact = try XCTUnwrap(renderer.scene.rootNode.childNode(withName: "ball-impact", recursively: true))
        var clock: TimeInterval = 0
        var previews: [(String, UIImage)] = []
        _ = snapshotter.snapshot(atTime: clock, with: viewport, antialiasingMode: .multisampling4X)

        move(.right, run: &run, renderer: renderer, runID: runID)
        advance(renderer, by: 0.05, clock: &clock)
        XCTAssertGreaterThan(renderer.pendingMoveCount, 0)
        XCTAssertTrue(visibleNodes(named: "ball-trail-particle", in: renderer.scene.rootNode).count > 0)
        capture("Trail · swipe +0.050 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)

        advance(renderer, by: 0.05, clock: &clock)
        XCTAssertEqual(renderer.pendingMoveCount, 0)
        XCTAssertLessThan(impact.scale.x, 0.8, "Capture the peak horizontal wall compression")
        capture("Wall squash · arrival +0.000 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)
        print("PRISM_MOTION_IMPACT time=\(clock) scale=\(impact.simdScale)")

        advance(renderer, by: 0.25, clock: &clock)
        XCTAssertEqual(impact.simdScale, SIMD3<Float>(repeating: 1))
        capture("Round again · arrival +0.250 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)

        for direction: MoveDirection in [.down, .left] {
            move(direction, run: &run, renderer: renderer, runID: runID)
            advance(renderer, by: 0.35, clock: &clock)
        }
        move(.up, run: &run, renderer: renderer, runID: runID)
        XCTAssertTrue(run.isComplete)
        XCTAssertTrue(renderer.isComplete)
        XCTAssertFalse(renderer.resultReady)
        renderer.celebrateCompletion()
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "completion-coins", recursively: true),
                     "An accepted completion must not celebrate before its last slide is rendered")
        for _ in 0..<30 where renderer.pendingMoveCount > 0 {
            advance(renderer, by: 1.0 / 120, clock: &clock)
        }
        XCTAssertTrue(renderer.resultReady)
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "completion-coins", recursively: true))
        renderer.celebrateCompletion()
        let completionClock = clock
        advance(renderer, by: 0.18, clock: &clock)
        XCTAssertEqual(visibleNodes(named: "completion-coin", in: renderer.scene.rootNode).count,
                       MazeCompletionCoinEffects.capacity)
        capture("Coin fan · completion +0.180 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)
        advance(renderer, by: 0.12, clock: &clock)
        capture("Coin spin · completion +0.300 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)
        XCTAssertEqual(clock - completionClock, 0.3, accuracy: 0.000_001)

        renderer.setReduceMotion(true)
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "completion-coins", recursively: true),
                     "Changing motion preferences must clear the moving burst")
        renderer.celebrateCompletion()
        let stationaryCoin = try XCTUnwrap(visibleNodes(named: "completion-coin", in: renderer.scene.rootNode).first)
        let stationaryPosition = stationaryCoin.simdPosition
        let stationaryScale = stationaryCoin.simdScale
        advance(renderer, by: 0.18, clock: &clock)
        XCTAssertEqual(visibleNodes(named: "completion-coin", in: renderer.scene.rootNode).count, 1)
        XCTAssertEqual(stationaryCoin.simdPosition, stationaryPosition)
        XCTAssertEqual(stationaryCoin.simdScale, stationaryScale)
        capture("Reduce Motion · completion +0.180 s", at: clock, renderer: snapshotter, viewport: viewport, previews: &previews)

        renderer.update(level: run.level, position: run.level.start, painted: [run.level.start],
                        skin: BallSkin.catalog[0], isComplete: false, resetID: UUID())
        XCTAssertNil(renderer.scene.rootNode.childNode(withName: "completion-coins", recursively: true),
                     "Replay must detach completion coins from the previous run")
        XCTAssertEqual(impact.simdScale, SIMD3<Float>(repeating: 1))
        try saveMontage(previews, viewport: viewport)
    }

    private func prepare(_ renderer: MazeSceneRenderer, run: MazeRun, runID: UUID) async {
        renderer.setReduceMotion(false)
        renderer.consumesMoveEvents = true
        let ready = expectation(description: "Motion review materials ready")
        renderer.onResourcesReady = { ready.fulfill() }
        renderer.update(level: run.level, position: run.position, painted: run.painted,
                        skin: BallSkin.catalog[0], isComplete: false, resetID: runID)
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

    private func advance(_ renderer: MazeSceneRenderer, by duration: TimeInterval, clock: inout TimeInterval) {
        var remaining = duration
        while remaining > 0.000_001 {
            let interval = min(1.0 / 120, remaining)
            renderer.advance(by: interval)
            remaining -= interval
            clock += interval
        }
    }

    private func visibleNodes(named name: String, in root: SCNNode) -> [SCNNode] {
        var nodes: [SCNNode] = []
        root.enumerateChildNodes { node, _ in
            if node.name == name, !node.isHidden, node.opacity > 0.0001 { nodes.append(node) }
        }
        return nodes
    }

    private func capture(_ label: String, at time: TimeInterval, renderer: SCNRenderer,
                         viewport: CGSize, previews: inout [(String, UIImage)]) {
        SCNTransaction.flush()
        let image = renderer.snapshot(atTime: time, with: viewport, antialiasingMode: .multisampling4X)
        let caption = "\(label)\nDisplay clock: \(String(format: "%.3f", time)) s"
        previews.append((caption, image))
        print("PRISM_MOTION_POLISH_CAPTURE=\(label) displayClock=\(time)")
    }

    private func saveMontage(_ previews: [(String, UIImage)], viewport: CGSize) throws {
        let cellSize = CGSize(width: viewport.width, height: 440)
        let size = CGSize(width: cellSize.width * 3, height: cellSize.height * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let montage = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.94, green: 0.96, blue: 1, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            for (index, preview) in previews.enumerated() {
                let origin = CGPoint(x: CGFloat(index % 3) * cellSize.width, y: CGFloat(index / 3) * cellSize.height)
                preview.1.draw(in: CGRect(origin: origin, size: viewport))
                let caption = NSAttributedString(string: preview.0, attributes: [
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: UIColor(red: 0.12, green: 0.18, blue: 0.3, alpha: 1),
                    .paragraphStyle: paragraph
                ])
                caption.draw(in: CGRect(x: origin.x + 8, y: origin.y + viewport.height + 5,
                                        width: cellSize.width - 16, height: 46))
            }
        }
        let attachment = XCTAttachment(image: montage)
        attachment.name = "Ball trail, wall squash, and completion coins at recorded display times"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("prismroll-motion-polish.png")
        try XCTUnwrap(montage.pngData()).write(to: url)
        print("PRISM_MOTION_POLISH_MONTAGE=\(url.path)")
    }

    private func loopLevel() -> MazeLevel {
        let width = 7
        let height = 5
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
