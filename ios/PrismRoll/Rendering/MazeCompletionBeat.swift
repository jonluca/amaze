import Foundation

/// A short rendered celebration precedes automatic progression. The scene's
/// display clock owns elapsed time, so menus and backgrounding pause the beat.
struct MazeCompletionBeat {
    static let duration: TimeInterval = 0.54
    private(set) var hasStarted = false
    private(set) var remaining: TimeInterval = 0
    var isPlaying: Bool { remaining > 0 }

    mutating func begin() -> Bool {
        guard !hasStarted else { return false }
        hasStarted = true
        remaining = Self.duration
        return true
    }

    mutating func advance(by interval: TimeInterval) {
        guard interval.isFinite, interval > 0 else { return }
        remaining = max(0, remaining - interval)
        if remaining < 0.000_001 { remaining = 0 }
    }
}
