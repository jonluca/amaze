enum MoveDirection: String, CaseIterable, Codable, Sendable {
    case up, down, left, right

    var rowDelta: Int {
        switch self {
        case .up: -1
        case .down: 1
        case .left, .right: 0
        }
    }

    var columnDelta: Int {
        switch self {
        case .left: -1
        case .right: 1
        case .up, .down: 0
        }
    }
}
