import Foundation

/// The original error and its userInfo never cross the SDK boundary.
struct DiagnosticFailure: Hashable, Sendable {
    let operation: DiagnosticOperation
    let domain: DiagnosticErrorDomain
    let code: Int

    init(error: Error, operation: DiagnosticOperation) {
        let error = error as NSError
        self.operation = operation
        domain = DiagnosticErrorDomain(error.domain)
        code = domain != .other && (-99_999...99_999).contains(error.code) ? error.code : 0
    }

    var reportError: NSError {
        NSError(domain: "com.jonluca.prismroll.\(operation.rawValue).\(domain.rawValue)", code: code)
    }
}
