import UIKit

/// Devices without custom haptics retain a bounded native fallback.
@MainActor
final class UIKitMazeHapticOutput: MazeHapticOutput {
    var onInterruption: (() -> Void)?
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let completion = UINotificationFeedbackGenerator()

    func prepare() {
        impact.prepare()
        completion.prepare()
    }

    func setRolling(_ rolling: Bool) {
        if rolling { impact.impactOccurred(intensity: 0.90) }
    }

    func playStep() { impact.impactOccurred(intensity: 0.90) }

    func playCompletion() {
        completion.notificationOccurred(.success)
    }

    func stop() {}
    func suspend() {}
}
