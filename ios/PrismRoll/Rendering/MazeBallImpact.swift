import Foundation
import simd

/// A wall-aligned deformation, independent of the ball's rolling orientation.
struct MazeBallImpact {
    static let duration = 0.24
    private var elapsed = Self.duration
    private var direction = SIMD2<Float>(1, 0)
    var isPlaying: Bool { elapsed < Self.duration }

    private var compression: Float {
        guard isPlaying else { return 0 }
        let progress = Float(elapsed / Self.duration)
        return 0.22 * cos(progress * .pi * 2.4) * pow(1 - progress, 2)
    }

    var scale: SIMD3<Float> {
        let along = 1 - compression
        let across = 1 / sqrt(along)
        return abs(direction.x) > abs(direction.y)
            ? SIMD3(along, across, across) : SIMD3(across, across, along)
    }

    var offset: SIMD3<Float> {
        let press = max(0, compression) * 0.20
        return SIMD3(direction.x * press, 0.405 * (scale.y - 1), direction.y * press)
    }

    mutating func begin(direction: SIMD2<Float>) {
        let length = simd_length(direction)
        guard length > 0, length.isFinite else { return }
        self.direction = direction / length
        elapsed = 0
    }

    mutating func advance(by interval: TimeInterval) {
        guard interval.isFinite, interval > 0 else { return }
        elapsed = min(Self.duration, elapsed + interval)
    }

    mutating func reset() { elapsed = Self.duration }
}
