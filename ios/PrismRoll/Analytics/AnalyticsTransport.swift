import Foundation

/// The SDK boundary stays injectable so privacy behavior can be tested without networking.
@MainActor
protocol AnalyticsTransport: AnyObject {
    var isAvailable: Bool { get }
    func configure() -> Bool
    func setCollectionEnabled(_ enabled: Bool)
    func setAnalyticsConsent(granted: Bool)
    func resetAnalyticsData()
    func record(_ name: String, parameters: [String: Any])
}
