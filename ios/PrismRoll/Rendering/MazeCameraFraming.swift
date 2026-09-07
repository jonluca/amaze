import Foundation

/// Fits the whole sculpted board with intentional space around it on any device.
enum MazeCameraFraming {
    static let widthCoverage = 0.84
    static let heightCoverage = 0.84
    static let cameraHeight = 20.0
    static let cameraDepth = 5.8

    static func scale(width: Int, height: Int, viewport: CGSize) -> Double {
        guard viewport.width > 0, viewport.height > 0 else { return 6 }
        // Dense mazes use extra vertical space while leaving a margin for the
        // raised rim and the ball at the edge of the screen.
        let growth = min(1, max(0, Double(max(width, height) - 10) / 6))
        let fittedWidthCoverage = widthCoverage + 0.02 * growth
        let fittedHeightCoverage = heightCoverage + 0.10 * growth
        let aspect = Double(viewport.width / viewport.height)
        let pitch = atan2(cameraDepth, cameraHeight)
        let horizontal = Double(width) + 0.22
        // Include the raised walls, ball and lower rim in the camera projection.
        let vertical = (Double(height) + 0.22) * cos(pitch) + 0.95 * sin(pitch)
        return max(vertical / (2 * fittedHeightCoverage), horizontal / (2 * aspect * fittedWidthCoverage))
    }
}
