import SceneKit
import SwiftUI

/// A persistent 3D board. SwiftUI owns the game state; SceneKit only presents it.
@MainActor
struct MazeSceneView: UIViewRepresentable {
    let level: MazeLevel
    let position: GridCell
    let painted: Set<GridCell>
    let skin: BallSkin
    let isComplete: Bool
    var theme: BoardTheme = .aurora
    var resetID: UUID? = nil
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
        context.coordinator.renderer.update(
            level: level,
            position: position,
            painted: painted,
            skin: skin,
            isComplete: isComplete,
            theme: theme,
            resetID: resetID
        )
        context.coordinator.observeFirstFrame()
        view.accessibilityValue = "Row \(position.row + 1), column \(position.column + 1). \(painted.count) of \(level.openCells.count) squares painted."
        view.accessibilityHint = isComplete
            ? "Level complete."
            : "Swipe to roll the ball. Use the move actions with VoiceOver."
    }

    static func dismantleUIView(_ view: MazeCanvasView, coordinator: MazeSceneCoordinator) {
        coordinator.renderer.stop()
        coordinator.onSwipe = { _ in }
        view.onLayout = nil
        view.delegate = nil
        view.setPreparing(false)
        view.isPlaying = false
        view.accessibilityCustomActions = nil
        view.scene = nil
        view.pointOfView = nil
    }
}
