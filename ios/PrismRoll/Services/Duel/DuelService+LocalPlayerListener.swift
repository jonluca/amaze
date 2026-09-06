@preconcurrency import GameKit

extension DuelService: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        DispatchQueue.main.async { [weak self] in self?.acceptedInvite(invite) }
    }
}
