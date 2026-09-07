import Combine
import SceneKit
import SwiftUI

/// A persistent 3D board. SwiftUI owns the game state; SceneKit only presents it.
@MainActor
struct MazeSceneView: UIViewRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    let level: MazeLevel
    let position: GridCell
    let painted: Set<GridCell>
    let skin: BallSkin
    let isComplete: Bool
    var isFailed = false
    var moveCount: Int? = nil
    var theme: BoardTheme = .aurora
    var resetID: UUID? = nil
    var isActive = true
    var moveEvents: AnyPublisher<GameMoveEvent, Never>? = nil
    var onReady: (Bool) -> Void = { _ in }
    var onResultReady: () -> Void = {}
    let onSwipe: (MoveDirection) -> Void

    func makeCoordinator() -> MazeSceneCoordinator {
        MazeSceneCoordinator(onSwipe: onSwipe)
    }

    func makeUIView(context: Context) -> MazeCanvasView {
        let view = MazeCanvasView()
        context.coordinator.configure(view)
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: MazeCanvasView, context: Context) {
        context.coordinator.onSwipe = onSwipe
        context.coordinator.onReady = onReady
        context.coordinator.onResultReady = onResultReady
        context.coordinator.bind(moveEvents, runID: resetID)
        context.coordinator.setActive(isActive)
        context.coordinator.renderer.setReduceMotion(reduceMotion)
        context.coordinator.renderer.setDifferentiateWithoutColor(differentiateWithoutColor)
        context.coordinator.renderer.update(
            level: level,
            position: position,
            painted: painted,
            skin: skin,
            isComplete: isComplete,
            isFailed: isFailed,
            moveCount: moveCount,
            theme: theme,
            resetID: resetID
        )
        context.coordinator.publishReadiness()
        context.coordinator.publishResultIfReady()
        view.accessibilityValue = "Row \(position.row + 1), column \(position.column + 1). \(painted.count) of \(level.openCells.count) squares painted."
        if isComplete { view.accessibilityHint = "Level complete." }
        else if isFailed { view.accessibilityHint = "Run ended." }
        else { view.accessibilityHint = "Swipe to roll the ball. Use the move actions with VoiceOver." }
    }

    static func dismantleUIView(_ view: MazeCanvasView, coordinator: MazeSceneCoordinator) {
        coordinator.stop()
        coordinator.onSwipe = { _ in }
        view.onLayout = nil
        view.onVisibilityChange = nil
        view.delegate = nil
        view.setPreparing(false)
        view.isPlaying = false
        view.accessibilityCustomActions = nil
        view.scene = nil
        view.pointOfView = nil
    }
}
