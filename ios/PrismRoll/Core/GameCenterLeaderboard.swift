enum GameCenterLeaderboard: String, CaseIterable, Codable, Identifiable, Sendable {
    case classicCompleted = "classic_completed"
    case perfectCompleted = "perfect_completed"
    case limitedCompleted = "limited_completed"
    case rushCompleted = "rush_completed"
    case dailyCompleted = "daily_completed"

    var id: String { "com.jonluca.prismroll.leaderboard.\(rawValue)" }

    var title: String {
        switch self {
        case .classicCompleted: "Classic Mazes Completed"
        case .perfectCompleted: "Perfect Mazes"
        case .limitedCompleted: "Limited Moves Completed"
        case .rushCompleted: "Time Rush Completed"
        case .dailyCompleted: "Daily Mazes Completed"
        }
    }

    /// Every leaderboard is a cumulative count; App Store Connect keeps the best (highest) score.
    func score(in snapshot: GameCenterProgressSnapshot) -> Int {
        let count: Int
        switch self {
        case .classicCompleted: count = snapshot.classicCompleted
        case .perfectCompleted: count = snapshot.perfectCompleted
        case .limitedCompleted: count = snapshot.limitedCompleted
        case .rushCompleted: count = snapshot.rushCompleted
        case .dailyCompleted: count = snapshot.dailyCompleted
        }
        return max(0, count)
    }
}
