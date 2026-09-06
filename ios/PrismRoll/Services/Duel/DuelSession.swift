struct DuelSession {
    let id: String
    let seed: Int
    let localID: String
    let opponentID: String
    let hostID: String
    var started = false
    var winnerID: String?
    var localPainted = 0
    var opponentPainted = 0
    var total = 0
    var localMoves = 0
    var opponentMoves = 0

    var isHost: Bool { localID == hostID }
}
