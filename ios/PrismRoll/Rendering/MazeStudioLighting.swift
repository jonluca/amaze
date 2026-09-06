import SceneKit
import UIKit

@MainActor
enum MazeStudioLighting {
    static func configure(scene: SCNScene, cameraNode: SCNNode, shadows: Bool = true) {
        scene.background.contents = UIColor.clear
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.zNear = 0.1
        camera.zFar = 100
        camera.wantsHDR = false
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 16, 8.6)
        cameraNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(red: 1, green: 0.97, blue: 0.95, alpha: 1)
        key.intensity = 760
        key.castsShadow = shadows
        key.shadowMode = .forward
        key.shadowColor = UIColor.black.withAlphaComponent(0.65)
        key.shadowRadius = 4
        key.shadowSampleCount = 16
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.automaticallyAdjustsShadowProjection = false
        key.orthographicScale = 12
        key.zNear = 1
        key.zFar = 40
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-6, 12, 5)
        keyNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .ambient
        fill.color = UIColor(red: 0.86, green: 0.91, blue: 1, alpha: 1)
        fill.intensity = 410
        let fillNode = SCNNode()
        fillNode.light = fill
        scene.rootNode.addChildNode(fillNode)

        let rim = SCNLight()
        rim.type = .omni
        rim.color = UIColor(red: 0.42, green: 0.68, blue: 1, alpha: 1)
        rim.intensity = 250
        rim.attenuationStartDistance = 4
        rim.attenuationEndDistance = 20
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(7, 4, -5)
        scene.rootNode.addChildNode(rimNode)
    }
}
