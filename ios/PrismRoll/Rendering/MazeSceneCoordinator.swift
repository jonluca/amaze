import SceneKit
import UIKit

@MainActor
final class MazeSceneCoordinator: NSObject {
    let renderer = MazeSceneRenderer()
    var onSwipe: (MoveDirection) -> Void
    private weak var canvasView: MazeCanvasView?

    init(onSwipe: @escaping (MoveDirection) -> Void) {
        self.onSwipe = onSwipe
    }

    func configure(_ view: MazeCanvasView) {
        canvasView = view
        view.setPreparing(true)
        view.scene = renderer.scene
        view.pointOfView = renderer.cameraNode
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true
        view.onLayout = { [weak self] size in
            self?.renderer.resize(to: size)
        }
        for direction: UISwipeGestureRecognizer.Direction in [.up, .down, .left, .right] {
            let gesture = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            gesture.direction = direction
            view.addGestureRecognizer(gesture)
        }
        view.isAccessibilityElement = true
        view.accessibilityLabel = "3D painting maze"
        view.accessibilityTraits = [.allowsDirectInteraction]
        view.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: "Roll up", target: self, selector: #selector(rollUp)),
            UIAccessibilityCustomAction(name: "Roll down", target: self, selector: #selector(rollDown)),
            UIAccessibilityCustomAction(name: "Roll left", target: self, selector: #selector(rollLeft)),
            UIAccessibilityCustomAction(name: "Roll right", target: self, selector: #selector(rollRight))
        ]
    }

    func observeFirstFrame() {
        guard let canvasView, canvasView.isPreparing else { return }
        canvasView.delegate = self
    }

    func receivedFirstFrame() {
        canvasView?.setPreparing(false)
        canvasView?.delegate = nil
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .up: onSwipe(.up)
        case .down: onSwipe(.down)
        case .left: onSwipe(.left)
        case .right: onSwipe(.right)
        default: break
        }
    }

    @objc private func rollUp() -> Bool { onSwipe(.up); return true }
    @objc private func rollDown() -> Bool { onSwipe(.down); return true }
    @objc private func rollLeft() -> Bool { onSwipe(.left); return true }
    @objc private func rollRight() -> Bool { onSwipe(.right); return true }
}
