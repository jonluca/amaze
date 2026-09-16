#if canImport(UIKit)
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

    func events(_ name: String) -> [Event] {
        recorded.filter { $0.name == name }
    }
}
#endif
