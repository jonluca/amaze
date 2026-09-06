import Combine
@preconcurrency import GameKit
import UIKit

/// A real two-player Game Center race. Single-player gameplay never depends on this service.
@MainActor
final class DuelService: NSObject, ObservableObject {
    @Published private(set) var authenticated = false
    @Published private(set) var status = "Sign in to Game Center to race a friend."
    @Published private(set) var isMatching = false
    @Published private(set) var isPlaying = false
    @Published private(set) var opponentName = "Opponent"
    @Published private(set) var opponentProgress = 0.0
    @Published private(set) var seed: Int?
    @Published private(set) var matchID: String?
    @Published private(set) var didWin: Bool?

    var onStart: ((Int, String) -> Void)?
    var onFinish: ((Bool) -> Void)?
    private var currentMatch: GKMatch?
    private var matchmakingController: GKMatchmakerViewController?
    private var session: DuelSession?
    private var authenticationStarted = false

    func authenticate() {
        guard !authenticationStarted else {
            authenticated = GKLocalPlayer.local.isAuthenticated
            return
        }
        authenticationStarted = true
        status = "Connecting to Game Center…"
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            DispatchQueue.main.async { self?.handleAuthentication(controller: controller, error: error) }
        }
    }

    func findMatch() {
        guard !isMatching, !isPlaying else { return }
        guard GKLocalPlayer.local.isAuthenticated else {
            authenticate()
            status = "Sign in to Game Center, then choose Find match."
            return
        }
        authenticated = true
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        // Change this when the level generator or wire protocol changes.
        request.playerGroup = 1
        guard let controller = GKMatchmakerViewController(matchRequest: request) else {
            status = "Game Center matchmaking is unavailable."
            return
        }
        presentMatchmaker(controller)
    }

    func cancel() {
        let wasActive = isMatching || isPlaying
        disconnect()
        resetPublishedMatch()
        status = wasActive ? "Duel ended. Your solo progress is saved." : "Ready for a new match."
    }

    func sendProgress(painted: Int, total: Int, moves: Int) {
        guard var state = session, state.started, state.winnerID == nil,
              (1...400).contains(total), (1...total).contains(painted),
              (0...1_000_000).contains(moves), painted >= state.localPainted,
              moves >= state.localMoves, state.total == 0 || state.total == total else { return }
        state.total = total
        state.localPainted = painted
        state.localMoves = moves
        session = state
        _ = send(.progress(id: state.id, painted: painted, total: total, moves: moves))
    }

    func submitCompletion() {
        guard let state = session, state.started, state.winnerID == nil,
              state.total > 0, state.localPainted == state.total else { return }
        if state.isHost { resolveWinner(state.localID) }
        else if send(.finish(id: state.id)) { status = "Maze complete — waiting for the result…" }
    }

    func receive(_ data: Data, senderID: String, matchIdentity: ObjectIdentifier) {
        guard let match = currentMatch, ObjectIdentifier(match) == matchIdentity, match.players.count == 1,
              match.players.first?.gamePlayerID == senderID,
              data.count <= 1_024,
              let message = try? JSONDecoder().decode(DuelMessage.self, from: data) else { return }
        switch message {
        case .hello(let version):
            guard version == 1 else { endWithError("Your opponent needs a compatible app version."); return }
            prepareHostSession()
        case .setup(let id, let proposedSeed):
            receiveSetup(id: id, proposedSeed: proposedSeed, from: senderID)
        case .ready(let id):
            guard let state = session, state.id == id, state.isHost, !state.started else { return }
            if send(.start(id: id)) { startRound() }
        case .start(let id):
            guard let state = session, state.id == id, !state.isHost,
                  state.hostID == senderID else { return }
            startRound()
        case .progress(let id, let painted, let total, let moves):
            receiveProgress(id: id, painted: painted, total: total, moves: moves)
        case .finish(let id):
            guard let state = session, state.id == id, state.isHost, state.started,
                  state.total > 0, state.opponentPainted == state.total else { return }
            resolveWinner(senderID)
        case .result(let id, let winner):
            guard let state = session, state.id == id, !state.isHost, state.started,
                  state.hostID == senderID,
                  winner == state.localID || winner == state.opponentID else { return }
            finish(winner: winner)
        }
    }

    func accept(_ match: GKMatch, from controller: GKMatchmakerViewController) {
        guard matchmakingController === controller else { match.disconnect(); return }
        controller.dismiss(animated: true)
        matchmakingController = nil
        guard match.players.count == 1, match.expectedPlayerCount == 0,
              match.players[0].gamePlayerID != GKLocalPlayer.local.gamePlayerID else {
            match.disconnect()
            endWithError("A two-player match could not be established.")
            return
        }
        currentMatch = match
        match.delegate = self
        opponentName = match.players[0].displayName
        status = "Preparing the same maze for both players…"
        _ = send(.hello(version: 1))
        prepareHostSession()
    }

    func matchmakingEnded(_ controller: GKMatchmakerViewController, error: Error?) {
        guard matchmakingController === controller else { return }
        endWithError(error == nil ? "Matchmaking cancelled." : "Game Center could not find a match. Try again.")
    }

    func peerDisconnected(id: String, matchIdentity: ObjectIdentifier) {
        guard let match = currentMatch, ObjectIdentifier(match) == matchIdentity,
              match.players.contains(where: { $0.gamePlayerID == id })
                || id == session?.opponentID else { return }
        if didWin != nil { disconnect(); return }
        endWithError("Your opponent disconnected. No result was awarded.")
    }

    func connectionFailed(matchIdentity: ObjectIdentifier) {
        guard let match = currentMatch, ObjectIdentifier(match) == matchIdentity else { return }
        endWithError("The duel connection was interrupted. Try a new match.")
    }

    func acceptedInvite(_ invite: GKInvite) {
        guard !isMatching, !isPlaying, let controller = GKMatchmakerViewController(invite: invite) else { return }
        presentMatchmaker(controller)
    }

    private func handleAuthentication(controller: UIViewController?, error: Error?) {
        if let controller {
            guard let presenter = DuelPresenter.activeController, !presenter.isBeingPresented else {
                status = "Open Game Center in Settings to sign in."
                return
            }
            presenter.present(controller, animated: true)
            return
        }
        authenticated = GKLocalPlayer.local.isAuthenticated
        if authenticated {
            GKLocalPlayer.local.unregisterListener(self)
            GKLocalPlayer.local.register(self)
            status = "Ready to race through Game Center."
        } else {
            status = "Game Center is unavailable. Sign in through Settings to play Duel."
            if isMatching || isPlaying { cancel() }
        }
    }

    private func presentMatchmaker(_ controller: GKMatchmakerViewController) {
        guard let presenter = DuelPresenter.activeController else {
            status = "Return to the app to find a match."
            return
        }
        disconnect()
        resetPublishedMatch()
        matchmakingController = controller
        controller.matchmakerDelegate = self
        isMatching = true
        status = "Finding another player…"
        presenter.present(controller, animated: true)
    }

    private func prepareHostSession() {
        guard let match = currentMatch, let opponent = match.players.first else { return }
        let local = GKLocalPlayer.local.gamePlayerID
        let host = min(local, opponent.gamePlayerID)
        guard host == local else { return }
        if session == nil {
            session = DuelSession(id: UUID().uuidString, seed: Int.random(in: 1...1_000_000),
                localID: local, opponentID: opponent.gamePlayerID, hostID: host)
        }
        guard let state = session, !state.started else { return }
        _ = send(.setup(id: state.id, seed: state.seed))
    }

    private func receiveSetup(id: String, proposedSeed: Int, from sender: String) {
        let local = GKLocalPlayer.local.gamePlayerID
        guard UUID(uuidString: id) != nil, (1...1_000_000).contains(proposedSeed),
              sender == min(local, sender), sender != local else { return }
        if let existing = session {
            guard existing.id == id, existing.seed == proposedSeed, !existing.started else { return }
        } else {
            session = DuelSession(id: id, seed: proposedSeed, localID: local, opponentID: sender, hostID: sender)
        }
        _ = send(.ready(id: id))
    }

    private func startRound() {
        guard var state = session, !state.started else { return }
        state.started = true
        session = state
        matchID = state.id
        isMatching = false
        isPlaying = true
        status = "Paint every corridor before \(opponentName)."
        seed = state.seed
        onStart?(state.seed, state.id)
    }

    private func receiveProgress(id: String, painted: Int, total: Int, moves: Int) {
        guard var state = session, state.id == id, state.started, state.winnerID == nil,
              (1...400).contains(total), (1...total).contains(painted), (0...1_000_000).contains(moves),
              painted >= state.opponentPainted, moves >= state.opponentMoves,
              state.total == 0 || state.total == total else { return }
        state.total = total
        state.opponentPainted = painted
        state.opponentMoves = moves
        session = state
        opponentProgress = Double(painted) / Double(total)
    }

    private func resolveWinner(_ winner: String) {
        guard let state = session, state.isHost, state.winnerID == nil else { return }
        if send(.result(id: state.id, winner: winner)) { finish(winner: winner) }
    }

    private func finish(winner: String) {
        guard var state = session, state.winnerID == nil else { return }
        state.winnerID = winner
        session = state
        isPlaying = false
        didWin = winner == state.localID
        status = didWin == true ? "You won the duel!" : "\(opponentName) finished first."
        onFinish?(winner == state.localID)
        // Keep the connection until the player leaves so a reliable result can arrive.
    }

    @discardableResult
    private func send(_ message: DuelMessage) -> Bool {
        guard let match = currentMatch, let data = try? JSONEncoder().encode(message), data.count <= 1_024 else { return false }
        do {
            try match.sendData(toAllPlayers: data, with: .reliable)
            return true
        } catch {
            endWithError("The duel connection was interrupted. Try a new match.")
            return false
        }
    }

    private func endWithError(_ message: String) {
        disconnect()
        resetPublishedMatch()
        status = message
    }

    private func disconnect() {
        matchmakingController?.matchmakerDelegate = nil
        matchmakingController?.dismiss(animated: true)
        matchmakingController = nil
        GKMatchmaker.shared().cancel()
        currentMatch?.delegate = nil
        currentMatch?.disconnect()
        currentMatch = nil
        session = nil
        isMatching = false
        isPlaying = false
    }

    private func resetPublishedMatch() {
        opponentName = "Opponent"
        opponentProgress = 0
        seed = nil
        matchID = nil
        didWin = nil
    }
}
