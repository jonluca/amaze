import Foundation

struct GameplayRewardRequest {
    let id: UUID
    let runID: UUID
    let kind: GameplayReward
    let position: GridCell
    let moves: Int
}
