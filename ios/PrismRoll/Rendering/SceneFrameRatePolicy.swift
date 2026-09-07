import SceneKit
import UIKit

@MainActor
enum SceneFrameRatePolicy {
    static func apply(to view: SCNView, displayLink: CADisplayLink? = nil) {
        let screenMaximum = view.window?.windowScene?.screen.maximumFramesPerSecond ?? 120
        let preferredRange = range(maximumFramesPerSecond: screenMaximum)
        view.preferredFramesPerSecond = Int(preferredRange.preferred ?? preferredRange.maximum)
        displayLink?.preferredFrameRateRange = preferredRange
    }

    static func range(maximumFramesPerSecond: Int) -> CAFrameRateRange {
        let maximum = Float(max(1, min(120, maximumFramesPerSecond)))
        // This is a preference. iOS retains control for Low Power Mode,
        // temperature, accessibility settings, and the connected display.
        return CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
    }
}
