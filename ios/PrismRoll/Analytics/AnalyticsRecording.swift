import Foundation

@MainActor
protocol AnalyticsRecording {
    func record(_ name: String, parameters: [String: Any])
}
