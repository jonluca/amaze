import SceneKit
import UIKit

/// Prepares the complete effect budget before play, then recycles the oldest
/// splash. Fast painting never creates geometry, materials, or action graphs.
@MainActor
final class MazePaintEffects {
    static let splashCapacity = 8
    private let tintMaterial: SCNMaterial
    private let geometries: [SCNGeometry]
    private let splashRoots: [SCNNode]
    private let splashActions: [SCNAction]
    private let splashRemoval: SCNAction
    private let celebrationRoot: SCNNode
    private let celebrationActions: [SCNAction]
    private let celebrationRemoval: SCNAction
    private let ballCelebration: SCNAction
    private weak var celebratingBall: SCNNode?
    private var nextSplash = 0

    // Explicit resources include inactive, unattached pool members, so the
    // view's asynchronous prepare call uploads them before the first swipe.
    var preparationResources: [Any] { geometries }

    init(tint: UIColor = .systemPink) {
        let paint = BallMaterialFactory.paint(tint)
        tintMaterial = paint
        let spheres = (0..<3).map { index -> SCNSphere in
            let sphere = SCNSphere(radius: CGFloat(0.035 + Double(index) * 0.014))
            sphere.segmentCount = 8
            sphere.materials = [paint]
            return sphere
        }
        let ring = SCNTorus(ringRadius: 0.15, pipeRadius: 0.008)
        ring.ringSegmentCount = 24
        ring.pipeSegmentCount = 4
        ring.materials = [paint]
        let colors = [UIColor.white, BallMaterialFactory.color(hex: "FFD46B"), BallMaterialFactory.color(hex: "66E5EC")]
        let confettiMaterials = [paint] + colors.map { BallMaterialFactory.paint($0) }
        let boxes = confettiMaterials.map { material -> SCNBox in
            let box = SCNBox(width: 0.05, height: 0.035, length: 0.12, chamferRadius: 0.008)
            box.materials = [material]
            return box
        }
        geometries = (spheres as [SCNGeometry]) + [ring] + boxes

        splashRoots = (0..<Self.splashCapacity).map { _ in
            let root = SCNNode()
            root.name = "paint-effect"
            root.castsShadow = false
            for index in 0..<4 {
                let droplet = SCNNode(geometry: spheres[index % spheres.count])
                droplet.castsShadow = false
                root.addChildNode(droplet)
            }
            let ripple = SCNNode(geometry: ring)
            ripple.castsShadow = false
            root.addChildNode(ripple)
            return root
        }
        var dropletActions: [SCNAction] = []
        for index in 0..<4 {
            let angle = Float(index) * 1.9
            let rise = SCNAction.moveBy(x: CGFloat(cos(angle)) * 0.08, y: 0.13,
                                       z: CGFloat(sin(angle)) * 0.08, duration: 0.14)
            rise.timingMode = .easeOut
            let settle = SCNAction.group([.moveBy(x: 0, y: -0.13, z: 0, duration: 0.19),
                                          .scale(to: 0.03, duration: 0.19)])
            dropletActions.append(.sequence([.fadeIn(duration: 0.015), rise, settle]))
        }
        let rippleAction = SCNAction.sequence([.fadeOpacity(to: 0.55, duration: 0.015),
                                               .group([.scale(to: 2.6, duration: 0.32), .fadeOut(duration: 0.32)])])
        splashActions = dropletActions + [rippleAction]
        splashRemoval = .sequence([.wait(duration: 0.345), .removeFromParentNode()])

        let celebration = SCNNode()
        celebration.name = "celebration"
        celebration.castsShadow = false
        var confettiActions: [SCNAction] = []
        for index in 0..<34 {
            let piece = SCNNode(geometry: boxes[index % boxes.count])
            piece.castsShadow = false
            celebration.addChildNode(piece)
            let angle = Float(index) * 2.39996
            let distance = Float(0.85 + Double(index % 5) * 0.23)
            let target = SCNVector3(cos(angle) * distance, Float(1.3 + Double(index % 4) * 0.21), sin(angle) * distance)
            let fly = SCNAction.move(to: target, duration: 0.7)
            fly.timingMode = .easeOut
            confettiActions.append(.sequence([.fadeIn(duration: 0.02),
                                               .group([fly, .rotateBy(x: 4, y: 3, z: 5, duration: 0.9)]),
                                               .fadeOut(duration: 0.3)]))
        }
        celebrationRoot = celebration
        celebrationActions = confettiActions
        celebrationRemoval = .sequence([.wait(duration: 1.22), .removeFromParentNode()])
        let lift = SCNAction.moveBy(x: 0, y: 0.3, z: 0, duration: 0.2)
        lift.timingMode = .easeOut
        let land = SCNAction.moveBy(x: 0, y: -0.3, z: 0, duration: 0.25)
        land.timingMode = .easeIn
        ballCelebration = .sequence([lift, land])
    }

    func setTint(_ tint: UIColor) {
        tintMaterial.diffuse.contents = tint
        tintMaterial.emission.contents = tint
    }

    func splash(at cell: GridCell, level: MazeLevel, root board: SCNNode) {
        let root = splashRoots[nextSplash]
        nextSplash = (nextSplash + 1) % Self.splashCapacity
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        clear(root)
        root.position = MazeBoardBuilder.position(of: cell, in: level)
        root.eulerAngles = SCNVector3(0, -Float(cell.row + cell.column), 0)
        for (index, node) in root.childNodes.enumerated() {
            if index < 4 {
                let angle = Float(index) * 1.9
                node.position = SCNVector3(cos(angle) * 0.18, 0.065, sin(angle) * 0.18)
                node.scale = SCNVector3(1, 0.5, 1)
            } else {
                node.position = SCNVector3(0, 0.032, 0)
                node.scale = SCNVector3(1, 1, 1)
            }
            node.opacity = 0
            node.runAction(splashActions[index])
        }
        board.addChildNode(root)
        root.runAction(splashRemoval)
        SCNTransaction.commit()
    }

    func celebrate(at cell: GridCell, level: MazeLevel, root board: SCNNode, ball: SCNNode) {
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        clear(celebrationRoot)
        celebratingBall?.removeAction(forKey: "celebrate")
        celebratingBall = ball
        celebrationRoot.position = MazeBoardBuilder.position(of: cell, in: level)
        for (index, piece) in celebrationRoot.childNodes.enumerated() {
            piece.position = SCNVector3(0, 0.3, 0)
            piece.eulerAngles = SCNVector3Zero
            piece.opacity = 0
            piece.runAction(celebrationActions[index])
        }
        board.addChildNode(celebrationRoot)
        celebrationRoot.runAction(celebrationRemoval)
        ball.runAction(ballCelebration, forKey: "celebrate")
        SCNTransaction.commit()
    }

    func reset() {
        for root in splashRoots { clear(root) }
        clear(celebrationRoot)
        celebratingBall?.removeAction(forKey: "celebrate")
        celebratingBall = nil
        nextSplash = 0
    }

    private func clear(_ root: SCNNode) {
        root.removeAllActions()
        for node in root.childNodes { node.removeAllActions() }
        root.removeFromParentNode()
    }
}
