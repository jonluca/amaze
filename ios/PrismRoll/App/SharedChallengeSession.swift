import Combine
import Foundation

/// Separate ownership makes a shared puzzle unable to alter the player's saved game.
@MainActor
final class SharedChallengeSession: ObservableObject {
    let challenge: SharedChallenge
    @Published private(set) var run: MazeRun
    @Published private(set) var runID = UUID()
    let moveEvents = PassthroughSubject<GameMoveEvent, Never>()
    private let analytics: any AnalyticsRecording

    init(challenge: SharedChallenge, analytics: (any AnalyticsRecording)? = nil) {
        self.challenge = challenge
        self.run = MazeRun(level: challenge.level)
        self.analytics = analytics ?? AnalyticsService.shared
        self.analytics.record("challenge_opened", parameters: ["has_target": challenge.senderMoves == nil ? 0 : 1])
    }

    func move(_ direction: MoveDirection, for inputID: UUID) {
        guard inputID == runID, !run.isComplete else { return }
        let start = run.position
        let previousMoves = run.moves
        let path = run.move(direction, recomputeFallbackHint: false)
        guard !path.isEmpty else { return }
        moveEvents.send(GameMoveEvent(runID: runID, start: start, path: path, position: run.position,
                                     painted: run.painted, isComplete: run.isComplete, moves: run.moves))
        if previousMoves == 0 { analytics.record("challenge_started", parameters: [:]) }
        if run.isComplete {
            analytics.record("challenge_completed", parameters: ["moves": run.moves])
        }
    }

    func restart() {
        runID = UUID()
        run = MazeRun(level: challenge.level)
    }
}
