#if canImport(UIKit)
import XCTest
import UIKit
@testable import PrismRoll

@MainActor
final class GameCenterServiceTests: XCTestCase {
    func testSuppressedRuntimeDoesNotAuthenticateOrWriteProgress() {
        let service = GameCenterService(runtime: .suppressed)
        service.observe(.init(classicCompleted: 50))
        service.start()
        service.retry()
        service.refresh()
        XCTAssertFalse(service.authenticated)
        XCTAssertFalse(service.isSyncing)
        XCTAssertTrue(service.ledger.accounts.isEmpty)
        XCTAssertNil(service.presentation)
    }

    func testSignedOutRetryWithoutAnotherAuthenticationCallbackKeepsSettingsGuidance() {
        let service = GameCenterService(runtime: .suppressed)
        service.start()
        // Model a prior initialization that supplies no new controller/callback.
        // Retry uses the same signed-out path in suppressed and live runtimes.
        service.status = "Connecting to Game Center…"
        service.retry()
        XCTAssertEqual(service.status, service.signedOutMessage)
        XCTAssertFalse(service.authenticated)
        XCTAssertFalse(service.isSyncing)
        XCTAssertNil(service.presentation)
        service.retry()
        XCTAssertEqual(service.status, service.signedOutMessage)
    }

    func testSignedOutRetryPresentsExistingControllerWithoutRestartingAuthentication() {
        let service = GameCenterService(runtime: .suppressed)
        service.start()
        let controller = UIViewController()
        service.pendingAuthenticationController = controller
        service.retry()
        XCTAssertNil(service.presentation)
        service.setPresentationAllowed(true)
        XCTAssertTrue(service.presentation?.controller === controller)
        XCTAssertEqual(service.presentation?.kind, .authentication)
    }

    #if DEBUG
    func testDashboardWaitsForSafePresentationAndCanDismiss() {
        let service = GameCenterService(runtime: .authenticatedFixture)
        service.start()
        service.showDashboard(.leaderboards)
        XCTAssertNil(service.presentation)
        service.setPresentationAllowed(true)
        XCTAssertEqual(service.presentation?.kind, .dashboard)
        service.presentation = nil
        service.presentationDidDismiss()
        XCTAssertNil(service.presentation)
        XCTAssertTrue(service.authenticated)
    }

    func testQueuedDashboardCannotReplaceControllerWhileDismissalIsInFlight() {
        let service = GameCenterService(runtime: .authenticatedFixture)
        service.start()
        service.setPresentationAllowed(true)
        service.showDashboard(.achievements)
        service.presentation = nil
        service.showDashboard(.leaderboards)
        XCTAssertNil(service.presentation)
        service.presentationDidDismiss()
        XCTAssertEqual(service.presentation?.kind, .dashboard)
    }
    #endif
}
#endif
