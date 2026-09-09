import SceneKit
import UIKit

/// A fixed sprite pool follows the rendered route, including turns crossed in
/// one frame. Geometry and textures are prepared before input becomes active.
@MainActor
final class MazeBallTrailEffects {
    static let capacity = 72
    static let maxEmissionsPerFrame = 36

    private enum Kind { case wake, motif }

    private struct Particle {
        let node: SCNNode
        var kind = Kind.wake
        var age: Double = 0
        var lifetime: Double = 0
        var origin = SIMD3<Float>.zero
        var velocity = SIMD3<Float>.zero
        var size: Float = 1
        var angle: Float = 0
        var spin: Float = 0
        var heading = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
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
        geometries = BallTrailTexture.make(for: style).enumerated().map { index, texture in
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = texture
            material.writesToDepthBuffer = false
            material.blendMode = style.additive ? .add : .alpha
            let plane = SCNPlane(width: 1, height: 1)
            plane.name = index == 2 ? "ball-trail-wake" : "ball-trail-motif"
            plane.materials = [material]
            return plane
        }
        for index in particles.indices {
            let kind: Kind = index.isMultiple(of: 3) ? .motif : .wake
            particles[index].kind = kind
            particles[index].node.geometry = geometries[kind == .wake ? 2 : (index / 3) % 2]
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
        let isWake = particles[index].kind == .wake
        let location = point - direction * 0.18 + lateral * (isWake ? 0 : side * 0.045)
        if particles[index].node.isHidden { activeParticleCount += 1 }
        particles[index].node.isHidden = false
        particles[index].age = age
        particles[index].lifetime = style.lifetime * Double(isWake ? 0.68 : 0.90 + variation * 0.20)
        particles[index].origin = SIMD3(location.x - Float(level.width - 1) / 2, isWake ? 0.055 : 0.20,
                                        location.y - Float(level.height - 1) / 2)
        let drift = isWake ? -direction * 0.035
            : lateral * (side * style.spread) - direction * style.drift
        particles[index].velocity = SIMD3(drift.x, isWake ? 0 : style.rise * (0.8 + variation * 0.4), drift.y)
        particles[index].size = style.size * (isWake ? 1 : 0.85 + variation * 0.30)
        particles[index].angle = variation * .pi * 2
        particles[index].spin = style.spin * side
        particles[index].heading = simd_quatf(angle: atan2(direction.x, direction.y), axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: -.pi / 2, axis: SIMD3(1, 0, 0))
        render(index)
    }

    private func render(_ index: Int) {
        let particle = particles[index]
        let age = Float(particle.age)
        let progress = min(1, age / Float(particle.lifetime))
        // Decelerating drift keeps the tail close to its corridor. Interleaved
        // floor streaks overlap into a tapered wake; the skin's motifs float
        // above it instead of merging into a cloud that obscures the board.
        let driftTime = (1 - exp(-age * 3)) / 3
        particle.node.simdPosition = particle.origin + particle.velocity * driftTime
        let entrance = min(1, age / 0.035)
        let fadeIn = entrance * entrance * (3 - 2 * entrance)
        if particle.kind == .wake {
            let taper = 1 - progress * 0.82
            particle.node.simdScale = SIMD3(particle.size * 1.25 * taper,
                                            style.spacing * 3.8 * (1 - progress * 0.25), 1)
            particle.node.simdOrientation = particle.heading
            particle.node.opacity = CGFloat(0.72 * fadeIn * pow(1 - progress, 1.6))
        } else {
            let easeOut = 1 - (1 - progress) * (1 - progress)
            let scale = particle.size * (1 + (style.expansion - 1) * easeOut)
                * (1 - progress * 0.25)
            particle.node.simdScale = SIMD3(repeating: scale)
            particle.node.simdOrientation = cameraOrientation * simd_quatf(
                angle: particle.angle + particle.spin * driftTime, axis: SIMD3(0, 0, 1))
            particle.node.opacity = CGFloat(0.90 * fadeIn * pow(1 - progress, 1.45))
        }
    }
}
