import Foundation

@MainActor
protocol AnalyticsRecording {
    func record(_ name: String, parameters: [String: Any])
    func recordAdRevenue(value: Double, currency: String, precision: Int, format: String, occurredAt: ContinuousClock.Instant)
}
