@preconcurrency import GameKit

@available(iOS 26.0, *)
extension GameCenterActivityCoordinator: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity,
                           completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in
            completionHandler(self?.receive(activity) ?? false)
        }
    }
}
