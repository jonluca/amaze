import Foundation

/// Recognizes the opening swipe and subsequent turns without requiring lift-off.
struct SwipeStroke {
    private var origin: CGPoint
    private var lastDirection: MoveDirection?
    var hasEmitted: Bool { lastDirection != nil }
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
        // Once moving, a lift-off wobble must not invent another turn.
        recognize(at: point, requiresClearAxis: hasEmitted)
    }

    mutating func continueTracking(at point: CGPoint) {
        origin = point
    }

    private mutating func recognize(at point: CGPoint, requiresClearAxis: Bool) -> MoveDirection? {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let horizontal = abs(dx)
        let vertical = abs(dy)
        guard horizontal > 0 || vertical > 0 else { return nil }
        let direction: MoveDirection = horizontal > vertical
            ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
        if direction == lastDirection {
            // Follow ongoing travel so the next corner or reversal is measured
            // from here, even after a long drag away from the touch-down point.
            origin = point
            return nil
        }
        // Sensitivity follows actual finger travel in every direction, rather
        // than making angled flicks travel farther than horizontal ones.
        guard dx * dx + dy * dy >= Self.threshold * Self.threshold else { return nil }
        // Distance alone is not direction confidence: an initial (5, 7)
        // wobble must not lock a sideways flick vertically. Require one axis
        // to lead by the touch slop before committing while the finger is down.
        // Straight eight-point swipes still start immediately; short angled
        // flicks resolve their overall direction at lift-off.
        if requiresClearAxis && abs(horizontal - vertical) < Self.threshold { return nil }
        lastDirection = direction
        origin = point
        return direction
    }
}
