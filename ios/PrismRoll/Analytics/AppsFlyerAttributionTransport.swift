import AppsFlyerLib
import Foundation
import OSLog

@MainActor
final class AppsFlyerAttributionTransport: InstallAttributionTransport {
    private var sdk: AppsFlyerLib?
    private let readiness = AttributionSessionReadiness()
    #if DEBUG
    private let diagnosticLogger = Logger(subsystem: "com.jonluca.prismroll", category: "AppsFlyerQA")
    #endif

    func initialize(configuration: AppsFlyerConfiguration, sessionReady: @escaping @MainActor () -> Void) {
        // Even shared() is deferred until both affirmative choices and runtime gates pass.
        let sdk = AppsFlyerLib.shared()
        self.sdk = sdk
        recordDiagnostic("initialize_requested")
        applyPrivacy(to: sdk)
        recordPrivacyDiagnostics(sdk, stage: "before_initialize")
        sdk.initialize(devKey: configuration.developerKey, appId: AppsFlyerConfiguration.appleAppID)
        recordConfigurationDiagnostics(sdk, expected: configuration)
        sdk.isStopped = false
        sdk.registerSessionReadyListener { [weak self] in
            guard let self else { return }
            self.recordDiagnostic("session_ready")
            // The SDK documents this Objective-C callback as main-queue delivered.
            // Normalize the SDK boundary explicitly for Swift actor isolation.
            let deliver = self.readiness.delivery(sessionReady)
            DispatchQueue.main.async { deliver() }
        }
    }

    func startSession() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--analytics-debug") {
            let logger = diagnosticLogger
            logger.notice("start_requested")
            sdk?.start { _, error in
                // Never log the response dictionary, request payload, key or device ID.
                if let error {
                    let sdkError = error as NSError
                    let underlying = sdkError.userInfo[NSUnderlyingErrorKey] as? NSError
                    logger.notice("server_response_error_code=\(sdkError.code) underlying_code=\(underlying?.code ?? 0)")
                } else {
                    logger.notice("server_response_accepted")
                }
            }
            return
        }
        #endif
        sdk?.start()
    }

    func stop() {
        recordDiagnostic("stop_requested")
        readiness.invalidate()
        sdk?.isStopped = true
    }

    func resume() {
        guard let sdk else { return }
        recordDiagnostic("resume_requested")
        readiness.invalidate()
        applyPrivacy(to: sdk)
        sdk.isStopped = false
    }

    private func applyPrivacy(to sdk: AppsFlyerLib) {
        // The Strict binary removes IDFA collection code. Keep its remaining optional
        // identifiers, advertising integrations and partner postbacks disabled too.
        sdk.disableIDFVCollection = true
        sdk.disableSKAdNetwork = true
        sdk.disableAppleAdsAttribution = true
        sdk.shouldCollectDeviceName = false
        sdk.isDebug = false
        sdk.enableTCFDataCollection(false)
        sdk.setSharingFilterForPartners(["all"])
        sdk.setConsentData(AppsFlyerConsent(
            // This field means advertising-data use, not the app's analytics opt-in.
            isUserSubjectToGDPR: nil, hasConsentForDataUsage: false,
            hasConsentForAdsPersonalization: false, hasConsentForAdStorage: false
        ))
    }

    private func recordDiagnostic(_ message: String) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--analytics-debug") {
            diagnosticLogger.notice("\(message, privacy: .public)")
        }
        #endif
    }

    private func recordConfigurationDiagnostics(_ sdk: AppsFlyerLib, expected: AppsFlyerConfiguration) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--analytics-debug") else { return }
        recordDiagnostic("configuration_app_id_matches=\(sdk.appleAppID == AppsFlyerConfiguration.appleAppID)")
        recordDiagnostic("configuration_dev_key_matches=\(sdk.appsFlyerDevKey == expected.developerKey)")
        recordPrivacyDiagnostics(sdk, stage: "after_initialize")
        #endif
    }

    private func recordPrivacyDiagnostics(_ sdk: AppsFlyerLib, stage: String) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--analytics-debug") else { return }
        recordDiagnostic("\(stage)_idfv_disabled=\(sdk.disableIDFVCollection)")
        recordDiagnostic("\(stage)_skan_disable_public_getter=\(sdk.disableSKAdNetwork)")
        recordDiagnostic("\(stage)_apple_ads_disabled=\(sdk.disableAppleAdsAttribution)")
        let allPartnersBlocked = sdk.sharingFilter == ["all"]
        recordDiagnostic("\(stage)_partner_sharing_disabled=\(allPartnersBlocked)")
        #endif
    }
}
