@MainActor
protocol DiagnosticsRecording: AnyObject {
    func record(error: Error, operation: DiagnosticOperation)
}
