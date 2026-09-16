import Combine
@preconcurrency import GameKit
import Network
import UIKit

/// The sole owner of Game Center authentication and reporting. Every entry point
/// runs on the main actor; GameKit and reachability callbacks cross here once.
@MainActor
final class GameCenterService: NSObject, ObservableObject {
    @Published var authenticated = false
    @Published var playerAlias: String?
    @Published var status = "Sign in to Game Center to share your achievements and scores."
    @Published var isSyncing = false
    @Published var presentation: GameCenterPresentation? {
        didSet {
            if oldValue != nil && presentation == nil { presentationAwaitingDismissal = true }
        }
    }

    // Internal for the focused authentication/reporting/presentation extensions.
    let runtime: GameCenterRuntime
    let persistence: GameCenterReportPersistence
    var ledger: GameCenterReportLedger
    var latestSnapshot: GameCenterProgressSnapshot?
    var activePlayerID: String?
    var sessionID = UUID()
    var started = false
    var baselineLoaded = false
    var baselineAttempted = false
    var failedReportResources: Set<String> = []
    var presentationAllowed = false
    var presentationAwaitingDismissal = false
    var pendingAuthenticationController: UIViewController?
    var pendingDashboard: GameCenterDashboardDestination?
    var reachability: NWPathMonitor?

    init(persistence: GameCenterReportPersistence = GameCenterReportPersistence(),
         runtime: GameCenterRuntime = .current) {
        self.persistence = persistence
        self.runtime = runtime
        ledger = runtime == .live ? persistence.load() : GameCenterReportLedger()
        super.init()
    }

    deinit { reachability?.cancel() }

    func start() {
        guard !started else { return }
        started = true
        guard runtime == .live else {
            authenticated = runtime == .authenticatedFixture
            playerAlias = authenticated ? "Prism Player" : nil
            status = authenticated ? "Connected to Game Center." : signedOutMessage
            return
        }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async { self?.refresh() }
        }
        monitor.start(queue: DispatchQueue(label: "com.jonluca.prismroll.gamecenter.reachability"))
        reachability = monitor
        installAuthenticationHandler()
    }

    func observe(_ snapshot: GameCenterProgressSnapshot) {
        guard latestSnapshot != snapshot else { return }
        latestSnapshot = snapshot
        guard runtime == .live, let playerID = activePlayerID else { return }
        guard sessionIsCurrent(sessionID, playerID: playerID) else { refresh(); return }
        if ledger.accounts[playerID] == nil {
            ledger.activate(playerID: playerID, snapshot: snapshot)
        } else {
            ledger.observe(snapshot, playerID: playerID, allowBanners: baselineLoaded)
        }
        persistence.save(ledger)
        beginSynchronization()
    }

    /// Foregrounding and network recovery retry durable reports without showing
    /// a new sign-in controller after the player has dismissed authentication.
    func refresh() {
        guard started, runtime == .live else { return }
        if GKLocalPlayer.local.isAuthenticated {
            acceptAuthenticatedPlayer()
        } else if authenticated {
            clearAuthenticatedPlayer()
        }
    }

    func retry() {
        guard started else { start(); return }
        if runtime == .live && GKLocalPlayer.local.isAuthenticated {
            acceptAuthenticatedPlayer()
        } else if runtime != .authenticatedFixture {
            // GameKit owns sign-in and may not invoke a reassigned handler. Keep
            // its original observer installed, present any supplied controller,
            // and give a stable fallback when sign-in is unavailable.
            if pendingAuthenticationController == nil && presentation?.kind != .authentication {
                clearAuthenticatedPlayer()
            }
            presentPendingController()
        }
    }

    func setPresentationAllowed(_ allowed: Bool) {
        presentationAllowed = allowed
        if allowed { presentPendingController() }
    }

    func showDashboard(_ destination: GameCenterDashboardDestination) {
        pendingDashboard = destination
        if !started { start() }
        else if !authenticated { retry() }
        presentPendingController()
    }

    func presentationDidDismiss() {
        presentation = nil
        presentationAwaitingDismissal = false
        presentPendingController()
    }

    var signedOutMessage: String {
        "Open Settings → Game Center to sign in, then return to Prism Roll. Your solo progress is saved."
    }
}
