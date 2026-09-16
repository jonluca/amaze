import Foundation

/// Only this player's earned counters and acknowledged reports belong in this record.
struct GameCenterAccountProgress: Codable, Equatable {
    var progress: GameCenterProgressSnapshot = .empty
    var reportedAchievements: [String: Double] = [:]
    var reportedScores: [String: Int] = [:]
    var bannerEligibleAchievements: Set<String> = []
}
