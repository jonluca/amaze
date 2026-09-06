import Foundation

struct TimedRunState: Codable, Equatable {
    var remainingSeconds: TimeInterval
    var hasStarted = false
    var rewardedExtensions = 0

    mutating func consume(_ seconds: TimeInterval) {
        guard hasStarted, seconds.isFinite, seconds > 0 else { return }
        remainingSeconds = max(0, remainingSeconds - seconds)
    }

    mutating func extend(by seconds: TimeInterval) {
        guard seconds.isFinite, seconds > 0 else { return }
        remainingSeconds += seconds
        rewardedExtensions += 1
    }
}
