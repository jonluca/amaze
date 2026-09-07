import CoreHaptics

final class CoreMazeHapticHardware: MazeHapticHardware {
    private enum Failure: Error { case playerUnavailable }
    private let engine: CHHapticEngine
    private var rollingPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var completionPlayer: (any CHHapticPatternPlayer)?

    init() throws {
        engine = try CHHapticEngine(audioSession: nil)
        engine.playsHapticsOnly = true
        // The visible gameplay session explicitly owns the warm engine. The
        // worker shuts it down when gameplay becomes inactive or is disabled.
        engine.isAutoShutdownEnabled = false
    }

    func setInterruptionHandler(_ handler: @escaping @Sendable () -> Void) {
        engine.stoppedHandler = { _ in handler() }
        engine.resetHandler = handler
    }

    func start(completion: @escaping @Sendable (Error?) -> Void) {
        engine.start(completionHandler: completion)
    }

    func preparePlayers() throws {
        if rollingPlayer == nil {
            let player = try engine.makeAdvancedPlayer(with: MazeHapticPatterns.rolling())
            player.loopEnabled = true
            player.loopEnd = MazeHapticPatterns.rollingDuration
            rollingPlayer = player
        }
        if completionPlayer == nil {
            completionPlayer = try engine.makePlayer(with: MazeHapticPatterns.completion())
        }
    }

    func startRolling() throws {
        guard let rollingPlayer else { throw Failure.playerUnavailable }
        try rollingPlayer.start(atTime: CHHapticTimeImmediate)
    }

    func stopRolling() throws {
        try rollingPlayer?.stop(atTime: CHHapticTimeImmediate)
    }

    func playCompletion() throws {
        guard let completionPlayer else { throw Failure.playerUnavailable }
        try completionPlayer.start(atTime: CHHapticTimeImmediate)
    }

    func stopPlayers() throws {
        try stopRolling()
        try completionPlayer?.stop(atTime: CHHapticTimeImmediate)
    }

    func shutdown() {
        engine.stoppedHandler = { _ in }
        engine.resetHandler = {}
        try? stopPlayers()
        engine.stop(completionHandler: nil)
        rollingPlayer = nil
        completionPlayer = nil
    }
}
