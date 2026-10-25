import Foundation
import Sentry

@MainActor
final class GlitchTipDiagnosticsTransport: DiagnosticsTransport {
    private let dsn: String?
    var isAvailable: Bool { dsn?.isEmpty == false }

    init(bundle: Bundle = .main) {
        dsn = bundle.object(forInfoDictionaryKey: "GlitchTipDSN") as? String
    }

    func configure() -> Bool {
        guard let dsn, !dsn.isEmpty else { return false }
        ErrorReporting.start(dsn: dsn, isAllowed: {
            UserDefaults.standard.bool(forKey: "prismroll.diagnostics.glitchtip.enabled")
        })
        return true
    }

    func sendPendingReports() {
        // Starting the SDK after consent sends its saved reports. It is never
        // started by Firebase Analytics and never imports old Firebase reports.
    }

    func record(_ failure: DiagnosticFailure) {
        SentrySDK.capture(error: failure.reportError)
    }

    func waitUntilReadyForSmokeTest() async {
        // Sentry installs its native crash handler synchronously during start.
    }
}
