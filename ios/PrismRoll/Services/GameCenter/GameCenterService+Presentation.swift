@preconcurrency import GameKit
import SwiftUI

extension GameCenterService: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        DispatchQueue.main.async { [weak self] in
            guard self?.presentation?.controller === gameCenterViewController else { return }
            self?.presentation = nil
        }
    }

    func presentPendingController() {
        guard presentationAllowed, presentation == nil, !presentationAwaitingDismissal else { return }
        if let controller = pendingAuthenticationController {
            pendingAuthenticationController = nil
            presentation = GameCenterPresentation(kind: .authentication, controller: controller)
            return
        }
        guard authenticated, let destination = pendingDashboard else { return }
        pendingDashboard = nil
        #if DEBUG
        if runtime == .authenticatedFixture {
            let controller = UIHostingController(rootView: GameCenterDashboardFixture(destination: destination) { [weak self] in
                self?.presentation = nil
            })
            presentation = GameCenterPresentation(kind: .dashboard, controller: controller)
            return
        }
        #endif
        guard runtime == .live, GKLocalPlayer.local.isAuthenticated else { return }
        let controller: GKGameCenterViewController
        switch destination {
        case .achievements: controller = GKGameCenterViewController(state: .achievements)
        case .leaderboards: controller = GKGameCenterViewController(state: .leaderboards)
        case .leaderboard(let board):
            controller = GKGameCenterViewController(leaderboardID: board.id, playerScope: .global, timeScope: .allTime)
        }
        controller.gameCenterDelegate = self
        presentation = GameCenterPresentation(kind: .dashboard, controller: controller)
    }
}
