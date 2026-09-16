import Foundation

enum GameCenterDashboardDestination: Equatable {
    case achievements
    case leaderboards
    case leaderboard(GameCenterLeaderboard)
}
