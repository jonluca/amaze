#if canImport(UIKit)
import StoreKit
import XCTest
@testable import PrismRoll

@MainActor
final class AnalyticsServiceTests: XCTestCase {
    func testFirstLaunchAndDecliningConsentNeverInitializeAnalytics() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)

            XCTAssertFalse(service.hasMadeChoice)
            XCTAssertFalse(service.isEnabled)
            XCTAssertTrue(service.isAvailable)
            service.configure()
            service.record("level_start", parameters: ["level": 1])
            service.setEnabled(false)
            service.screen("home")

            XCTAssertTrue(service.hasMadeChoice)
            XCTAssertFalse(service.isEnabled)
            XCTAssertTrue(transport.actions.isEmpty)
            XCTAssertTrue(transport.events.isEmpty)
            XCTAssertEqual(defaults.object(forKey: AnalyticsService.consentDefaultsKey) as? Bool, false)
        }
    }

    func testOptInStartsAnalyticsOnceAndRecordsStructuredEvents() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.configure()
            service.setEnabled(true)
            service.configure()
            service.setEnabled(true)
            service.record("level_start", parameters: ["level": 2, "mode": "classic"])
            service.screen("collection")

            XCTAssertEqual(transport.actions, ["configure", "consent:true", "collection:true"])
            XCTAssertEqual(transport.events.map(\.name), ["level_start", "screen_view"])
            XCTAssertEqual(transport.events[0].parameters["level"] as? Int, 2)
            XCTAssertEqual(transport.events[0].parameters["mode"] as? String, "classic")
            XCTAssertEqual(transport.events[1].parameters["screen_name"] as? String, "collection")
            XCTAssertEqual(transport.events[1].parameters["screen_class"] as? String, "PrismRoll")
        }
    }

    func testStoredChoiceSurvivesServiceRecreationAndGameSaveRemoval() {
        withDefaults { defaults in
            let first = makeService(defaults: defaults, transport: RecordingTransport())
            first.setEnabled(true)
            for key in ["prism.snapshot.v2", "prism.progress", "prism.runs", "prism.mode"] {
                defaults.set("fixture", forKey: key)
                defaults.removeObject(forKey: key)
            }

            let transport = RecordingTransport()
            let restored = makeService(defaults: defaults, transport: transport)
            XCTAssertTrue(restored.hasMadeChoice)
            XCTAssertTrue(restored.isEnabled)
            XCTAssertTrue(transport.actions.isEmpty)
            restored.configure()
            XCTAssertEqual(transport.actions, ["configure", "consent:true", "collection:true"])

            restored.setEnabled(false)
            let declinedTransport = RecordingTransport()
            let declined = makeService(defaults: defaults, transport: declinedTransport)
            declined.configure()
            XCTAssertTrue(declined.hasMadeChoice)
            XCTAssertFalse(declined.isEnabled)
            XCTAssertTrue(declinedTransport.actions.isEmpty)
        }
    }

    func testRevokingConsentStopsCollectionBeforeResetAndDropsSubsequentEvents() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.setEnabled(true)
            service.record("level_start")
            service.setEnabled(false)
            service.record("level_end")
            service.setEnabled(false)

            XCTAssertEqual(transport.actions, [
                "configure", "consent:true", "collection:true",
                "collection:false", "consent:false", "reset", "consent:false"
            ])
            XCTAssertEqual(transport.events.map(\.name), ["level_start"])

            service.setEnabled(true)
            service.record("level_end")
            XCTAssertEqual(transport.actions.suffix(2), ["consent:true", "collection:true"])
            XCTAssertEqual(transport.actions.filter { $0 == "configure" }.count, 1)
            XCTAssertEqual(transport.events.map(\.name), ["level_start", "level_end"])
        }
    }

    func testUnavailableOrInvalidConfigurationNeverRecords() {
        withDefaults { defaults in
            let unavailable = RecordingTransport()
            unavailable.isAvailable = false
            let service = makeService(defaults: defaults, transport: unavailable)
            service.setEnabled(true)
            service.record("level_start")
            XCTAssertFalse(service.isAvailable)
            XCTAssertTrue(unavailable.actions.isEmpty)
            XCTAssertTrue(unavailable.events.isEmpty)

            let invalid = RecordingTransport()
            invalid.configureSucceeds = false
            let invalidService = makeService(defaults: defaults, transport: invalid)
            invalidService.configure()
            invalidService.record("level_start")
            XCTAssertFalse(invalidService.isAvailable)
            XCTAssertEqual(invalid.actions, ["configure"])
            XCTAssertTrue(invalid.events.isEmpty)
        }
    }

    func testDebugBuildNeedsExplicitAnalyticsDebugFlag() {
        let suppressed = AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: true)
        XCTAssertFalse(suppressed.allowsCollection)
        assertSuppressed(suppressed)

        let enabled = AnalyticsRuntime(arguments: ["--analytics-debug"], environment: [:], isDebugBuild: true)
        XCTAssertTrue(enabled.allowsCollection)
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = AnalyticsService(defaults: defaults, transport: transport, runtime: enabled)
            service.setEnabled(true)
            service.record("level_start")
            XCTAssertEqual(transport.events.count, 1)
        }
    }

    func testUITestsAndXCTestAlwaysSuppressIncludingInReleaseAndWithDebugFlag() {
        let runtimes = [
            AnalyticsRuntime(arguments: ["--uitesting", "--analytics-debug"], environment: [:], isDebugBuild: true),
            AnalyticsRuntime(arguments: ["--uitesting"], environment: [:], isDebugBuild: false),
            AnalyticsRuntime(arguments: ["--analytics-debug"], environment: ["XCTestConfigurationFilePath": "/test"], isDebugBuild: true),
            AnalyticsRuntime(arguments: [], environment: ["XCTestBundlePath": "/test"], isDebugBuild: false),
            AnalyticsRuntime(arguments: ["--analytics-debug"], environment: [:], isDebugBuild: false, isRunningTests: true)
        ]
        for runtime in runtimes {
            XCTAssertFalse(runtime.allowsCollection)
            assertSuppressed(runtime)
        }
    }

    private func assertSuppressed(_ runtime: AnalyticsRuntime) {
        withDefaults { defaults in
            defaults.set(true, forKey: AnalyticsService.consentDefaultsKey)
            let transport = RecordingTransport()
            let service = AnalyticsService(defaults: defaults, transport: transport, runtime: runtime)
            service.configure()
            service.record("level_start")
            service.setEnabled(false)
            service.setEnabled(true)
            service.screen("home")
            XCTAssertTrue(transport.actions.isEmpty)
            XCTAssertTrue(transport.events.isEmpty)
        }
    }

    private func makeService(defaults: UserDefaults, transport: RecordingTransport) -> AnalyticsService {
        AnalyticsService(
            defaults: defaults,
            transport: transport,
            runtime: AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false)
        )
    }

    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "AnalyticsServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    private final class RecordingTransport: AnalyticsTransport {
        var isAvailable = true
        var configureSucceeds = true
        var actions: [String] = []
        var events: [(name: String, parameters: [String: Any])] = []

        func configure() -> Bool {
            actions.append("configure")
            return configureSucceeds
        }

        func setCollectionEnabled(_ enabled: Bool) { actions.append("collection:\(enabled)") }
        func setAnalyticsConsent(granted: Bool) { actions.append("consent:\(granted)") }
        func resetAnalyticsData() { actions.append("reset") }
        func record(_ name: String, parameters: [String: Any]) { events.append((name, parameters)) }
        func recordVerifiedPurchase(_ transaction: Transaction) { actions.append("purchase:\(transaction.id)") }
    }
}
#endif
