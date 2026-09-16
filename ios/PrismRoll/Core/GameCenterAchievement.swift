enum GameCenterAchievement: String, CaseIterable, Codable, Identifiable, Sendable {
    case firstMaze = "first_maze"
    case classic25 = "classic_25"
    case classic100 = "classic_100"
    case classic500 = "classic_500"
    case perfect1 = "perfect_1"
    case perfect25 = "perfect_25"
    case perfect100 = "perfect_100"
    case limited25 = "limited_25"
    case rush10 = "rush_10"
    case daily1 = "daily_1"
    case daily7 = "daily_7"
    case coins100 = "coins_100"

    var id: String { "com.jonluca.prismroll.achievement.\(rawValue)" }

    var title: String {
        switch self {
        case .firstMaze: "First Light"
        case .classic25: "Finding Flow"
        case .classic100: "Maze Voyager"
        case .classic500: "Prism Master"
        case .perfect1: "Perfect Line"
        case .perfect25: "Pure Precision"
        case .perfect100: "Flawless Form"
        case .limited25: "Move Maestro"
        case .rush10: "Against the Clock"
        case .daily1: "Daily Spark"
        case .daily7: "Daily Explorer"
        case .coins100: "Pocketful of Prisms"
        }
    }

    var unachievedDescription: String {
        switch self {
        case .firstMaze: "Complete your first Classic maze."
        case .classic25: "Complete 25 different Classic mazes."
        case .classic100: "Complete 100 different Classic mazes."
        case .classic500: "Complete 500 different Classic mazes."
        case .perfect1: "Earn a Perfect solve on a regular level."
        case .perfect25: "Earn Perfect solves on 25 different regular levels."
        case .perfect100: "Earn Perfect solves on 100 different regular levels."
        case .limited25: "Complete 25 different Limited Moves levels."
        case .rush10: "Complete 10 different Time Rush rounds."
        case .daily1: "Complete your first daily maze."
        case .daily7: "Complete 7 different daily mazes. Consecutive days are not required."
        case .coins100: "Pick up 100 coins inside mazes."
        }
    }

    var achievedDescription: String {
        switch self {
        case .firstMaze: "You completed your first Classic maze."
        case .classic25: "You completed 25 different Classic mazes."
        case .classic100: "You completed 100 different Classic mazes."
        case .classic500: "You completed 500 different Classic mazes."
        case .perfect1: "You earned your first Perfect solve."
        case .perfect25: "You earned Perfect solves on 25 different regular levels."
        case .perfect100: "You earned Perfect solves on 100 different regular levels."
        case .limited25: "You completed 25 different Limited Moves levels."
        case .rush10: "You completed 10 different Time Rush rounds."
        case .daily1: "You completed your first daily maze."
        case .daily7: "You completed 7 different daily mazes."
        case .coins100: "You picked up 100 coins inside mazes."
        }
    }

    var points: Int {
        switch self {
        case .firstMaze: 10
        case .classic25: 25
        case .classic100, .perfect25, .limited25, .rush10, .daily7: 50
        case .classic500, .perfect100: 100
        case .perfect1, .daily1: 15
        case .coins100: 35
        }
    }

    var target: Int {
        switch self {
        case .firstMaze, .perfect1, .daily1: 1
        case .classic25, .perfect25, .limited25: 25
        case .classic100, .perfect100, .coins100: 100
        case .classic500: 500
        case .rush10: 10
        case .daily7: 7
        }
    }

    func progress(in snapshot: GameCenterProgressSnapshot) -> Int {
        let count: Int
        switch self {
        case .firstMaze, .classic25, .classic100, .classic500: count = snapshot.classicCompleted
        case .perfect1, .perfect25, .perfect100: count = snapshot.perfectCompleted
        case .limited25: count = snapshot.limitedCompleted
        case .rush10: count = snapshot.rushCompleted
        case .daily1, .daily7: count = snapshot.dailyCompleted
        case .coins100: count = snapshot.mazeCoinsCollected
        }
        return max(0, count)
    }

    func percentComplete(in snapshot: GameCenterProgressSnapshot) -> Double {
        Double(min(target, progress(in: snapshot))) / Double(target) * 100
    }
}
