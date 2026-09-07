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
        recognize(at: point, requiresClearAxis: true)
    }

    mutating func finish(at point: CGPoint) -> MoveDirection? {
        // A fast diagonal may lift before a clear-axis sample arrives. Resolve
        // its dominant direction instead of throwing away the entire flick.
        recognize(at: point, requiresClearAxis: false)
    }

    private mutating func recognize(at point: CGPoint, requiresClearAxis: Bool) -> MoveDirection? {
        guard !hasEmitted else { return nil }
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let horizontal = abs(dx)
        let vertical = abs(dy)
        // Sensitivity follows actual finger travel in every direction, rather
        // than making angled flicks travel farther than horizontal ones.
        guard dx * dx + dy * dy >= Self.threshold * Self.threshold else { return nil }
        // While the finger is down, wait for a clear axis so initial jitter
        // cannot choose a turn too early. Lift-off resolves any remaining tie.
        if requiresClearAxis && max(horizontal, vertical) < min(horizontal, vertical) * 1.15 { return nil }
        hasEmitted = true
        return horizontal > vertical ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
    }
}
