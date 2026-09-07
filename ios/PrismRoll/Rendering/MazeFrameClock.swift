import Foundation

/// Advances custom motion to the frame being displayed, including refresh-rate changes.
struct MazeFrameClock {
    private var lastTargetTimestamp: TimeInterval?

    mutating func reset() { lastTargetTimestamp = nil }

    mutating func interval(timestamp: TimeInterval, targetTimestamp: TimeInterval) -> TimeInterval {
        guard timestamp.isFinite, targetTimestamp.isFinite, targetTimestamp > timestamp else { return 0 }
        if let previous = lastTargetTimestamp, targetTimestamp <= previous { return 0 }
        let interval = targetTimestamp - (lastTargetTimestamp ?? timestamp)
        lastTargetTimestamp = targetTimestamp
        return interval
    }
}
