@preconcurrency import GameKit

extension DuelService: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        DispatchQueue.main.async { [weak self] in self?.matchmakingEnded(viewController, error: nil) }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in self?.matchmakingEnded(viewController, error: error) }
    }

    nonisolated func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { match.disconnect(); return }
            self.accept(match, from: viewController)
        }
    }
}
