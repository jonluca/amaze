import UIKit

@MainActor
final class CoreMazeHapticOutput: MazeHapticOutput {
    var onInterruption: (() -> Void)?
    private let worker = MazeHapticEngineWorker()
    private let fallbackImpact = UIImpactFeedbackGenerator(style: .medium)
    private let fallbackCompletion = UINotificationFeedbackGenerator()
    private var sessionID: UUID?
    private var availability = MazeHapticAvailability.preparing
    private var rolling = false
    private var usedFallback = false

    init() {
        worker.setHandlers(
            availability: { [weak self] sessionID, availability in
                DispatchQueue.main.async {
                    guard let self, self.sessionID == sessionID else { return }
                    self.availability = availability
                    if availability == .unavailable { self.playFallbackIfRolling() }
                }
            },
            interruption: { [weak self] sessionID in
                DispatchQueue.main.async {
                    guard let self, self.sessionID == sessionID else { return }
                    self.onInterruption?()
                }
            }
        )
    }

    func prepare() {
        if sessionID == nil { sessionID = UUID() }
        guard let sessionID else { return }
        fallbackImpact.prepare()
        fallbackCompletion.prepare()
        worker.prepare(sessionID: sessionID)
    }

    func setRolling(_ rolling: Bool) {
        guard let sessionID else { return }
        if !self.rolling { usedFallback = false }
        self.rolling = rolling
        if rolling, availability != .ready { playFallbackIfRolling() }
        worker.setRolling(rolling, sessionID: sessionID)
    }

    func playCompletion() {
        guard let sessionID else { return }
        rolling = false
        if availability == .ready {
            worker.playCompletion(sessionID: sessionID)
        } else {
            // A cold engine must not replay the celebration after its animation.
            fallbackCompletion.notificationOccurred(.success)
        }
    }

    func playStep() {
        guard sessionID != nil else { return }
        fallbackImpact.impactOccurred(intensity: 0.75)
    }

    func stop() {
        rolling = false
        usedFallback = false
        if let sessionID { worker.stop(sessionID: sessionID) }
    }

    func suspend() {
        let previousSession = sessionID
        sessionID = nil
        availability = .preparing
        rolling = false
        usedFallback = false
        if let previousSession { worker.suspend(sessionID: previousSession) }
    }

    private func playFallbackIfRolling() {
        guard sessionID != nil, rolling, !usedFallback else { return }
        usedFallback = true
        fallbackImpact.impactOccurred(intensity: 0.75)
    }

    deinit { worker.shutdown() }
}
