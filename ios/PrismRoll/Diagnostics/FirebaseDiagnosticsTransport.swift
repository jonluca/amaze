import FirebaseAnalytics
import FirebaseCore
import FirebaseCrashlytics
import Foundation

@MainActor
final class FirebaseDiagnosticsTransport: DiagnosticsTransport {
    private let options: FirebaseOptions?

    var isAvailable: Bool { options != nil }

    init(bundle: Bundle = .main) {
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
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--diagnostics-debug") {
            FirebaseConfiguration.shared.setLoggerLevel(.debug)
        }
        #endif
        // Analytics' enabled override survives launches and takes precedence over
        // Info.plist. Clear a stale override before diagnostics starts the shared
        // Firebase app; only AnalyticsService may enable usage collection.
        if !AnalyticsRuntime.current.allowsCollection
            || !UserDefaults.standard.bool(forKey: AnalyticsService.consentDefaultsKey) {
            Analytics.setAnalyticsCollectionEnabled(false)
            Analytics.setConsent([
                .analyticsStorage: .denied,
                .adStorage: .denied,
                .adUserData: .denied,
                .adPersonalization: .denied
            ])
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure(options: options)
        }
        // Keep automatic uploads off even after consent. A persisted SDK override
        // could otherwise upload on a future analytics-only/debug initialization.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        return true
    }

    func sendPendingReports() {
        Crashlytics.crashlytics().sendUnsentReports()
    }

    func record(_ failure: DiagnosticFailure) {
        Crashlytics.crashlytics().record(error: failure.reportError)
    }

    func waitUntilReadyForSmokeTest() async {
        // Crashlytics resolves this only after its crash reporter has started.
        // A crash immediately after FirebaseApp.configure() can be too early.
        _ = await Crashlytics.crashlytics().checkForUnsentReports()
    }
}
