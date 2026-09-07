import SceneKit
import UIKit

@MainActor
final class MazeSceneRenderer {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    var onPreparationNeeded: (() -> Void)?
    var onResourcesReady: (() -> Void)?
    private(set) var resourcesReady = false
    private(set) var contentRevision = 0
    var consumesMoveEvents = false
    private var boardRoot = SCNNode()
    private let shadowMaterial = SCNMaterial()
    private let ballRoot = SCNNode()
    private let ball = SCNNode(geometry: SCNSphere(radius: 0.405))
    private let paintEffects = MazePaintEffects()
    var preparationResources: [Any] { [scene] + paintEffects.preparationResources }
    private var paintTiles: [GridCell: SCNNode] = [:]
    private var pathMarkers: [GridCell: SCNNode] = [:]
    private var coins: [GridCell: SCNNode] = [:]
    private var currentLevel: MazeLevel?
    private var currentTheme: BoardTheme?
    private var lastPosition: GridCell?
    private var lastPainted: Set<GridCell> = []
    private var lastResetID: UUID?
    private(set) var acceptedMoveCount = 0
    var pendingMoveCount: Int { motion.pendingMoveCount }
    var hasResult: Bool { wasComplete || wasFailed }
    var resultReady: Bool { hasResult && !motion.isMoving }
    var renderedCellPosition: SIMD2<Float> { motion.position }
    var renderedPainted: Set<GridCell> { motion.painted }
    var markedUnpaintedCells: Set<GridCell> { Set(pathMarkers.filter { !$0.value.isHidden }.keys) }
    private var skinID: String?
    private var paintTint = UIColor.systemPink
    private var wasComplete = false
    private var wasFailed = false
    private var viewportSize = CGSize(width: 360, height: 390)
    private var materialTask: Task<Void, Never>?
    private var motion = MazeMotionTimeline()
    private var reduceMotion = UIAccessibility.isReduceMotionEnabled
    private var differentiateWithoutColor = false

