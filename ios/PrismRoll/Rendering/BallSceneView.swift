import SceneKit
import SwiftUI

@MainActor
struct BallSceneView: UIViewRepresentable {
    let skin: BallSkin
    var isAnimated = false

    func makeCoordinator() -> BallSceneCoordinator { BallSceneCoordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.cameraNode
        view.backgroundColor = .clear
        view.isOpaque = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.isUserInteractionEnabled = false
        updateUIView(view, context: context)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.update(skin: skin, isAnimated: isAnimated)
        view.isPlaying = isAnimated && !UIAccessibility.isReduceMotionEnabled
    }

    static func dismantleUIView(_ view: SCNView, coordinator: BallSceneCoordinator) {
        coordinator.stop()
        view.isPlaying = false
        view.scene = nil
        view.pointOfView = nil
    }
}
