import AppsFlyerLib
import Foundation

@MainActor
final class AppsFlyerAttributionTransport: InstallAttributionTransport {
    private var sdk: AppsFlyerLib?
    private let readiness = AttributionSessionReadiness()

    func initialize(configuration: AppsFlyerConfiguration, sessionReady: @escaping @MainActor () -> Void) {
        // Even shared() is deferred until both affirmative choices and runtime gates pass.
        let sdk = AppsFlyerLib.shared()
        self.sdk = sdk
        applyPrivacy(to: sdk)
        sdk.initialize(devKey: configuration.developerKey, appId: AppsFlyerConfiguration.appleAppID)
        sdk.isStopped = false
        sdk.registerSessionReadyListener { [weak self] in
            guard let self else { return }
            // The SDK documents this Objective-C callback as main-queue delivered.
            // Normalize the SDK boundary explicitly for Swift actor isolation.
            let deliver = self.readiness.delivery(sessionReady)
            DispatchQueue.main.async { deliver() }
        }
    }

    func startSession() {
        sdk?.start()
    }

    func stop() {
        readiness.invalidate()
        sdk?.isStopped = true
    }

    func resume() {
        guard let sdk else { return }
        readiness.invalidate()
        applyPrivacy(to: sdk)
        sdk.isStopped = false
    }

    private func applyPrivacy(to sdk: AppsFlyerLib) {
        // The Strict binary removes IDFA collection code. Keep its remaining optional
        // identifiers, advertising integrations and partner postbacks disabled too.
        sdk.disableIDFVCollection = true
        sdk.disableSKAdNetwork = true
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
}
