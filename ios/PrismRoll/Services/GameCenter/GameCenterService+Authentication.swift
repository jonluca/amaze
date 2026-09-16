@preconcurrency import GameKit
import UIKit

extension GameCenterService {
    func installAuthenticationHandler() {
        status = "Connecting to Game Center…"
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            DispatchQueue.main.async { self?.handleAuthentication(controller: controller, error: error) }
        }
    }

    func handleAuthentication(controller: UIViewController?, error: Error?) {
        if let controller {
            clearAuthenticatedPlayer()
            pendingAuthenticationController = controller
            presentPendingController()
            return
        }
        pendingAuthenticationController = nil
        if presentation?.kind == .authentication { presentation = nil }
        guard GKLocalPlayer.local.isAuthenticated else {
            clearAuthenticatedPlayer()
            status = signedOutMessage
            return
        }
        acceptAuthenticatedPlayer()
        presentPendingController()
    }

    func acceptAuthenticatedPlayer() {
        let player = GKLocalPlayer.local
        guard player.isAuthenticated else { clearAuthenticatedPlayer(); return }
        let playerID = player.gamePlayerID
        guard !playerID.isEmpty else { return }
        if activePlayerID != playerID {
            // In-flight callbacks carry the previous UUID and can no longer
            // acknowledge reports or drive work for a newly signed-in player.
            sessionID = UUID()
            isSyncing = false
            baselineLoaded = false
            activePlayerID = playerID
            if let latestSnapshot {
                ledger.activate(playerID: playerID, snapshot: latestSnapshot)
                persistence.save(ledger)
            }
        } else if ledger.accounts[playerID] == nil, let latestSnapshot {
            ledger.activate(playerID: playerID, snapshot: latestSnapshot)
            persistence.save(ledger)
        }
        authenticated = true
        playerAlias = player.displayName
        status = "Connected to Game Center."
        beginSynchronization()
    }

    func clearAuthenticatedPlayer() {
        sessionID = UUID()
        activePlayerID = nil
        authenticated = false
        playerAlias = nil
        baselineLoaded = false
        isSyncing = false
        status = signedOutMessage
        if presentation?.kind == .dashboard { presentation = nil }
    }

    func sessionIsCurrent(_ session: UUID, playerID: String) -> Bool {
        sessionID == session && activePlayerID == playerID
            && GKLocalPlayer.local.isAuthenticated && GKLocalPlayer.local.gamePlayerID == playerID
    }
}
