#if canImport(UIKit)
import StoreKit
import StoreKitTest
import XCTest
@testable import PrismRoll

@MainActor
final class DiagnosticsIntegrationTests: XCTestCase {
    func testCorruptWalletReportsLoadAndSaveFailuresWithoutOverwritingEvidence() throws {
        let suite = "DiagnosticsCorruptWallet.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let url = FileManager.default.temporaryDirectory.appending(path: suite)
        let corrupt = Data("incomplete wallet".utf8)
        try corrupt.write(to: url)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: url) }
        let recorder = Recorder()
        let store = GameStore(defaults: defaults, progressFileURL: url, diagnostics: recorder)
        store.setHaptics(false)
        XCTAssertEqual(recorder.failures.map(\.operation), [.progressLoad, .progressSave])
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testCoinDeliveryFailureReportsCategoryAndLeavesTransactionUnfinished() async throws {
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PrismRoll-Local", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: fixture)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions(); session.resetToDefaultState() }
        let recorder = Recorder()
        let purchases = PurchaseService(diagnostics: recorder) { _ in
            throw NSError(domain: NSCocoaErrorDomain, code: CocoaError.fileWriteOutOfSpace.rawValue,
                          userInfo: [NSFilePathErrorKey: "/private/wallet.json"])
        }
        await purchases.load()
        await purchases.purchaseCoins(productID: "com.jonluca.prismroll.coins.1000")
        XCTAssertFalse(recorder.failures.isEmpty)
        XCTAssertTrue(recorder.failures.allSatisfy { $0.operation == .coinDelivery && $0.domain == .cocoa })
        XCTAssertTrue(recorder.failures.allSatisfy { $0.reportError.userInfo.isEmpty })
        XCTAssertTrue(purchases.coinStatus.hasPrefix("Your purchase is saved by the App Store."))
        var hasUnfinishedCoin = false
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result, transaction.productType == .consumable {
                hasUnfinishedCoin = true
            }
        }
        XCTAssertTrue(hasUnfinishedCoin)
    }

    private final class Recorder: DiagnosticsRecording {
        var failures: [DiagnosticFailure] = []
        func record(error: Error, operation: DiagnosticOperation) {
            failures.append(DiagnosticFailure(error: error, operation: operation))
        }
    }
}
#endif
