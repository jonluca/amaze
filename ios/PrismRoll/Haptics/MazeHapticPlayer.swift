import CoreHaptics

/// Owns gameplay intent. Hardware preparation never runs on the swipe path.
@MainActor
final class MazeHapticPlayer {
    private let output: any MazeHapticOutput
    private var enabled = true
    private var active = false
    private var rolling = false
    private var completionPlayed = false

    init(output: (any MazeHapticOutput)? = nil) {
        if let output {
            self.output = output
        } else if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            self.output = CoreMazeHapticOutput()
        } else {
            self.output = UIKitMazeHapticOutput()
        }
        self.output.onInterruption = { [weak self] in
            // A fresh displayed-motion frame may restart a roll. Never replay a
            // completion or infer movement from the interrupted engine's state.
            self?.rolling = false
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        if enabled { prepare() } else { silence() }
    }

    func setActive(_ active: Bool) {
        guard self.active != active else { return }
        self.active = active
        if active { prepare() } else { silence() }
    }

    func prepare() {
        guard enabled, active else { return }
        output.prepare()
    }

    /// Call with the displayed motion state, including each idle frame.
    func setRolling(_ rolling: Bool) {
        let shouldRoll = rolling && enabled && active && !completionPlayed
        guard self.rolling != shouldRoll else { return }
        self.rolling = shouldRoll
        output.setRolling(shouldRoll)
    }

    func playCompletion() {
        guard enabled, active, !completionPlayed else { return }
        completionPlayed = true
        rolling = false
        output.setRolling(false)
        output.playCompletion()
    }

    /// Starts a new visual run without replaying the previous run's feedback.
    func reset() {
        completionPlayed = false
        silence()
    }

    func stop() {
        active = false
        silence()
    }

    private func silence() {
        rolling = false
        output.stop()
    }
}
