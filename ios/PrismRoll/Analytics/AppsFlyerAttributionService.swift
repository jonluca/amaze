import Combine
import Foundation

@MainActor
final class AppsFlyerAttributionService: ObservableObject, InstallAttributionConsentUpdating {
    static let shared = AppsFlyerAttributionService(
        defaults: .standard, configuration: AppsFlyerConfiguration(bundle: .main),
        transport: AppsFlyerAttributionTransport(), runtime: .current
    )
    static let consentDefaultsKey = "prismroll.analytics.appsflyer.enabled.v1"

    @Published private(set) var isEnabled: Bool
    let isAvailable: Bool
    private let defaults: UserDefaults
    private let configuration: AppsFlyerConfiguration?
    private let transport: any InstallAttributionTransport
    private let runtime: AnalyticsRuntime
    private var usageAnalyticsEnabled = false
    private var isInitialized = false
    private var isCollecting = false

    init(defaults: UserDefaults, configuration: AppsFlyerConfiguration?,
         transport: any InstallAttributionTransport, runtime: AnalyticsRuntime) {
        self.defaults = defaults
        self.configuration = configuration
        self.transport = transport
        self.runtime = runtime
        isEnabled = defaults.bool(forKey: Self.consentDefaultsKey)
        isAvailable = configuration != nil
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.consentDefaultsKey)
        isEnabled = enabled
        applyChoice()
    }

    func setUsageAnalyticsEnabled(_ enabled: Bool) {
        usageAnalyticsEnabled = enabled
        applyChoice()
    }

    private func applyChoice() {
        guard runtime.allowsCollection, isEnabled, usageAnalyticsEnabled,
              let configuration else {
            if isCollecting {
                isCollecting = false
                transport.stop()
            }
            return
        }
        guard !isCollecting else { return }
        isCollecting = true
        if isInitialized {
            // AppsFlyer's stop(false) resumes the SDK. Do not also call start here.
            transport.resume()
        } else {
            isInitialized = true
            transport.initialize(configuration: configuration) { [weak self] in
                guard let self, self.isCollecting, self.isEnabled, self.usageAnalyticsEnabled else { return }
                self.transport.startSession()
            }
        }
    }
}
