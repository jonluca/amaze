import Foundation

/// A self-contained puzzle. It never carries currency, unlocks, or saved progress.
struct SharedChallenge: Identifiable, Equatable, Sendable {
    let level: MazeLevel
    let title: String
    let senderMoves: Int?
    let url: URL

    var id: String { url.absoluteString }
}
