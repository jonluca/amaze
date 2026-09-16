#if canImport(UIKit)
import XCTest
@testable import PrismRoll

final class DiagnosticFailureTests: XCTestCase {
    func testOnlyAllowedDomainAndBoundedCodeReachReport() {
        let privateError = NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteOutOfSpace.rawValue,
                                   userInfo: [NSLocalizedDescriptionKey: "private receipt and player",
                                              NSFilePathErrorKey: "/private/user/progress.json",
                                              NSUnderlyingErrorKey: NSError(domain: "private-transaction-id", code: 42)])
        let failure = DiagnosticFailure(error: privateError, operation: .coinDelivery)
        XCTAssertEqual(failure.operation, .coinDelivery)
        XCTAssertEqual(failure.domain, .cocoa)
        XCTAssertEqual(failure.code, CocoaError.fileWriteOutOfSpace.rawValue)
        XCTAssertEqual(failure.reportError.domain, "com.jonluca.prismroll.coin_delivery.cocoa")
        XCTAssertTrue(failure.reportError.userInfo.isEmpty)
        XCTAssertFalse(failure.reportError.localizedDescription.contains("private"))
    }

    func testUnknownDomainsAndUnboundedCodesCannotCarryIdentifiers() {
        let unknown = DiagnosticFailure(error: NSError(domain: "receipt-123-user-456", code: 98765), operation: .storeLoad)
        XCTAssertEqual(unknown.domain, .other)
        XCTAssertEqual(unknown.code, 0)
        XCTAssertEqual(unknown.reportError.domain, "com.jonluca.prismroll.store_load.other")
        for code in [Int.min, -100_000, 100_000, Int.max] {
            let bounded = DiagnosticFailure(error: NSError(domain: NSURLErrorDomain, code: code), operation: .storeLoad)
            XCTAssertEqual(bounded.domain, .url)
            XCTAssertEqual(bounded.code, 0)
        }
    }

    func testFailureFingerprintExcludesMessagesAndPaths() {
        let first = DiagnosticFailure(error: NSError(domain: NSPOSIXErrorDomain, code: 28,
                                                     userInfo: [NSFilePathErrorKey: "/first/user"]), operation: .progressSave)
        let second = DiagnosticFailure(error: NSError(domain: NSPOSIXErrorDomain, code: 28,
                                                      userInfo: [NSFilePathErrorKey: "/second/user"]), operation: .progressSave)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set([first, second]).count, 1)
    }
}
#endif
