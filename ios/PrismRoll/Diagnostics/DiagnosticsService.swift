import Combine
import Foundation

@MainActor
final class DiagnosticsService: ObservableObject, DiagnosticsRecording {
    static let shared = DiagnosticsService()
    static let consentDefaultsKey = "prismroll.diagnostics.enabled"
    static let maximumReportsPerSession = 8

    @Published private(set) var isEnabled: Bool
    @Published private(set) var hasMadeChoice: Bool
    @Published private(set) var isAvailable: Bool

    private let defaults: UserDefaults
    private let transport: any DiagnosticsTransport
    private let runtime: DiagnosticsRuntime
    private var isConfigured = false
    private var isCollecting = false
    private var hasAuthorizedPendingReports = false
    private var reportedFailures: Set<DiagnosticFailure> = []

    convenience init() {
        self.init(defaults: .standard, transport: FirebaseDiagnosticsTransport(), runtime: .current)
    }

    init(defaults: UserDefaults, transport: any DiagnosticsTransport, runtime: DiagnosticsRuntime) {
        self.defaults = defaults
        self.transport = transport
        self.runtime = runtime
        hasMadeChoice = defaults.object(forKey: Self.consentDefaultsKey) != nil
        isEnabled = defaults.bool(forKey: Self.consentDefaultsKey)
        isAvailable = transport.isAvailable
    }

    /// Automatic SDK upload remains disabled. Consent explicitly covers saved
    /// reports, including local reports created before the choice, and future
    /// reports. Analytics consent alone never authorizes a crash report upload.
    func configure() {
        guard isEnabled, configureTransport() else { return }
        if !hasAuthorizedPendingReports {
            transport.sendPendingReports()
            hasAuthorizedPendingReports = true
        }
        isCollecting = true
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.consentDefaultsKey)
        hasMadeChoice = true
        isEnabled = enabled
        if enabled {
            configure()
        } else {
            // Crashlytics cannot retract a pending-report action already granted
            // this launch. Stop new custom errors and future authorizations only.
            isCollecting = false
        }
    }

    func record(error: Error, operation: DiagnosticOperation) {
        guard isEnabled, isCollecting else { return }
        let failure = DiagnosticFailure(error: error, operation: operation)
        guard reportedFailures.count < Self.maximumReportsPerSession,
              reportedFailures.insert(failure).inserted else { return }
        transport.record(failure)
    }

    /// A deliberate manual smoke test. Release builds contain no crash trigger;
    /// Debug also requires consent, --diagnostics-debug, and no XCTest runtime.
    func runDebugSmokeCrashIfRequested() async {
        #if DEBUG
        guard isEnabled, isCollecting, runtime.allowsCollection,
              ProcessInfo.processInfo.arguments.contains("--diagnostics-smoke-crash") else { return }
        await transport.waitUntilReadyForSmokeTest()
        guard !Task.isCancelled, isEnabled, isCollecting else { return }
        fatalError("Prism Roll diagnostics smoke test")
        #endif
    }

    private func configureTransport() -> Bool {
        guard runtime.allowsCollection, isAvailable else { return false }
        if !isConfigured {
            guard transport.configure() else {
                isAvailable = false
                return false
            }
            isConfigured = true
        }
        return true
    }
}
