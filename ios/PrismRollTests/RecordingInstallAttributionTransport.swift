@testable import PrismRoll

@MainActor
final class RecordingInstallAttributionTransport: InstallAttributionTransport {
    private(set) var actions: [String] = []
    private var sessionReady: (@MainActor () -> Void)?

    func initialize(configuration: AppsFlyerConfiguration, sessionReady: @escaping @MainActor () -> Void) {
        actions.append("initialize")
        self.sessionReady = sessionReady
    }

    func startSession() { actions.append("start") }
    func stop() { actions.append("stop") }
    func resume() { actions.append("resume") }
    func signalReady() { sessionReady?() }
}
