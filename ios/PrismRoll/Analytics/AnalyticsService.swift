import Combine
import Foundation

@MainActor
final class AnalyticsService: ObservableObject, AnalyticsRecording {
    static let shared = AnalyticsService()
    static let consentDefaultsKey = "prismroll.analytics.enabled"

    @Published private(set) var isEnabled: Bool
    @Published private(set) var hasMadeChoice: Bool
    @Published private(set) var isAvailable: Bool

    private let defaults: UserDefaults
    private let transport: any AnalyticsTransport
    private let runtime: AnalyticsRuntime
    private var isConfigured = false
    private var isCollecting = false

    convenience init() {
        self.init(defaults: .standard, transport: FirebaseAnalyticsTransport(), runtime: .current)
    }

    init(defaults: UserDefaults, transport: any AnalyticsTransport, runtime: AnalyticsRuntime) {
        self.defaults = defaults
        self.transport = transport
        self.runtime = runtime
        hasMadeChoice = defaults.object(forKey: Self.consentDefaultsKey) != nil
        isEnabled = defaults.bool(forKey: Self.consentDefaultsKey)
        isAvailable = transport.isAvailable
    }

    /// Called during app startup. The SDK starts only for a saved, explicit opt-in.
    func configure() {
        applyChoice()
    }

    /// Consent lives outside the game save, so resetting progress does not change it.
    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.consentDefaultsKey)
        hasMadeChoice = true
        isEnabled = enabled
        applyChoice()
    }

    func record(_ name: String, parameters: [String: Any] = [:]) {
        guard isEnabled, isCollecting else { return }
        transport.record(name, parameters: parameters)
    }

    func screen(_ name: String) {
        record("screen_view", parameters: ["screen_name": name, "screen_class": "PrismRoll"])
    }

    private func applyChoice() {
        // UI tests and ordinary debug runs cannot initialize the SDK, even after opt-in.
        guard runtime.allowsCollection, isAvailable else { return }

        if isEnabled {
            guard !isCollecting else { return }
            if !isConfigured {
                guard transport.configure() else {
                    isAvailable = false
                    return
                }
                isConfigured = true
            }
            transport.setAnalyticsConsent(granted: true)
            transport.setCollectionEnabled(true)
            isCollecting = true
        } else if isConfigured, isCollecting {
            isCollecting = false
            transport.setCollectionEnabled(false)
            transport.setAnalyticsConsent(granted: false)
            transport.resetAnalyticsData()
            // Resetting analytics state must never restore advertising consent.
            transport.setAnalyticsConsent(granted: false)
        }
    }
}
