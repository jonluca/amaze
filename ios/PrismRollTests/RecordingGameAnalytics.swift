#if canImport(UIKit)
import Foundation
@testable import PrismRoll

@MainActor
final class RecordingGameAnalytics: AnalyticsRecording {
    struct Event {
        let name: String
        let parameters: [String: Any]
    }

    private(set) var recorded: [Event] = []

    func record(_ name: String, parameters: [String: Any]) {
        recorded.append(Event(name: name, parameters: parameters))
    }

    func recordAdRevenue(value: Double, currency: String, precision: Int, format: String, occurredAt: ContinuousClock.Instant) {
        record("ad_revenue_paid", parameters: ["ad_value": value, "ad_currency": currency,
                                              "ad_value_precision": precision, "ad_format": format])
    }

    func events(_ name: String) -> [Event] {
        recorded.filter { $0.name == name }
    }
}
#endif
