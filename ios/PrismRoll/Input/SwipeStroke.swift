import Foundation

/// Recognizes the opening swipe and subsequent turns without requiring lift-off.
struct SwipeStroke {
    private var origin: CGPoint
    private var lastDirection: MoveDirection?
    var hasEmitted: Bool { lastDirection != nil }
    static let threshold: CGFloat = 8
    private static let turnThreshold: CGFloat = 24

    init(origin: CGPoint) {
        self.origin = origin
    }

    mutating func direction(at point: CGPoint) -> MoveDirection? {
        recognize(at: point, requiresClearAxis: true)
    }

    mutating func finish(at point: CGPoint) -> MoveDirection? {
        // Once a swipe has fired, lift-off only ends it. The contact can jump
        // as the finger leaves the glass; that is not another deliberate turn.
        guard !hasEmitted else { return nil }
        // A fast diagonal may lift before a clear-axis sample arrives. Resolve
        // its dominant direction instead of throwing away the entire flick.
        return recognize(at: point, requiresClearAxis: false)
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
        if hasEmitted {
            // Keep the opening flick light, but require a deliberate segment
            // to turn. Thumb hooks and near-diagonal drift must not add moves.
            let dominant = max(horizontal, vertical)
            let minor = min(horizontal, vertical)
            guard dominant >= minor * 2 else {
                // Follow uncertain diagonal travel without changing direction,
                // so the next clear corner starts from the finger's new position.
                if dx * dx + dy * dy >= Self.threshold * Self.threshold {
                    origin = point
                }
                return nil
            }
            guard dominant >= Self.turnThreshold else { return nil }
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
