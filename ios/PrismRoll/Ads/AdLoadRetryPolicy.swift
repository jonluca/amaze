import Foundation

struct AdLoadRetryPolicy {
    private var lastFailure: Date?

    func canAttempt(at date: Date) -> Bool {
        guard let lastFailure else { return true }
        return date.timeIntervalSince(lastFailure) >= 30
    }

    mutating func failed(at date: Date) { lastFailure = date }
    mutating func succeeded() { lastFailure = nil }
}
