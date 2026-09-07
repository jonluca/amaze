import Foundation

struct GameSnapshot: Codable {
    var progress: ProgressData
    var runs: [String: MazeRun]
    var clocks: [String: TimedRunState]
    var mode: GameMode
    var dailyRun: MazeRun?
    var dailyID: String?
    var dailyActive: Bool
    var themeID: String
    var timeRushSession: TimeRushSession? = nil
}
