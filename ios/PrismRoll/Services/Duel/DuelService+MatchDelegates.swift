// GameKit owns these Objective-C callback objects; service access starts at the main-queue boundary.
@preconcurrency import GameKit

extension DuelService: GKMatchDelegate {
    nonisolated func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        guard data.count <= 1_024 else { return }
        let senderID = player.gamePlayerID
        let identity = ObjectIdentifier(match)
        DispatchQueue.main.async { [weak self] in self?.receive(data, senderID: senderID, matchIdentity: identity) }
    }

    nonisolated func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        guard state == .disconnected else { return }
        let playerID = player.gamePlayerID
        let identity = ObjectIdentifier(match)
        DispatchQueue.main.async { [weak self] in self?.peerDisconnected(id: playerID, matchIdentity: identity) }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        let identity = ObjectIdentifier(match)
        DispatchQueue.main.async { [weak self] in self?.connectionFailed(matchIdentity: identity) }
    }

    nonisolated func match(_ match: GKMatch, shouldReinviteDisconnectedPlayer player: GKPlayer) -> Bool { false }
}
