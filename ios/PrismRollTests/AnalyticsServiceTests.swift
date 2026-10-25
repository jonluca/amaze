#if canImport(UIKit)
import GoogleMobileAds
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

    func testPaidCallbacksMapSDKAmountsWithoutStandardRevenueEventsOrIdentifiers() async {
        await withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            let ads = AdService(configuration: nil, analytics: service)
            let rewarded = ads.makePaidEventHandler(rewarded: true)
            let interstitial = ads.makePaidEventHandler(rewarded: false)
            // Loading while opted out does not suppress a future, newly consented receipt.
            service.setEnabled(true)
            rewarded(PaidValue(amount: "0.005", currency: "USD", precision: .estimated))
            interstitial(PaidValue(amount: "0.12", currency: "EUR", precision: .precise))
            await drainPaidCallbacks()

            XCTAssertEqual(transport.events.map(\.name), ["ad_revenue_paid", "ad_revenue_paid"])
            XCTAssertEqual(transport.events[0].parameters["ad_value"] as? Double, 0.005)
            XCTAssertEqual(transport.events[1].parameters["ad_value"] as? Double, 0.12)
            XCTAssertEqual(transport.events.compactMap { $0.parameters["ad_currency"] as? String }, ["USD", "EUR"])
            XCTAssertEqual(transport.events.compactMap { $0.parameters["ad_format"] as? String }, ["rewarded", "interstitial"])
            XCTAssertEqual(transport.events.compactMap { $0.parameters["ad_value_precision"] as? Int }, [1, 3])
            XCTAssertTrue(transport.events.allSatisfy {
                Set($0.parameters.keys) == ["ad_value", "ad_currency", "ad_value_precision", "ad_format"]
            })
            XCTAssertFalse(transport.actions.contains { $0.hasPrefix("purchase:") })
        }
    }

    func testPaidCallbackConsumesOnlyItsOwnSingleUseAdIncludingRepeatedValues() async {
        await withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.setEnabled(true)
            let ads = AdService(configuration: nil, analytics: service)
            let first = ads.makePaidEventHandler(rewarded: true)
            let second = ads.makePaidEventHandler(rewarded: true)
            let value = PaidValue(amount: "0.005", currency: "USD", precision: .publisherProvided)
            first(value)
            first(value)
            first(PaidValue(amount: "0.009", currency: "USD", precision: .precise))
            second(value)
            await drainPaidCallbacks()

            XCTAssertEqual(transport.events.map(\.name), ["ad_revenue_paid", "ad_revenue_paid"])
            XCTAssertEqual(transport.events.compactMap { $0.parameters["ad_value"] as? Double }, [0.005, 0.005])
            XCTAssertEqual(transport.events.compactMap { $0.parameters["ad_value_precision"] as? Int }, [2, 2])
        }
    }

    func testPaidCallbackFromBackgroundQueueRecordsOnAnalyticsOwner() async {
        await withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.setEnabled(true)
            let callback = AdService(configuration: nil, analytics: service).makePaidEventHandler(rewarded: false)
            await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .utility).async {
                    callback(PaidValue(amount: "0.025", currency: "USD", precision: .estimated))
                    continuation.resume()
                }
            }
            await drainPaidCallbacks()
            XCTAssertEqual(transport.events.map(\.name), ["ad_revenue_paid"])
            XCTAssertEqual(transport.events.first?.parameters["ad_value"] as? Double, 0.025)
        }
    }

    func testPaidCallbacksRespectConsentAndNeverReplaySuppressedReceipts() async {
        await withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            let ads = AdService(configuration: nil, analytics: service)
            let beforeConsent = ads.makePaidEventHandler(rewarded: true)
            let value = PaidValue(amount: "0.005", currency: "USD", precision: .estimated)
            beforeConsent(value)
            await drainPaidCallbacks()
            XCTAssertTrue(transport.actions.isEmpty)
            service.setEnabled(true)
            beforeConsent(value)
            let consented = ads.makePaidEventHandler(rewarded: false)
            consented(value)
            await drainPaidCallbacks()
            XCTAssertEqual(transport.events.count, 1)

            service.setEnabled(false)
            let revoked = ads.makePaidEventHandler(rewarded: true)
            revoked(value)
            await drainPaidCallbacks()
            service.setEnabled(true)
            revoked(value)
            await drainPaidCallbacks()
            XCTAssertEqual(transport.events.count, 1)
        }
    }

    func testQueuedPaidReceiptsCannotCrossAnOptInOrRevocationBoundary() async {
        await withDefaults { defaults in
            let transport = RecordingTransport()
            let service = AnalyticsService(defaults: defaults, transport: transport,
                runtime: AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false))
            let ads = AdService(configuration: nil, analytics: service)
            let value = PaidValue(amount: "0.005", currency: "USD", precision: .estimated)
            let beforeConsent = ads.makePaidEventHandler(rewarded: true)
            beforeConsent(value)
            service.setEnabled(true)
            await drainPaidCallbacks()
            XCTAssertTrue(transport.events.isEmpty)

            service.setEnabled(false)
            service.setEnabled(true)
            let beforeRevocation = ads.makePaidEventHandler(rewarded: false)
            beforeRevocation(value)
            service.setEnabled(false)
            service.setEnabled(true)
            await drainPaidCallbacks()
            XCTAssertTrue(transport.events.isEmpty)
        }
    }

    func testAdRevenueRejectsInvalidValuesButPreservesSDKZeroUnknownPrecision() {
        withDefaults { defaults in
            let transport = RecordingTransport()
            let service = makeService(defaults: defaults, transport: transport)
            service.setEnabled(true)
            for value in [-1, Double.nan, Double.infinity] {
                service.recordAdRevenue(value: value, currency: "USD", precision: 3, format: "rewarded", occurredAt: .now)
            }
            for currency in ["", "usd", "US", "USDD", "€€€"] {
                service.recordAdRevenue(value: 1, currency: currency, precision: 3, format: "rewarded", occurredAt: .now)
            }
            service.recordAdRevenue(value: 1, currency: "USD", precision: 3, format: "arbitrary", occurredAt: .now)
            service.recordAdRevenue(value: 0, currency: "USD", precision: 0, format: "rewarded", occurredAt: .now)
            XCTAssertEqual(transport.events.map(\.name), ["ad_revenue_paid"])
            XCTAssertEqual(transport.events[0].parameters["ad_value"] as? Double, 0)
            XCTAssertEqual(transport.events[0].parameters["ad_value_precision"] as? Int, 0)
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
            service.recordAdRevenue(value: 0.005, currency: "USD", precision: 1, format: "rewarded", occurredAt: .now)
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

    private func withDefaults(_ body: (UserDefaults) async -> Void) async {
        let suiteName = "AnalyticsServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        await body(defaults)
    }

    private func drainPaidCallbacks() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private final class PaidValue: AdValue {
        private let amount: NSDecimalNumber
        private let currency: String
        private let reportedPrecision: AdValuePrecision
        override var value: NSDecimalNumber { amount }
        override var currencyCode: String { currency }
        override var precision: AdValuePrecision { reportedPrecision }

        init(amount: String, currency: String, precision: AdValuePrecision) {
            self.amount = NSDecimalNumber(string: amount)
            self.currency = currency
            reportedPrecision = precision
            super.init()
        }
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
