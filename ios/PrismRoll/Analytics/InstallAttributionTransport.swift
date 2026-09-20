@MainActor
protocol InstallAttributionTransport: AnyObject {
    func initialize(configuration: AppsFlyerConfiguration, sessionReady: @escaping @MainActor () -> Void)
    func startSession()
    func stop()
    func resume()
}
