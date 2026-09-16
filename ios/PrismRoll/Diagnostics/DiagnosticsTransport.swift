/// Injectable SDK boundary: consent and payload behavior can be tested offline.
@MainActor
protocol DiagnosticsTransport: AnyObject {
    var isAvailable: Bool { get }
    func configure() -> Bool
    func sendPendingReports()
    func record(_ failure: DiagnosticFailure)
    func waitUntilReadyForSmokeTest() async
}
