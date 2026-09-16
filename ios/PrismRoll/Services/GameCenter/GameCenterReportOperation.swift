import Foundation

enum GameCenterReportOperation: Equatable, Sendable {
    case achievement(id: String, percent: Double, showBanner: Bool)
    case leaderboard(id: String, score: Int)

    var resourceKey: String {
        switch self {
        case .achievement(let id, _, _): "achievement:\(id)"
        case .leaderboard(let id, _): "leaderboard:\(id)"
        }
    }
}
