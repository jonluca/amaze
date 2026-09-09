import SceneKit

/// A small, prebuilt coin fan runs on the scene's display clock, so completing
/// a level never allocates meshes and pausing also pauses the celebration.
@MainActor
final class MazeCompletionCoinEffects {
    static let duration: TimeInterval = 0.54
    static let capacity = 9

    private let root = SCNNode()
    private let coins: [SCNNode]
    private let geometries: [SCNGeometry]
    private var elapsed: TimeInterval = 0
    private var reduceMotion = false
    private var horizontalBias: Float = 0
    private var riseScale: Float = 1
    private(set) var hasParticles = false

    var preparationResources: [Any] { geometries }

    init() {
        root.name = "completion-coins"
        root.castsShadow = false
        let template = MazeCoinBuilder.make()
        var prepared: [SCNGeometry] = []
        template.enumerateChildNodes { node, _ in
            node.castsShadow = false
            if let geometry = node.geometry { prepared.append(geometry) }
        }
        geometries = prepared
        coins = (0..<Self.capacity).map { _ in
            let coin = template.clone()
            coin.name = "completion-coin"
            coin.castsShadow = false
            coin.isHidden = true
            return coin
        }
        for coin in coins { root.addChildNode(coin) }
    }

    func setCameraOrientation(_ orientation: simd_quatf) {
        root.simdOrientation = orientation
    }

    func celebrate(at cell: GridCell, level: MazeLevel, root board: SCNNode, reduceMotion: Bool) {
        reset()
        self.reduceMotion = reduceMotion
        // Keep edge completions inside the camera's board margin. Coins still
        // leave the ball, with the fan opening toward the board's center.
        horizontalBias = level.width > 1
            ? (1 - 2 * Float(cell.column) / Float(level.width - 1)) * 0.85 : 0
        riseScale = 0.55 + 0.45 * min(1, Float(cell.row) / 1.5)
        hasParticles = true
        root.position = MazeBoardBuilder.position(of: cell, in: level)
        root.position.y = 0.58
        board.addChildNode(root)
        render()
    }

    func advance(by interval: TimeInterval) {
        guard hasParticles, interval.isFinite, interval > 0 else { return }
        elapsed = min(Self.duration, elapsed + interval)
        guard elapsed < Self.duration - 0.000_001 else {
            reset()
            return
        }
        render()
    }

    func reset() {
        root.removeFromParentNode()
        for coin in coins {
            coin.isHidden = true
            coin.opacity = 0
        }
        elapsed = 0
        hasParticles = false
    }

    private func render() {
        let progress = Float(elapsed / Self.duration)
        for (index, coin) in coins.enumerated() {
            if reduceMotion {
                // Keep the completion reward visible without movement, scaling,
                // or spinning when the player requests reduced motion.
                coin.isHidden = index != Self.capacity / 2
                if coin.isHidden { continue }
                coin.position = SCNVector3(0, 0.48, 0.12)
                coin.eulerAngles = SCNVector3Zero
                coin.simdScale = SIMD3(repeating: 0.95)
                coin.opacity = CGFloat(min(1, 0.15 + progress / 0.18) * min(1, (1 - progress) / 0.4))
                continue
            }

            let offset = Float(index - Self.capacity / 2)
            let delay = Double(abs(offset)) * 0.012
            guard elapsed >= delay else {
                coin.isHidden = true
                continue
            }
            coin.isHidden = false
            let phase = Float((elapsed - delay) / (Self.duration - delay))
            let spread = 1 - pow(1 - phase, 2)
            let height = 1.55 - abs(offset) * 0.12
            coin.position = SCNVector3(
                (offset * 0.33 + horizontalBias) * spread,
                0.1 + height * riseScale * sin(phase * .pi * 0.78),
                0.14 + abs(offset) * 0.012)
            let side: Float = index.isMultiple(of: 2) ? 1 : -1
            coin.eulerAngles = SCNVector3(
                0.2 * sin(phase * .pi),
                side * phase * .pi * 3.2,
                -offset * 0.08 * spread)
            let entrance = min(1, 0.4 + phase / 0.12)
            let shrink = 1 - 0.65 * max(0, (phase - 0.58) / 0.42)
            let size = (0.84 + Float(index % 3) * 0.08) * entrance * shrink
            coin.simdScale = SIMD3(repeating: size)
            let fadeIn = min(1, 0.18 + phase / 0.05)
            let fadeOut = min(1, (1 - phase) / 0.3)
            coin.opacity = CGFloat(fadeIn * fadeOut)
        }
    }
}
