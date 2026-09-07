import Foundation
import OSLog

/// Every hardware property belongs to `queue`, including normalized callbacks.
/// Each foreground session and hardware instance rejects stale native events.
final class MazeHapticEngineWorker: @unchecked Sendable {
    private enum Intent {
        case idle
        case rolling
        case completion(requestedAt: TimeInterval)
    }

    private let queue: DispatchQueue
    private let makeHardware: @Sendable () throws -> any MazeHapticHardware
    private let uptime: @Sendable () -> TimeInterval
    private let logger = Logger(subsystem: "com.jonluca.prismroll", category: "Haptics")
    private var hardware: (any MazeHapticHardware)?
    private var hardwareID: UUID?
    private var startID: UUID?
    private var sessionID: UUID?
    private var intent = Intent.idle
    private var ready = false
    private var rolling = false
    private var onAvailability: (@Sendable (UUID, MazeHapticAvailability) -> Void)?
    private var onInterruption: (@Sendable (UUID) -> Void)?

    init(queue: DispatchQueue = DispatchQueue(label: "com.jonluca.prismroll.haptics", qos: .userInteractive),
         makeHardware: @escaping @Sendable () throws -> any MazeHapticHardware = { try CoreMazeHapticHardware() },
         uptime: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.queue = queue
        self.makeHardware = makeHardware
        self.uptime = uptime
    }

    func setHandlers(availability: @escaping @Sendable (UUID, MazeHapticAvailability) -> Void,
                     interruption: @escaping @Sendable (UUID) -> Void) {
        queue.async {
            self.onAvailability = availability
            self.onInterruption = interruption
        }
    }

    func prepare(sessionID: UUID) {
        queue.async {
            if self.sessionID != sessionID {
                self.releaseHardware()
                self.intent = .idle
                self.sessionID = sessionID
            }
            self.ensureStarted()
        }
    }

    func setRolling(_ rolling: Bool, sessionID: UUID) {
        queue.async {
            guard self.sessionID == sessionID else { return }
            if rolling {
                // A failed request may be retried on the next rolling interval,
                // never on every display frame of this same interval.
                if case .rolling = self.intent { return }
                self.intent = .rolling
                self.ensureStarted()
            } else {
                self.intent = .idle
                self.stopRolling()
            }
        }
    }

    func playCompletion(sessionID: UUID) {
        let requestedAt = uptime()
        queue.async {
            guard self.sessionID == sessionID else { return }
            self.stopRolling()
            self.intent = .completion(requestedAt: requestedAt)
            self.ensureStarted()
        }
    }

    func stop(sessionID: UUID) {
        queue.async {
            guard self.sessionID == sessionID else { return }
            self.intent = .idle
            do {
                try self.hardware?.stopPlayers()
                self.rolling = false
            } catch { self.fail(error, operation: "stop players") }
        }
    }

    func suspend(sessionID: UUID) {
        queue.async {
            guard self.sessionID == sessionID else { return }
            self.sessionID = nil
            self.intent = .idle
            self.releaseHardware()
        }
    }

    func shutdown() {
        queue.async {
            self.sessionID = nil
            self.intent = .idle
            self.releaseHardware()
        }
    }

    private func ensureStarted() {
        guard let sessionID else { return }
        if ready {
            playCurrentIntent()
            return
        }
        guard startID == nil else { return }
        do {
            if hardware == nil {
                let hardware = try makeHardware()
                let hardwareID = UUID()
                hardware.setInterruptionHandler { [weak self] in
                    self?.queue.async { [weak self] in self?.interrupted(hardwareID: hardwareID) }
                }
                self.hardware = hardware
                self.hardwareID = hardwareID
            }
            guard let hardware, let hardwareID else { return }
            let startID = UUID()
            self.startID = startID
            onAvailability?(sessionID, .preparing)
            hardware.start { [weak self] error in
                self?.queue.async { [weak self] in
                    guard let self, self.sessionID == sessionID,
                          self.hardwareID == hardwareID, self.startID == startID else { return }
                    self.startID = nil
                    if let error {
                        self.fail(error, operation: "start engine")
                        return
                    }
                    do {
                        try hardware.preparePlayers()
                        self.ready = true
                        self.onAvailability?(sessionID, .ready)
                        self.playCurrentIntent()
                    } catch { self.fail(error, operation: "prepare players") }
                }
            }
        } catch { fail(error, operation: "create engine") }
    }

    private func playCurrentIntent() {
        guard let hardware else { return }
        do {
            switch intent {
            case .idle:
                break
            case .rolling:
                guard !rolling else { return }
                try hardware.startRolling()
                rolling = true
            case .completion(let requestedAt):
                intent = .idle
                guard uptime() - requestedAt < 0.15 else { return }
                try hardware.playCompletion()
            }
        } catch { fail(error, operation: "play pattern") }
    }

    private func stopRolling() {
        guard rolling else { return }
        do {
            try hardware?.stopRolling()
            rolling = false
        } catch { fail(error, operation: "stop rolling") }
    }

    private func interrupted(hardwareID: UUID) {
        guard self.hardwareID == hardwareID, let sessionID else { return }
        intent = .idle
        releaseHardware()
        onAvailability?(sessionID, .unavailable)
        onInterruption?(sessionID)
    }

    private func fail(_ error: Error, operation: String) {
        logger.error("Haptic \(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        if case .completion = intent { intent = .idle }
        releaseHardware()
        if let sessionID { onAvailability?(sessionID, .unavailable) }
    }

    private func releaseHardware() {
        let previous = hardware
        hardware = nil
        hardwareID = nil
        startID = nil
        ready = false
        rolling = false
        previous?.shutdown()
    }
}
