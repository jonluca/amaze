import SceneKit
import UIKit

/// A fixed sprite pool follows the rendered route, including turns crossed in
/// one frame. Geometry and textures are prepared before input becomes active.
@MainActor
final class MazeBallTrailEffects {
    static let capacity = 72
    static let maxEmissionsPerFrame = 36

    private struct Particle {
        let node: SCNNode
        var age: Double = 0
        var lifetime: Double = 0
        var origin = SIMD3<Float>.zero
        var velocity = SIMD3<Float>.zero
        var size: Float = 1
        var angle: Float = 0
        var spin: Float = 0
    }

    private let root = SCNNode()
    private var particles: [Particle] = []
    private var geometries: [SCNGeometry] = []
    private var style = BallTrailStyle.coral
    private var skinID: String?
    private var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))
    private var nextParticle = 0
    private var sequence = 0
    private var distanceSinceEmission: Float = 0
    private(set) var activeParticleCount = 0

    var hasParticles: Bool { activeParticleCount > 0 }
    var preparationResources: [Any] { geometries }

    init() {
        root.name = "ball-trail"
        root.castsShadow = false
        particles = (0..<Self.capacity).map { _ in
            let node = SCNNode()
            node.name = "ball-trail-particle"
            node.castsShadow = false
            node.isHidden = true
            root.addChildNode(node)
            return Particle(node: node)
        }
    }

    func setCameraOrientation(_ orientation: simd_quatf) {
        cameraOrientation = orientation
    }

    func setSkin(_ skin: BallSkin) {
        guard skinID != skin.id else { return }
        reset()
        skinID = skin.id
        style = BallTrailStyle(skin: skin)
        geometries = BallTrailTexture.make(for: style).map { texture in
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = texture
            material.writesToDepthBuffer = false
            material.blendMode = style.additive ? .add : .alpha
            let plane = SCNPlane(width: 1, height: 1)
            plane.materials = [material]
            return plane
        }
        for index in particles.indices {
            particles[index].node.geometry = geometries[index % geometries.count]
        }
    }

    func advance(by interval: TimeInterval) {
        guard interval.isFinite, interval > 0, hasParticles else { return }
        let step = min(interval, 1.0 / 15)
        for index in particles.indices where !particles[index].node.isHidden {
            particles[index].age += step
            if particles[index].age >= particles[index].lifetime {
                particles[index].node.isHidden = true
                activeParticleCount -= 1
            } else {
                render(index)
            }
        }
        if !hasParticles { root.removeFromParentNode() }
    }

    func emit(from origin: SIMD2<Float>, segments: [SIMD2<Float>], level: MazeLevel,
              root board: SCNNode, interval: TimeInterval) {
        guard skinID != nil, interval.isFinite, interval > 0 else { return }
        let totalDistance = segments.reduce(Float.zero) { $0 + simd_length($1) }
        guard totalDistance.isFinite, totalDistance > 0.00001 else { return }
        if root.parent !== board { board.addChildNode(root) }
        // Coalesced input can traverse an entire board in one frame. Increase
        // spacing for that frame instead of doing unbounded particle work.
        let spacing = max(style.spacing, totalDistance / Float(Self.maxEmissionsPerFrame))
        distanceSinceEmission = min(distanceSinceEmission, spacing)
        var cursor = origin
        var travelled: Float = 0
        var emitted = 0
        for segment in segments {
            let length = simd_length(segment)
            guard length > 0.00001 else { continue }
            let direction = segment / length
            var offset = spacing - distanceSinceEmission
            while offset <= length, emitted < Self.maxEmissionsPerFrame {
                let point = cursor + direction * offset
                let age = min(interval, 1.0 / 15) * Double(1 - (travelled + offset) / totalDistance)
                spawn(at: point, direction: direction, age: max(0, age), level: level)
                emitted += 1
                offset += spacing
            }
            distanceSinceEmission = (distanceSinceEmission + length).truncatingRemainder(dividingBy: spacing)
            travelled += length
            cursor += segment
        }
    }

    func reset() {
        for index in particles.indices {
            particles[index].node.isHidden = true
            particles[index].age = 0
        }
        root.removeFromParentNode()
        nextParticle = 0
        sequence = 0
        distanceSinceEmission = 0
        activeParticleCount = 0
    }

    private func spawn(at point: SIMD2<Float>, direction: SIMD2<Float>, age: Double, level: MazeLevel) {
        let index = nextParticle
        nextParticle = (nextParticle + 1) % Self.capacity
        sequence = (sequence + 1) % 4096
        // A repeatable low-discrepancy sequence avoids random allocation and
        // gives neighboring puffs different sizes, drift, and rotation.
        let variation = (Float(sequence) * 0.618034).truncatingRemainder(dividingBy: 1)
        let side: Float = sequence.isMultiple(of: 2) ? 1 : -1
        let lateral = SIMD2(-direction.y, direction.x)
        let location = point - direction * 0.16 + lateral * (side * 0.07)
        if particles[index].node.isHidden { activeParticleCount += 1 }
        particles[index].node.isHidden = false
        particles[index].age = age
        particles[index].lifetime = style.lifetime * Double(0.85 + variation * 0.3)
        particles[index].origin = SIMD3(location.x - Float(level.width - 1) / 2, 0.20,
                                        location.y - Float(level.height - 1) / 2)
        let drift = lateral * (side * style.spread) - direction * style.drift
        particles[index].velocity = SIMD3(drift.x, style.rise * (0.8 + variation * 0.4), drift.y)
        particles[index].size = style.size * (0.8 + variation * 0.4)
        particles[index].angle = variation * .pi * 2
        particles[index].spin = style.spin * side
        render(index)
    }

    private func render(_ index: Int) {
        let particle = particles[index]
        let age = Float(particle.age)
        let progress = min(1, age / Float(particle.lifetime))
        // Expand gently, float away from the roll, and dissolve. The short
        // entrance hides individual births without producing a solid ribbon.
        let scale = particle.size * (1 + (style.expansion - 1) * progress)
        particle.node.simdPosition = particle.origin + particle.velocity * age
        particle.node.simdScale = SIMD3(repeating: scale)
        particle.node.simdOrientation = cameraOrientation * simd_quatf(
            angle: particle.angle + particle.spin * age, axis: SIMD3(0, 0, 1))
        let fadeIn = min(1, age / 0.025 + 0.25)
        particle.node.opacity = CGFloat(0.82 * fadeIn * (1 - progress) * (1 - progress))
    }
}
