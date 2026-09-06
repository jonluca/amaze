import Foundation

enum GameplayReward: String {
    case hint, extraTime, extraMoves, skip

    var title: String {
        switch self {
        case .hint: "Reveal a hint"
        case .extraTime: "Add 30 seconds"
        case .extraMoves: "Add 3 moves"
        case .skip: "Skip this level"
        }
    }
}
