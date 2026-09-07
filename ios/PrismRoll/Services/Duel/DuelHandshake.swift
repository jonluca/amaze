/// The matchmaking group and wire handshake identify the same maze generator.
struct DuelHandshake {
    static let version = 3

    private enum State {
        case waiting, compatible, rejected
    }
    private var state = State.waiting

    var isCompatible: Bool { state == .compatible }

    /// Invite connections must pass the same check as automatically matched peers.
    /// Rejecting a connection is terminal; a new match needs a fresh handshake.
    mutating func accepts(_ message: DuelMessage) -> Bool {
        guard state != .rejected else { return false }
        if case .hello(let version) = message {
            state = version == Self.version ? .compatible : .rejected
        } else if state != .compatible {
            state = .rejected
        }
        return isCompatible
    }
}
