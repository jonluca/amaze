import FirebaseAnalytics
import FirebaseCore
import Foundation

@MainActor
final class FirebaseAnalyticsTransport: AnalyticsTransport {
    private let options: FirebaseOptions?

    var isAvailable: Bool { options != nil }

    init(bundle: Bundle = .main) {
        // Reading the local configuration does not initialize Firebase or contact a server.
        if let path = bundle.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: path),
           options.bundleID == bundle.bundleIdentifier {
            self.options = options
        } else {
            options = nil
        }
    }

    func configure() -> Bool {
        guard let options else { return false }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure(options: options)
        }
        return true
    }

    func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    func setAnalyticsConsent(granted: Bool) {
        Analytics.setConsent([
            .analyticsStorage: granted ? .granted : .denied,
            .adStorage: .denied,
            .adUserData: .denied,
            .adPersonalization: .denied
        ])
    }

    func resetAnalyticsData() {
        Analytics.resetAnalyticsData()
    }

    func record(_ name: String, parameters: [String: Any]) {
        Analytics.logEvent(name, parameters: parameters)
    }
}
