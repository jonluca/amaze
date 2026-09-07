import Foundation

/// Recognizes one direction as soon as a finger travels far enough, before lift-off.
struct SwipeStroke {
    private let origin: CGPoint
    private(set) var hasEmitted = false
    static let threshold: CGFloat = 8

    init(origin: CGPoint) {
        self.origin = origin
    }

    mutating func direction(at point: CGPoint) -> MoveDirection? {
        guard !hasEmitted else { return nil }
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let horizontal = abs(dx)
        let vertical = abs(dy)
        guard max(horizontal, vertical) >= Self.threshold else { return nil }
        // A diagonal needs a clear axis; finger jitter and taps never create moves.
        guard max(horizontal, vertical) >= min(horizontal, vertical) * 1.15 else { return nil }
        hasEmitted = true
        return horizontal > vertical ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
    }
}