    init() { configureScene() }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0, size != viewportSize else { return }
        viewportSize = size
        frameBoard()
    }

    func setReduceMotion(_ enabled: Bool) {
        guard enabled != reduceMotion else { return }
        reduceMotion = enabled
        // A retained scene must react when the accessibility setting changes,
        // including movement and decorative actions already in flight.
        guard let position = lastPosition, let level = currentLevel else { return }
        snap(to: position, painted: lastPainted, level: level)
    }

    func setDifferentiateWithoutColor(_ enabled: Bool) {
        guard enabled != differentiateWithoutColor else { return }
        differentiateWithoutColor = enabled
        rebuildPathMarkers()
    }

    func update(level: MazeLevel, position proposedPosition: GridCell, painted proposedPainted: Set<GridCell>, skin: BallSkin,
                isComplete proposedCompletion: Bool, isFailed proposedFailure: Bool = false, moveCount: Int? = nil,
                theme: BoardTheme = .aurora, resetID: UUID? = nil) {
        let changedLayout = currentLevel?.number != level.number || currentLevel?.mode != level.mode
            || currentLevel?.openCells != level.openCells || currentLevel?.coinCells != level.coinCells
            || currentLevel?.width != level.width || currentLevel?.height != level.height
        let changedLevel = changedLayout || currentTheme != theme
        let changedRun = lastResetID != resetID
        let eventStateIsNewer = consumesMoveEvents && !changedRun && !changedLayout && acceptedMoveCount > 0
        let position = eventStateIsNewer ? lastPosition ?? proposedPosition : proposedPosition
        let painted = eventStateIsNewer ? lastPainted : proposedPainted
        let isComplete = eventStateIsNewer ? wasComplete : proposedCompletion
        // Failure also includes clock expiry and rewarded extensions, which
        // arrive through SwiftUI. Only apply it to the accepted move snapshot.
        let snapshotMatchesMove = moveCount.map { $0 == acceptedMoveCount }
            ?? (proposedPosition == lastPosition && proposedPainted == lastPainted)
        let isFailed = eventStateIsNewer && !snapshotMatchesMove ? wasFailed : proposedFailure
        let reset = changedRun || !lastPainted.isSubset(of: painted)
        let changedSkin = skinID != skin.id
        let needsPreparation = changedLevel || changedSkin || reset
        if needsPreparation {
            resourcesReady = false
            contentRevision += 1
            onPreparationNeeded?()
        }
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
            rebuildPathMarkers()
            frameBoard()
        }
        if changedSkin || changedLevel {
            skinID = skin.id
            paintEffects.setTint(paintTint)
            let material = BallMaterialFactory.paint(paintTint)
            for tile in paintTiles.values { tile.geometry?.materials = [material] }
        }
        if changedLevel || reset {
            if changedRun || changedLayout { acceptedMoveCount = 0 }
            snap(to: position, painted: painted, level: level)
        } else if !consumesMoveEvents, lastPosition != position || lastPainted != painted || isComplete != wasComplete {
            // Snapshot-only callers retain safe interruption semantics: only a
            // legal straight slide animates; a skipped turn snaps to its state.
            if !reduceMotion, let origin = lastPosition, let path = slide(from: origin, to: position, level: level) {
                motion.enqueue(MazeSceneMove(origin: origin, path: path, position: position, painted: painted, isComplete: isComplete))
            } else { snap(to: position, painted: painted, level: level) }
        }
        lastPosition = position
        lastPainted = painted
        lastResetID = resetID
        wasComplete = isComplete
        wasFailed = isFailed
        if needsPreparation { prepareMaterials(skin: skin, theme: theme) }
    }

    func receive(_ event: GameMoveEvent) {
        guard event.runID == lastResetID, event.moves > acceptedMoveCount, let level = currentLevel else { return }
        // Preserve every accepted event, rather than reconstructing turns from
        // SwiftUI's potentially coalesced final snapshot.
        guard event.start == lastPosition, event.path == slide(from: event.start, to: event.position, level: level) else {
            snap(to: event.position, painted: event.painted, level: level)
            record(event)
            return
        }
        if reduceMotion { snap(to: event.position, painted: event.painted, level: level) }
        else {
            motion.enqueue(MazeSceneMove(origin: event.start, path: event.path, position: event.position,
                                        painted: event.painted, isComplete: event.isComplete))
        }
        record(event)
    }

    func advance(by interval: TimeInterval) {
        guard resourcesReady, let level = currentLevel, motion.isMoving else { return }
        let frame = motion.advance(by: interval)
        SCNTransaction.begin()
        SCNTransaction.disableActions = true
        ballRoot.position = SCNVector3(motion.position.x - Float(level.width - 1) / 2, 0,
                                      motion.position.y - Float(level.height - 1) / 2)
        for delta in frame.rotations {
            let distance = simd_length(delta)
            if distance > 0.00001 {
                let turn = simd_quatf(angle: distance / 0.405, axis: SIMD3(delta.y / distance, 0, -delta.x / distance))
                ball.simdOrientation = turn * ball.simdOrientation
            }
        }
        for cell in frame.paintedCells {
            paintTiles[cell]?.opacity = 1
            pathMarkers[cell]?.isHidden = true
            if let coin = coins[cell], coin.opacity > 0 {
                coin.removeAllActions()
                coin.runAction(.group([.moveBy(x: 0, y: 0.35, z: 0, duration: 0.18), .fadeOut(duration: 0.18)]))
            }
        }
        SCNTransaction.commit()
        // A fast frame may cross several cells; a bounded, prepared splash pool
        // keeps the wet trail without uploading geometry during movement.
        if let cell = frame.paintedCells.last { paintEffects.splash(at: cell, level: level, root: boardRoot) }
        if let cell = frame.completedAt { paintEffects.celebrate(at: cell, level: level, root: boardRoot, ball: ball) }
    }

    func stop() {
        materialTask?.cancel()
        contentRevision += 1
        resourcesReady = false
        if let position = lastPosition, let level = currentLevel { snap(to: position, painted: lastPainted, level: level) }
    }

    private func record(_ event: GameMoveEvent) {
        acceptedMoveCount = event.moves
        lastPosition = event.position
        lastPainted = event.painted
        wasComplete = event.isComplete
        // New input proves an earlier failure was revived. Its new terminal
        // status, if any, arrives with the matching SwiftUI move count.
        wasFailed = false
    }

    private func snap(to position: GridCell, painted: Set<GridCell>, level: MazeLevel) {
        motion.reset(position: position, painted: painted)
        paintEffects.reset()
        ballRoot.removeAllActions()
        ball.removeAllActions()
        boardRoot.enumerateChildNodes { node, _ in node.removeAllActions() }
        ballRoot.position = MazeBoardBuilder.position(of: position, in: level)
        ball.position.y = 0.423
        ball.eulerAngles = SCNVector3(0.1, 0.4, -0.2)
        for (cell, tile) in paintTiles { tile.opacity = painted.contains(cell) ? 1 : 0 }
        for (cell, marker) in pathMarkers { marker.isHidden = painted.contains(cell) }
        for (cell, coin) in coins {
            let center = MazeBoardBuilder.position(of: cell, in: level)
            coin.position = SCNVector3(center.x, 0.39, center.z)
            coin.scale = SCNVector3(1, 1, 1)
            coin.opacity = painted.contains(cell) ? 0 : 1
            if !painted.contains(cell) { MazeCoinBuilder.animate(coin, reduceMotion: reduceMotion) }
        }
    }

    private func rebuildPathMarkers() {
        for marker in pathMarkers.values { marker.removeFromParentNode() }
        pathMarkers.removeAll()
        guard differentiateWithoutColor, let level = currentLevel else { return }
        pathMarkers = MazePathMarkerBuilder.make(level: level)
        for (cell, marker) in pathMarkers {
            // Queued input can be ahead of the visible ball. A marker disappears
            // only when that cell's paint is actually shown, including live toggles.
            marker.isHidden = motion.painted.contains(cell)
            boardRoot.addChildNode(marker)
        }
    }

    private func prepareMaterials(skin: BallSkin, theme: BoardTheme) {
        materialTask?.cancel()
        let revision = contentRevision
        materialTask = Task { [weak self] in
            let material = await BallMaterialFactory.make(for: skin)
            let shadow = await ProceduralTextures.shared.contactShadow()
            let timber = theme == .timber ? await ProceduralTextures.shared.timber() : nil
            guard !Task.isCancelled, let self, self.contentRevision == revision else { return }
            self.ball.geometry?.materials = [material]
            self.shadowMaterial.diffuse.contents = shadow
            for coin in self.coins.values {
                coin.childNode(withName: "coin-gold", recursively: false)?.geometry?.firstMaterial?.reflective.contents = material.reflective.contents
            }
            if let timber { self.boardRoot.childNode(withName: "sculpted-walls", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = timber }
            self.resourcesReady = true
            self.onResourcesReady?()
        }
    }

    private func configureScene() {
        MazeStudioLighting.configure(scene: scene, cameraNode: cameraNode)
        shadowMaterial.lightingModel = .constant
        shadowMaterial.diffuse.contents = UIColor.clear
        shadowMaterial.writesToDepthBuffer = false
        let contact = SCNNode(geometry: SCNPlane(width: 1.18, height: 1.18))
        contact.geometry?.materials = [shadowMaterial]
        contact.eulerAngles.x = -.pi / 2
        contact.position = SCNVector3(0.03, 0.03, 0.06)
        contact.castsShadow = false
        ballRoot.addChildNode(contact)
        (ball.geometry as? SCNSphere)?.segmentCount = 48
        ball.position.y = 0.423
        ball.castsShadow = true
        ballRoot.addChildNode(ball)
        scene.rootNode.addChildNode(ballRoot)
    }

    private func frameBoard() {
        guard let level = currentLevel else { return }
        cameraNode.camera?.orthographicScale = MazeCameraFraming.scale(width: level.width, height: level.height, viewport: viewportSize)
    }

    private func slide(from origin: GridCell, to target: GridCell, level: MazeLevel) -> [GridCell]? {
        let direction: MoveDirection
        if origin == target { return nil }
        if origin.row == target.row { direction = target.column > origin.column ? .right : .left }
        else if origin.column == target.column { direction = target.row > origin.row ? .down : .up }
        else { return nil }
        let path = MazeSolver.path(from: origin, direction: direction, in: level.openCells)
        return path.last == target ? path : nil
    }
}
