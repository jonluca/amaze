import Foundation

/// A committed move, delivered synchronously so a display update cannot merge turns.
struct GameMoveEvent: Sendable {
    let runID: UUID
    let start: GridCell
    let path: [GridCell]
    let position: GridCell
    let painted: Set<GridCell>
    let isComplete: Bool
    let moves: Int
}
