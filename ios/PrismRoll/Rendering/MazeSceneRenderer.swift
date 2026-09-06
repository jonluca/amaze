import SceneKit
import UIKit

@MainActor
final class MazeSceneRenderer {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private var boardRoot = SCNNode()
    private let boardShadow = SCNNode(geometry: SCNPlane(width: 8, height: 8))
    private let ballRoot = SCNNode()
    private let ball = SCNNode(geometry: SCNSphere(radius: 0.405))
    private var paintTiles: [GridCell: SCNNode] = [:]
    private var coins: [GridCell: SCNNode] = [:]
    private var currentLevel: MazeLevel?
    private var currentTheme: BoardTheme?
    private var lastPosition: GridCell?
    private var lastPainted: Set<GridCell> = []
    private var displayedPosition: GridCell?
    private var displayedPainted: Set<GridCell> = []
    private var pendingMoves: [MazeSceneMove] = []
    private var isAnimating = false
    private var animationRevision = 0
    private var lastResetID: UUID?
    private var skinID: String?
    private var paintTint = UIColor.systemPink
    private var wasComplete = false
    private var viewportSize = CGSize(width: 360, height: 390)

    init() { configureScene() }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewportSize = size
        frameBoard()
    }

    func update(level: MazeLevel, position: GridCell, painted: Set<GridCell>, skin: BallSkin,
                isComplete: Bool, theme: BoardTheme = .aurora, resetID: UUID? = nil) {
        let changedLevel = currentLevel?.number != level.number || currentLevel?.mode != level.mode
            || currentLevel?.openCells != level.openCells || currentLevel?.coinCells != level.coinCells
            || currentLevel?.width != level.width || currentLevel?.height != level.height || currentTheme != theme
        let reset = lastResetID != resetID || !lastPainted.isSubset(of: painted)
        paintTint = BallMaterialFactory.color(hex: skin.hex)
        if changedLevel {
            boardRoot.removeFromParentNode()
            let board = MazeBoardBuilder.build(level: level, tint: paintTint, theme: theme)
            boardRoot = board.root
            paintTiles = board.paintTiles
            coins = board.coins
            scene.rootNode.addChildNode(boardRoot)
            currentLevel = level
            currentTheme = theme
            lastPosition = nil
            lastPainted = []
            wasComplete = false
            frameBoard()
        }
        if skinID != skin.id || changedLevel {
            skinID = skin.id
            ball.geometry?.materials = [BallMaterialFactory.make(for: skin)]
            let material = BallMaterialFactory.paint(paintTint)
            for tile in paintTiles.values { tile.geometry?.materials = [material] }
            if theme != .timber, let material = boardRoot.childNode(withName: "board-accent", recursively: false)?.geometry?.firstMaterial {
                material.diffuse.contents = paintTint
                material.emission.contents = paintTint
            }
        }
        if changedLevel || reset || UIAccessibility.isReduceMotionEnabled {
            stop()
            ballRoot.position = MazeBoardBuilder.position(of: position, in: level)
            ball.position.y = 0.423
            ball.eulerAngles = SCNVector3(0.1, 0.4, -0.2)
            updatePaint(painted, from: nil, duration: 0, reset: true)
            for (cell, coin) in coins {
                let center = MazeBoardBuilder.position(of: cell, in: level)
                coin.position = SCNVector3(center.x, 0.39, center.z)
                coin.scale = SCNVector3(1, 1, 1)
                coin.opacity = painted.contains(cell) ? 0 : 1
                if !painted.contains(cell) { MazeCoinBuilder.animate(coin) }
            }
            displayedPosition = position
            displayedPainted = painted
            for child in boardRoot.childNodes where child.name == "celebration" || child.name == "paint-effect" {
                child.removeFromParentNode()
            }
        } else if lastPosition != position || lastPainted != painted || isComplete != wasComplete {
            pendingMoves.append(MazeSceneMove(position: position, painted: painted, isComplete: isComplete))
            animateNextMove()
        }
        lastPosition = position
        lastPainted = painted
        lastResetID = resetID
        wasComplete = isComplete
    }

    func stop() {
        animationRevision += 1
        pendingMoves.removeAll()
        isAnimating = false
        ballRoot.removeAllActions()
        ball.removeAllActions()
        boardRoot.enumerateChildNodes { node, _ in node.removeAllActions() }
    }

    private func configureScene() {
        MazeStudioLighting.configure(scene: scene, cameraNode: cameraNode)
        let shadowMaterial = SCNMaterial()
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = ProceduralTextures.contactShadow()
        shadowMaterial.writesToDepthBuffer = false
        boardShadow.geometry?.materials = [shadowMaterial]
        boardShadow.eulerAngles.x = -.pi / 2
        boardShadow.position = SCNVector3(0.12, -0.43, 0.17)
        boardShadow.castsShadow = false
        scene.rootNode.addChildNode(boardShadow)
        let contact = SCNNode(geometry: SCNPlane(width: 1.18, height: 1.18))
        contact.geometry?.materials = [shadowMaterial]
        contact.eulerAngles.x = -.pi / 2
        contact.position = SCNVector3(0.03, 0.03, 0.06)
        contact.castsShadow = false
        ballRoot.addChildNode(contact)
        (ball.geometry as? SCNSphere)?.segmentCount = 80
        ball.position.y = 0.423
        ball.castsShadow = true
        ballRoot.addChildNode(ball)
        scene.rootNode.addChildNode(ballRoot)
    }

    private func frameBoard() {
        guard let level = currentLevel else { return }
        let aspect = viewportSize.width / viewportSize.height
        let vertical = CGFloat(level.height) * 0.89 + 1.05
        let horizontal = CGFloat(level.width) + 1.05
        cameraNode.camera?.orthographicScale = Double(max(vertical / 2, horizontal / (2 * aspect)))
        (boardShadow.geometry as? SCNPlane)?.width = CGFloat(level.width) + 1.7
        (boardShadow.geometry as? SCNPlane)?.height = CGFloat(level.height) + 1.7
    }

    private func animateNextMove() {
        guard !isAnimating, !pendingMoves.isEmpty, let level = currentLevel else { return }
        let move = pendingMoves.removeFirst()
        isAnimating = true
        let duration = animateBall(to: move.position, in: level)
        updatePaint(move.painted, from: displayedPosition, duration: duration, reset: false)
        displayedPosition = move.position
        displayedPainted = move.painted
        if move.isComplete {
            MazePaintEffects.celebrate(at: move.position, level: level, root: boardRoot, ball: ball, tint: paintTint, delay: duration)
        }
        if duration == 0 { isAnimating = false; animateNextMove() }
    }

    private func animateBall(to position: GridCell, in level: MazeLevel) -> TimeInterval {
        guard displayedPosition != position else { return 0 }
        let target = MazeBoardBuilder.position(of: position, in: level)
        guard let from = displayedPosition, canAnimateSlide(from: from, to: position, in: level) else {
            ballRoot.position = target
            return 0
        }
        let deltaX = target.x - ballRoot.position.x
        let deltaZ = target.z - ballRoot.position.z
        let distance = sqrt(deltaX * deltaX + deltaZ * deltaZ)
        let duration = min(0.44, max(0.14, Double(distance) * 0.075))
        let movement = SCNAction.move(to: target, duration: duration)
        movement.timingMode = .easeInEaseOut
        let revision = animationRevision
        ballRoot.runAction(movement, forKey: "move") { [weak self] in
            // SceneKit completes actions on its rendering thread.
            DispatchQueue.main.async {
                guard let self, self.animationRevision == revision else { return }
                self.isAnimating = false
                self.animateNextMove()
            }
        }
        if distance > 0.001 {
            let rotation = SCNAction.rotate(by: CGFloat(distance / 0.405),
                                             around: SCNVector3(deltaZ / distance, 0, -deltaX / distance), duration: duration)
            rotation.timingMode = .easeInEaseOut
            ball.runAction(rotation, forKey: "roll")
        }
        return duration
    }

    private func canAnimateSlide(from origin: GridCell, to target: GridCell, in level: MazeLevel) -> Bool {
        let direction: MoveDirection
        if origin.row == target.row { direction = target.column > origin.column ? .right : .left }
        else if origin.column == target.column { direction = target.row > origin.row ? .down : .up }
        else { return false }
        return MazeSolver.path(from: origin, direction: direction, in: level.openCells).last == target
    }

    private func updatePaint(_ painted: Set<GridCell>, from origin: GridCell?, duration: TimeInterval, reset: Bool) {
        if reset {
            for (cell, tile) in paintTiles { tile.removeAllActions(); tile.opacity = painted.contains(cell) ? 1 : 0 }
            return
        }
        let sorted = painted.subtracting(displayedPainted).sorted { first, second in
            guard let origin else { return first.row * 100 + first.column < second.row * 100 + second.column }
            return abs(first.row - origin.row) + abs(first.column - origin.column)
                < abs(second.row - origin.row) + abs(second.column - origin.column)
        }
        for (index, cell) in sorted.enumerated() {
            guard let tile = paintTiles[cell] else { continue }
            let delay = duration * Double(index) / Double(max(1, sorted.count))
            tile.removeAllActions()
            if duration == 0 { tile.opacity = 1 }
            else {
                tile.runAction(.sequence([.wait(duration: delay), .fadeIn(duration: 0.055)]))
                if let level = currentLevel { MazePaintEffects.splash(at: cell, level: level, root: boardRoot, tint: paintTint, delay: delay) }
            }
            if let coin = coins[cell] {
                coin.removeAllActions()
                coin.runAction(.sequence([.wait(duration: delay), .group([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.22),
                                                                         .scale(to: 1.35, duration: 0.22), .fadeOut(duration: 0.22)])]))
            }
        }
    }
}
