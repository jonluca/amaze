import SceneKit
import UIKit

@MainActor
enum MazeCoinBuilder {
    static func make() -> SCNNode {
        let root = SCNNode()
        let gold = BallMaterialFactory.paint(BallMaterialFactory.color(hex: "FFD46B"))
        gold.specular.intensity = 0.9
        gold.reflective.intensity = 0.2
        let cylinder = SCNCylinder(radius: 0.23, height: 0.075)
        cylinder.radialSegmentCount = 36
        cylinder.materials = [gold]
        let face = SCNNode(geometry: cylinder)
        face.name = "coin-gold"
        face.eulerAngles.x = .pi / 2
        root.addChildNode(face)
        let ring = SCNTorus(ringRadius: 0.18, pipeRadius: 0.012)
        ring.materials = [MazeBoardBuilder.matte(BallMaterialFactory.color(hex: "A86B12"))]
        let ringNode = SCNNode(geometry: ring)
        ringNode.eulerAngles.x = .pi / 2
        ringNode.position.z = 0.041
        root.addChildNode(ringNode)
        let star = SCNText(string: "+", extrusionDepth: 0.006)
        star.font = UIFont.systemFont(ofSize: 0.31, weight: .black)
        star.flatness = 0.2
        star.materials = [MazeBoardBuilder.matte(BallMaterialFactory.color(hex: "B47D20"))]
        let symbol = SCNNode(geometry: star)
        let bounds = star.boundingBox
        symbol.position = SCNVector3(-(bounds.max.x + bounds.min.x) / 2, -(bounds.max.y + bounds.min.y) / 2, 0.042)
        root.addChildNode(symbol)
        return root
    }

    static func animate(_ root: SCNNode, reduceMotion: Bool) {
        root.removeAction(forKey: "coin-bob")
        root.removeAction(forKey: "coin-spin")
        root.eulerAngles = SCNVector3(-0.4, 0, 0)
        if !reduceMotion {
            let rise = SCNAction.moveBy(x: 0, y: 0.07, z: 0, duration: 0.75)
            rise.timingMode = .easeInEaseOut
            root.runAction(.repeatForever(.sequence([rise, rise.reversed()])), forKey: "coin-bob")
            root.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.8)), forKey: "coin-spin")
        }
    }
}
