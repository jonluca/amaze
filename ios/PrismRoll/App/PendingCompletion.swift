import Foundation

/// An unfinished proof survives advancing to another maze or restarting the app.
struct PendingCompletion: Codable, Equatable, Sendable {
    let id: UUID
    let run: MazeRun
    let stageIndex: Int?
}
