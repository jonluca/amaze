import CoreHaptics
import Foundation

/// Every engine/player property belongs to `queue`, including native callbacks.
/// The main-thread facade only submits commands and never waits for the engine.
final class MazeHapticEngineWorker: @unchecked Sendable {
    private enum Intent {
        case idle
        case rolling
        case completion(requestedAt: TimeInterval)
    }

    private let queue = DispatchQueue(label: "com.jonluca.prismroll.haptics", qos: .userInteractive)
    private var engine: CHHapticEngine?
    private var rollingPlayer: (any CHHapticAdvancedPatternPlayer)?
    private var completionPlayer: (any CHHapticPatternPlayer)?
    private var intent = Intent.idle
    private var generation = 0
    private var starting = false
    private var ready = false
    private var rolling = false
    private var onInterruption: (@Sendable () -> Void)?

    func setInterruptionHandler(_ handler: @escaping @Sendable () -> Void) {
        queue.async { self.onInterruption = handler }
    }

    func prepare() {
        queue.async { self.ensureStarted() }
    }

    func setRolling(_ rolling: Bool) {
        queue.async {
            self.intent = rolling ? .rolling : .idle
            if rolling {
                self.ensureStarted()
            } else {
                self.stopRolling()
            }
        }
    }

    func playCompletion() {
        let requestedAt = ProcessInfo.processInfo.systemUptime
        queue.async {
            self.stopRolling()
            self.intent = .completion(requestedAt: requestedAt)
            self.ensureStarted()
        }
    }

    func stop() {
        queue.async {
            self.intent = .idle
            self.stopPlayers()
            // Reuse the engine between runs; auto-shutdown releases idle hardware.
            // Any in-flight start reads the new idle intent before playing.
        }
    }

    func shutdown() {
        queue.async {
            self.intent = .idle
            self.stopPlayers()
            self.generation += 1
            self.engine?.stoppedHandler = { _ in }
            self.engine?.resetHandler = {}
            self.engine?.stop(completionHandler: nil)
            self.engine = nil
            self.rollingPlayer = nil
            self.completionPlayer = nil
            self.ready = false
            self.starting = false
        }
    }

    private func ensureStarted() {
        if ready {
            playCurrentIntent()
            return
        }
        guard !starting else { return }
        do {
            if engine == nil { try makeEngine() }
            guard let engine else { return }
            starting = true
            let requestedGeneration = generation
            engine.start { [weak self] error in
                self?.queue.async { [weak self] in
                    guard let self, self.generation == requestedGeneration else { return }
                    self.starting = false
                    guard error == nil else {
                        self.invalidatePlayback()
                        return
                    }
                    do {
                        try self.makePlayers(on: engine)
                        self.ready = true
                        self.playCurrentIntent()
                    } catch {
                        self.invalidatePlayback()
                    }
                }
            }
        } catch {
            invalidatePlayback()
        }
    }

    private func makeEngine() throws {
        let engine = try CHHapticEngine()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        // A stop/reset only invalidates playback. The next live command prepares
        // again; an interruption must not replay a queued completion or old roll.
        engine.stoppedHandler = { [weak self] _ in
            self?.queue.async { [weak self] in
                self?.invalidatePlayback()
                self?.onInterruption?()
            }
        }
        engine.resetHandler = { [weak self] in
            self?.queue.async { [weak self] in
                self?.invalidatePlayback()
                self?.onInterruption?()
            }
        }
        self.engine = engine
    }

    private func makePlayers(on engine: CHHapticEngine) throws {
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

    private func playCurrentIntent() {
        do {
            switch intent {
            case .idle:
                break
            case .rolling:
                guard !rolling else { return }
                try rollingPlayer?.start(atTime: CHHapticTimeImmediate)
                rolling = true
            case .completion(let requestedAt):
                intent = .idle
                // Late engine recovery must not turn into a detached celebration.
                guard ProcessInfo.processInfo.systemUptime - requestedAt < 0.15 else { return }
                try completionPlayer?.start(atTime: CHHapticTimeImmediate)
            }
        } catch {
            stopPlayers()
            invalidatePlayback()
        }
    }

    private func stopRolling() {
        if rolling { try? rollingPlayer?.stop(atTime: CHHapticTimeImmediate) }
        rolling = false
    }

    private func stopPlayers() {
        stopRolling()
        try? completionPlayer?.stop(atTime: CHHapticTimeImmediate)
    }

    private func invalidatePlayback() {
        // A delayed native callback may arrive after a new start. Retain and
        // stop the known players before invalidating them so no loop is orphaned.
        stopPlayers()
        generation += 1
        intent = .idle
        ready = false
        starting = false
        rolling = false
        rollingPlayer = nil
        completionPlayer = nil
    }
}
