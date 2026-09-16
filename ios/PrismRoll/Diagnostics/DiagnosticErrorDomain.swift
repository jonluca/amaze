import Foundation

/// An allowlist prevents custom NSError domains from carrying user information.
enum DiagnosticErrorDomain: String, Sendable {
    case cocoa
    case url
    case posix
    case storeKit = "storekit"
    case other

    init(_ domain: String) {
        switch domain {
        case NSCocoaErrorDomain: self = .cocoa
        case NSURLErrorDomain: self = .url
        case NSPOSIXErrorDomain: self = .posix
        case "SKErrorDomain", "StoreKit.StoreKitError": self = .storeKit
        default: self = .other
        }
    }
}
