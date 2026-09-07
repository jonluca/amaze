import SceneKit
import UIKit

@MainActor
enum MazePaintEffects {
    static func splash(at cell: GridCell, level: MazeLevel, root: SCNNode, tint: UIColor, delay: TimeInterval) {
        let center = MazeBoardBuilder.position(of: cell, in: level)
        let material = BallMaterialFactory.paint(tint)
        for index in 0..<4 {
            let radius = CGFloat(0.035 + Double(index % 3) * 0.014)
            let geometry = SCNSphere(radius: radius)
            geometry.segmentCount = 8
            let droplet = SCNNode(geometry: geometry)
            droplet.geometry?.materials = [material]
            droplet.name = "paint-effect"
            let angle = Float(index) * 1.9 + Float(cell.row + cell.column)
            droplet.position = SCNVector3(center.x + cos(angle) * 0.18, 0.065, center.z + sin(angle) * 0.18)
            droplet.scale = SCNVector3(1, 0.5, 1)
            droplet.opacity = 0
            let up = SCNAction.moveBy(x: CGFloat(cos(angle)) * 0.08, y: 0.13, z: CGFloat(sin(angle)) * 0.08, duration: 0.14)
            up.timingMode = .easeOut
            let settle = SCNAction.group([.moveBy(x: 0, y: -0.13, z: 0, duration: 0.19), .scale(to: 0.03, duration: 0.19)])
            droplet.runAction(.sequence([.wait(duration: delay), .fadeIn(duration: 0.015), up, settle, .removeFromParentNode()]))
            root.addChildNode(droplet)
        }
        let rippleGeometry = SCNTorus(ringRadius: 0.15, pipeRadius: 0.008)
        rippleGeometry.ringSegmentCount = 24
        rippleGeometry.pipeSegmentCount = 4
        rippleGeometry.materials = [material]
        let ripple = SCNNode(geometry: rippleGeometry)
        ripple.name = "paint-effect"
        ripple.position = SCNVector3(center.x, 0.032, center.z)
        ripple.opacity = 0
        ripple.runAction(.sequence([.wait(duration: delay), .fadeOpacity(to: 0.55, duration: 0.015),
                                    .group([.scale(to: 2.6, duration: 0.32), .fadeOut(duration: 0.32)]), .removeFromParentNode()]))
        root.addChildNode(ripple)
    }

    static func celebrate(at cell: GridCell, level: MazeLevel, root: SCNNode, ball: SCNNode, tint: UIColor, delay: TimeInterval) {
        let lift = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.2)
        lift.timingMode = .easeOut
        let land = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.25)
        land.timingMode = .easeIn
        ball.runAction(.sequence([.wait(duration: delay), lift, land]), forKey: "celebrate")
        let origin = MazeBoardBuilder.position(of: cell, in: level)
        let colors = [tint, UIColor.white, BallMaterialFactory.color(hex: "FFD46B"), BallMaterialFactory.color(hex: "66E5EC")]
        for index in 0..<34 {
            let geometry = SCNBox(width: 0.05, height: 0.035, length: 0.12, chamferRadius: 0.008)
            geometry.materials = [BallMaterialFactory.paint(colors[index % colors.count])]
            let piece = SCNNode(geometry: geometry)
            piece.name = "celebration"
            piece.position = SCNVector3(origin.x, 0.3, origin.z)
            piece.opacity = 0
            let angle = Float(index) * 2.39996
            let distance = Float(0.85 + Double(index % 5) * 0.23)
            let target = SCNVector3(origin.x + cos(angle) * distance, Float(1.3 + Double(index % 4) * 0.21), origin.z + sin(angle) * distance)
            let fly = SCNAction.move(to: target, duration: 0.7)
            fly.timingMode = .easeOut
            piece.runAction(.sequence([.wait(duration: delay), .fadeIn(duration: 0.02),
                                      .group([fly, .rotateBy(x: 4, y: 3, z: 5, duration: 0.9)]),
                                      .fadeOut(duration: 0.3), .removeFromParentNode()]))
            root.addChildNode(piece)
        }
    }
}
