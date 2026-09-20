import XCTest
@testable import PrismRoll

@MainActor
final class AppsFlyerAttributionTests: XCTestCase {
    func testMissingOrTemplateKeyCannotEnableSDK() {
        for key in [nil, "", "   ", "$(APPSFLYER_DEV_KEY)", "<YOUR_DEV_KEY>", "placeholder", "YOUR_DEV_KEY"] {
            let config = AppsFlyerConfiguration(developerKey: key)
            XCTAssertNil(config)
            let recorder = RecordingInstallAttributionTransport()
            let service = makeService(recorder, configuration: config)
            service.setEnabled(true)
            service.setUsageAnalyticsEnabled(true)
            XCTAssertFalse(service.isAvailable)
            XCTAssertTrue(recorder.actions.isEmpty)
        }
    }

    func testOldGoogleConsentDoesNotEnableNewProvider() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AnalyticsService.consentDefaultsKey)
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder, defaults: defaults)
        service.setUsageAnalyticsEnabled(true)
        XCTAssertFalse(service.isEnabled)
        XCTAssertTrue(recorder.actions.isEmpty)
    }

    func testBothAffirmativeChoicesAreRequiredInEitherOrder() {
        for attributionFirst in [false, true] {
            let recorder = RecordingInstallAttributionTransport()
            let service = makeService(recorder)
            if attributionFirst { service.setEnabled(true) }
            else { service.setUsageAnalyticsEnabled(true) }
            XCTAssertTrue(recorder.actions.isEmpty)
            if attributionFirst { service.setUsageAnalyticsEnabled(true) }
            else { service.setEnabled(true) }
            XCTAssertEqual(recorder.actions, ["initialize"])
            recorder.signalReady()
            XCTAssertEqual(recorder.actions, ["initialize", "start"])
        }
    }

    func testRepeatedChoiceUpdatesDoNotDuplicateInitializationOrSession() {
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder)
        service.setEnabled(true)
        service.setUsageAnalyticsEnabled(true)
        recorder.signalReady()
        service.setEnabled(true)
        service.setUsageAnalyticsEnabled(true)
        XCTAssertEqual(recorder.actions, ["initialize", "start"])
    }

    func testEitherWithdrawalStopsAndRejectsLateReadyCallbacks() {
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder)
        service.setEnabled(true)
        service.setUsageAnalyticsEnabled(true)
        recorder.signalReady()
        service.setEnabled(false)
        recorder.signalReady()
        service.setEnabled(false)
        XCTAssertEqual(recorder.actions, ["initialize", "start", "stop"])

        service.setEnabled(true)
        XCTAssertEqual(recorder.actions.last, "resume")
        XCTAssertEqual(recorder.actions.filter { $0 == "start" }.count, 1)
        service.setUsageAnalyticsEnabled(false)
        recorder.signalReady()
        XCTAssertEqual(recorder.actions, ["initialize", "start", "stop", "resume", "stop"])
    }

    func testDecliningBeforeSDKReadyNeverSendsFirstSession() {
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder)
        service.setEnabled(true)
        service.setUsageAnalyticsEnabled(true)
        service.setEnabled(false)
        recorder.signalReady()
        XCTAssertEqual(recorder.actions, ["initialize", "stop"])
    }

    func testSavedAttributionChoiceStillNeedsUsageChoiceOnNewLaunch() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppsFlyerAttributionService.consentDefaultsKey)
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder, defaults: defaults)
        XCTAssertTrue(service.isEnabled)
        service.setUsageAnalyticsEnabled(false)
        XCTAssertTrue(recorder.actions.isEmpty)
        service.setUsageAnalyticsEnabled(true)
        XCTAssertEqual(recorder.actions, ["initialize"])
        service.setEnabled(false)
        let nextRecorder = RecordingInstallAttributionTransport()
        let nextLaunch = makeService(nextRecorder, defaults: defaults)
        nextLaunch.setUsageAnalyticsEnabled(true)
        XCTAssertFalse(nextLaunch.isEnabled)
        XCTAssertTrue(nextRecorder.actions.isEmpty)
    }

    func testDebugAndTestsRemainSuppressedWithBothSavedChoices() {
        let runtimes = [
            AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: true),
            AnalyticsRuntime(arguments: ["--uitesting", "--analytics-debug"], environment: [:], isDebugBuild: true),
            AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false, isRunningTests: true)
        ]
        for runtime in runtimes {
            let defaults = makeDefaults()
            defaults.set(true, forKey: AppsFlyerAttributionService.consentDefaultsKey)
            let recorder = RecordingInstallAttributionTransport()
            let service = makeService(recorder, defaults: defaults, runtime: runtime)
            service.setUsageAnalyticsEnabled(true)
            service.setEnabled(true)
            recorder.signalReady()
            XCTAssertTrue(recorder.actions.isEmpty)
        }
    }

    func testAnalyticsMasterChoiceCoordinatesAttributionAndRemainsIndependentOfMissingKey() {
        for configuration in [nil, AppsFlyerConfiguration(developerKey: "unit-test-only-not-an-account-key")] {
            let recorder = RecordingInstallAttributionTransport()
            let attribution = makeService(recorder, configuration: configuration)
            let firebase = RecordingPurchaseAnalyticsTransport()
            let analytics = AnalyticsService(
                defaults: makeDefaults(), transport: firebase,
                runtime: AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false),
                attribution: attribution
            )
            attribution.setEnabled(true)
            analytics.configure()
            XCTAssertTrue(recorder.actions.isEmpty)
            analytics.setEnabled(true)
            XCTAssertTrue(firebase.actions.contains("collection:true"))
            XCTAssertEqual(recorder.actions, configuration == nil ? [] : ["initialize"])
            analytics.setEnabled(false)
            recorder.signalReady()
            XCTAssertTrue(firebase.actions.contains("collection:false"))
            XCTAssertEqual(recorder.actions, configuration == nil ? [] : ["initialize", "stop"])
        }
    }

    func testQueuedReadinessCannotSurviveWithdrawalAndImmediateReenable() {
        let recorder = RecordingInstallAttributionTransport()
        let service = makeService(recorder)
        let readiness = AttributionSessionReadiness()
        service.setEnabled(true)
        service.setUsageAnalyticsEnabled(true)
        let oldDelivery = readiness.delivery { recorder.signalReady() }
        readiness.invalidate()
        service.setEnabled(false)
        readiness.invalidate()
        service.setEnabled(true)
        oldDelivery()
        XCTAssertEqual(recorder.actions, ["initialize", "stop", "resume"])
        let nextForeground = readiness.delivery { recorder.signalReady() }
        nextForeground()
        XCTAssertEqual(recorder.actions, ["initialize", "stop", "resume", "start"])
    }

    private func makeService(
        _ recorder: RecordingInstallAttributionTransport,
        defaults: UserDefaults? = nil,
        configuration: AppsFlyerConfiguration? = AppsFlyerConfiguration(developerKey: "unit-test-only-not-an-account-key"),
        runtime: AnalyticsRuntime = AnalyticsRuntime(arguments: [], environment: [:], isDebugBuild: false)
    ) -> AppsFlyerAttributionService {
        // The fixture configuration only reaches a recorder, never the real SDK.
        AppsFlyerAttributionService(defaults: defaults ?? makeDefaults(), configuration: configuration,
                                   transport: recorder, runtime: runtime)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "AppsFlyerAttributionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}
