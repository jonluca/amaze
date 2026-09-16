#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class DiagnosticsServiceTests: XCTestCase {
    func testAppDisablesAutomaticUploadsBeforeEitherConsentServiceStarts() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "FirebaseCrashlyticsCollectionEnabled") as? Bool, false)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "FIREBASE_ANALYTICS_COLLECTION_ENABLED") as? Bool, false)
    }

    func testAnalyticsConsentDoesNotOptIntoDiagnostics() {
        withDefaults { defaults in
            defaults.set(true, forKey: AnalyticsService.consentDefaultsKey)
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.configure()
            service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            XCTAssertFalse(service.hasMadeChoice)
            XCTAssertFalse(service.isEnabled)
            service.setEnabled(false)
            XCTAssertTrue(service.hasMadeChoice)
            XCTAssertTrue(transport.actions.isEmpty)
            XCTAssertTrue(transport.failures.isEmpty)
            XCTAssertTrue(defaults.bool(forKey: AnalyticsService.consentDefaultsKey))
        }
    }

    func testNewConsentExplicitlyAuthorizesPreviouslySavedReportsOncePerLaunch() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            // Analytics may have initialized Firebase and cached a local report
            // before diagnostics consent. The explicit choice covers that report.
            transport.pendingReportCount = 1
            let service = makeService(defaults: defaults, transport: transport)
            service.configure()
            XCTAssertEqual(transport.uploadedReportCount, 0)
            service.setEnabled(true)
            service.configure()
            service.setEnabled(true)
            service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            XCTAssertEqual(transport.actions, ["configure", "send"])
            XCTAssertEqual(transport.uploadedReportCount, 1)
            XCTAssertEqual(transport.failures.count, 1)
            XCTAssertNil(defaults.object(forKey: AnalyticsService.consentDefaultsKey))

            let nextTransport = RecordingTransport()
            let nextLaunch = makeService(defaults: defaults, transport: nextTransport)
            XCTAssertTrue(nextLaunch.isEnabled)
            XCTAssertTrue(nextLaunch.hasMadeChoice)
            XCTAssertTrue(nextTransport.actions.isEmpty)
            nextLaunch.configure()
            nextLaunch.configure()
            XCTAssertEqual(nextTransport.actions, ["configure", "send"])
        }
    }

    func testRevocationStopsFutureAuthorizationWithoutClaimingToRecallAuthorizedReports() {
        withDefaults { defaults in
            defaults.set(true, forKey: DiagnosticsService.consentDefaultsKey)
            let transport = RecordingTransport()
            transport.pendingReportCount = 1
            let service = makeService(defaults: defaults, transport: transport)
            service.configure()
            service.setEnabled(false)
            service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            service.configure()
            XCTAssertEqual(transport.actions, ["configure", "send"])
            XCTAssertEqual(transport.uploadedReportCount, 1, "Opt-out cannot recall an already authorized report")
            XCTAssertTrue(transport.failures.isEmpty)

            let nextTransport = RecordingTransport()
            let nextLaunch = makeService(defaults: defaults, transport: nextTransport)
            nextLaunch.configure()
            XCTAssertTrue(nextTransport.actions.isEmpty)
            nextLaunch.setEnabled(true)
            nextLaunch.configure()
            XCTAssertEqual(nextTransport.actions, ["configure", "send"])
        }
    }

    func testReenablingWithinLaunchDoesNotIssueASecondPendingReportAction() {
        withDefaults { defaults in
            defaults.set(true, forKey: DiagnosticsService.consentDefaultsKey)
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.configure()
            service.setEnabled(false)
            service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            service.setEnabled(true)
            service.configure()
            service.record(error: CocoaError(.fileReadCorruptFile), operation: .progressLoad)
            XCTAssertEqual(transport.actions, ["configure", "send"])
            XCTAssertEqual(transport.failures.map(\.operation), [.progressLoad])
        }
    }

    func testSuppressedRuntimeNeverInitializesEvenWithSavedConsent() {
        let runtimes = [
            DiagnosticsRuntime(arguments: [], environment: [:], isDebugBuild: true),
            DiagnosticsRuntime(arguments: ["--analytics-debug"], environment: [:], isDebugBuild: true),
            DiagnosticsRuntime(arguments: ["--uitesting", "--diagnostics-debug"], environment: [:], isDebugBuild: true),
            DiagnosticsRuntime(arguments: ["--uitesting"], environment: [:], isDebugBuild: false),
            DiagnosticsRuntime(arguments: ["--diagnostics-debug"], environment: ["XCTestConfigurationFilePath": "/test"], isDebugBuild: true),
            DiagnosticsRuntime(arguments: [], environment: ["XCTestBundlePath": "/test"], isDebugBuild: false),
            DiagnosticsRuntime(arguments: ["--diagnostics-debug"], environment: [:], isDebugBuild: false, isRunningTests: true)
        ]
        for runtime in runtimes {
            XCTAssertFalse(runtime.allowsCollection)
            withDefaults { defaults in
                defaults.set(true, forKey: DiagnosticsService.consentDefaultsKey)
                let transport = RecordingTransport()
                let service = DiagnosticsService(defaults: defaults, transport: transport, runtime: runtime)
                service.configure()
                service.setEnabled(false)
                service.setEnabled(true)
                service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
                XCTAssertTrue(transport.actions.isEmpty)
                XCTAssertTrue(transport.failures.isEmpty)
            }
        }
    }

    func testDiagnosticsDebugFlagStillRequiresSeparateConsent() {
        withDefaults { defaults in
            let runtime = DiagnosticsRuntime(arguments: ["--diagnostics-debug"], environment: [:], isDebugBuild: true)
            let transport = RecordingTransport()
            let service = DiagnosticsService(defaults: defaults, transport: transport, runtime: runtime)
            service.configure()
            XCTAssertTrue(runtime.allowsCollection)
            XCTAssertTrue(transport.actions.isEmpty)
            service.setEnabled(true)
            service.record(error: CocoaError(.fileReadCorruptFile), operation: .progressLoad)
            XCTAssertEqual(transport.failures.count, 1)
        }
    }

    func testUnavailableAndFailedConfigurationNeverSend() {
        withDefaults { defaults in
            let missing = RecordingTransport()
            missing.isAvailable = false
            let unavailable = makeService(defaults: defaults, transport: missing)
            unavailable.setEnabled(true)
            unavailable.configure()
            XCTAssertFalse(unavailable.isAvailable)
            XCTAssertTrue(missing.actions.isEmpty)

            let failed = RecordingTransport()
            failed.configureSucceeds = false
            let invalid = makeService(defaults: defaults, transport: failed)
            invalid.configure()
            invalid.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            XCTAssertFalse(invalid.isAvailable)
            XCTAssertEqual(failed.actions, ["configure"])
            XCTAssertTrue(failed.failures.isEmpty)
        }
    }

    func testRepeatedFailuresAndSessionVolumeAreBounded() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.setEnabled(true)
            for _ in 0..<50 {
                service.record(error: CocoaError(.fileWriteOutOfSpace), operation: .progressSave)
            }
            XCTAssertEqual(transport.failures.count, 1)
            for code in 0..<20 {
                service.record(error: NSError(domain: NSCocoaErrorDomain, code: code), operation: .progressSave)
            }
            XCTAssertEqual(transport.failures.count, DiagnosticsService.maximumReportsPerSession)
            service.setEnabled(false)
            service.setEnabled(true)
            service.record(error: CocoaError(.fileReadCorruptFile), operation: .progressLoad)
            XCTAssertEqual(transport.failures.count, DiagnosticsService.maximumReportsPerSession)
        }
    }

    private func makeService(defaults: UserDefaults, transport: RecordingTransport) -> DiagnosticsService {
        DiagnosticsService(defaults: defaults, transport: transport,
                           runtime: DiagnosticsRuntime(arguments: [], environment: [:], isDebugBuild: false))
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suite = "DiagnosticsServiceTests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults)
    }

    private final class RecordingTransport: DiagnosticsTransport {
        var isAvailable = true
        var configureSucceeds = true
        var actions: [String] = []
        var failures: [DiagnosticFailure] = []
        var pendingReportCount = 0
        private(set) var uploadedReportCount = 0
        private var hasResolvedReportAction = false

        func configure() -> Bool { actions.append("configure"); return configureSucceeds }
        func sendPendingReports() {
            // Match Crashlytics: one shared pending-report action per launch.
            XCTAssertFalse(hasResolvedReportAction, "A second SDK report action has no effect")
            guard !hasResolvedReportAction else { return }
            hasResolvedReportAction = true
            actions.append("send")
            uploadedReportCount += pendingReportCount
            pendingReportCount = 0
        }
        func record(_ failure: DiagnosticFailure) { failures.append(failure) }
        func waitUntilReadyForSmokeTest() async { actions.append("smoke_ready") }
    }
}
#endif
