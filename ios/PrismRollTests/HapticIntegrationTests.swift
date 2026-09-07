#if canImport(UIKit) && canImport(SceneKit) && canImport(CoreHaptics)
import Combine
import UIKit
import XCTest
@testable import PrismRoll

@MainActor
final class HapticIntegrationTests: XCTestCase {
    private final class RecordingOutput: MazeHapticOutput {
        var onInterruption: (() -> Void)?
        var steps = 0
        var rolling: [Bool] = []
        var suspensions = 0

        func prepare() {}
        func setRolling(_ rolling: Bool) { self.rolling.append(rolling) }
        func playStep() { steps += 1 }
        func playCompletion() {}
        func stop() {}
        func suspend() { suspensions += 1 }
    }

    func testAcceptedReducedMotionMoveReachesHapticsOnceAndInactiveSceneStaysSilent() throws {
        let output = RecordingOutput()
        let coordinator = MazeSceneCoordinator(onSwipe: { _ in }, haptics: MazeHapticPlayer(output: output))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        let canvas = MazeCanvasView(frame: window.bounds)
        coordinator.configure(canvas)
        window.addSubview(canvas)
        defer {
            coordinator.stop()
            canvas.removeFromSuperview()
            window.isHidden = true
        }
        XCTAssertTrue(canvas.window === window)
        coordinator.configureFeedback(enabled: true, reduceMotion: true)
        coordinator.renderer.setReduceMotion(true)
        let events = PassthroughSubject<GameMoveEvent, Never>()
        let runID = UUID()
        coordinator.bind(events.eraseToAnyPublisher(), runID: runID)
        var run = MazeRun(level: .generate(number: 1, mode: .endless))
        coordinator.renderer.update(level: run.level, position: run.position, painted: run.painted,
                                    skin: BallSkin.catalog[0], isComplete: false, resetID: runID)

        let first = try moveEvent(run: &run, runID: runID)
        events.send(first)
        XCTAssertEqual(coordinator.renderer.acceptedMoveCount, 1)
        XCTAssertEqual(coordinator.renderer.pendingMoveCount, 0,
                       "Reduced Motion must not need an animated interval to provide move feedback")
        XCTAssertEqual(coordinator.renderer.renderedPainted, run.painted)
        XCTAssertEqual(output.steps, 1)
        XCTAssertTrue(output.rolling.isEmpty)

        events.send(first)
        let second = try moveEvent(run: &run, runID: runID)
        events.send(GameMoveEvent(runID: UUID(), start: second.start, path: second.path,
                                  position: second.position, painted: second.painted,
                                  isComplete: second.isComplete, moves: second.moves))
        XCTAssertEqual(coordinator.renderer.acceptedMoveCount, 1)
        XCTAssertEqual(output.steps, 1, "Duplicate or stale events cannot repeat tactile feedback")

        coordinator.setActive(false)
        events.send(second)
        XCTAssertEqual(coordinator.renderer.acceptedMoveCount, 2,
                       "Exercise a valid accepted event while presentation is inactive")
        XCTAssertEqual(coordinator.renderer.pendingMoveCount, 0)
        XCTAssertEqual(output.steps, 1, "Settings and backgrounding must suppress accepted-move feedback")
        XCTAssertEqual(output.suspensions, 1)
        XCTAssertTrue(output.rolling.isEmpty)
    }

    private func moveEvent(run: inout MazeRun, runID: UUID) throws -> GameMoveEvent {
        let direction = try XCTUnwrap(run.hintDirection)
        let start = run.position
        let path = run.move(direction)
        XCTAssertFalse(path.isEmpty)
        return GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                             painted: run.painted, isComplete: run.isComplete, moves: run.moves)
    }
}
#endif
