import UIKit

/// Devices without custom haptics retain a bounded native fallback.
@MainActor
final class UIKitMazeHapticOutput: MazeHapticOutput {
    var onInterruption: (() -> Void)?
    private let impact = UIImpactFeedbackGenerator(style: .soft)
    private let completion = UINotificationFeedbackGenerator()

    func prepare() {
        impact.prepare()
        completion.prepare()
    }

    func setRolling(_ rolling: Bool) {
        if rolling { impact.impactOccurred(intensity: 0.35) }
    }

    func playCompletion() {
        completion.notificationOccurred(.success)
    }

    func stop() {}
}
