import Foundation

/// Fits the whole sculpted board with intentional space around it on any device.
enum MazeCameraFraming {
    static let widthCoverage = 0.68
    static let heightCoverage = 0.78

    static func scale(width: Int, height: Int, viewport: CGSize) -> Double {
        guard viewport.width > 0, viewport.height > 0 else { return 6 }
        let aspect = Double(viewport.width / viewport.height)
        let pitch = atan2(8.6, 16.0)
        let horizontal = Double(width) + 0.58
        // Include the raised walls, ball and lower rim in the camera projection.
        let vertical = (Double(height) + 0.58) * cos(pitch) + 1.15 * sin(pitch)
        return max(vertical / (2 * heightCoverage), horizontal / (2 * aspect * widthCoverage))
    }
}
