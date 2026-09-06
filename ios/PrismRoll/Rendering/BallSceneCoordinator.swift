import SceneKit
import UIKit

@MainActor
final class BallSceneCoordinator {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let sphere = SCNNode(geometry: SCNSphere(radius: 0.72))
    private var skinID: String?

    init() {
        MazeStudioLighting.configure(scene: scene, cameraNode: cameraNode, shadows: false)
        cameraNode.position = SCNVector3(0, 0.25, 4)
        cameraNode.look(at: SCNVector3Zero)
        cameraNode.camera?.orthographicScale = 0.88
        (sphere.geometry as? SCNSphere)?.segmentCount = 80
        sphere.eulerAngles = SCNVector3(0.25, 0.4, -0.2)
        scene.rootNode.addChildNode(sphere)
    }

    func update(skin: BallSkin, isAnimated: Bool) {
        if skinID != skin.id {
            skinID = skin.id
            sphere.geometry?.materials = [BallMaterialFactory.make(for: skin)]
        }
        let animate = isAnimated && !UIAccessibility.isReduceMotionEnabled
        if animate, sphere.action(forKey: "turntable") == nil {
            sphere.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 18)), forKey: "turntable")
        } else if !animate { sphere.removeAction(forKey: "turntable") }
    }

    func stop() { sphere.removeAllActions() }
}
