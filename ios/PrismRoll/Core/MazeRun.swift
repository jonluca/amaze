struct MazeRun: Codable, Equatable, Sendable {
    let level: MazeLevel
    private(set) var position: GridCell
    private(set) var painted: Set<GridCell>
    private(set) var moves: Int
    private(set) var extraMovesGranted: Int
    private var hintRoute: [MoveDirection]
    private(set) var hintIsOptimal = false

    private enum CodingKeys: String, CodingKey {
        case level, position, painted, moves, extraMovesGranted, hintRoute
    }

    init(level: MazeLevel) {
        self.level = level
        position = level.start
        painted = [level.start]
        moves = 0
        extraMovesGranted = 0
        hintRoute = level.solution
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        level = try values.decode(MazeLevel.self, forKey: .level)
        position = try values.decode(GridCell.self, forKey: .position)
        painted = try values.decode(Set<GridCell>.self, forKey: .painted)
        moves = try values.decode(Int.self, forKey: .moves)
        extraMovesGranted = max(0, try values.decodeIfPresent(Int.self, forKey: .extraMovesGranted) ?? 0)
        hintRoute = try values.decodeIfPresent([MoveDirection].self, forKey: .hintRoute)
            ?? MazeSolver.coveringRoute(openCells: level.openCells, position: position, painted: painted)
            ?? []
    }

    var isComplete: Bool { painted == level.openCells }
    var isFailed: Bool { !isComplete && remainingMoves == 0 }
    var effectiveMoveLimit: Int? {
        level.moveLimit.map { base in
            let sum = base.addingReportingOverflow(extraMovesGranted)
            return sum.overflow ? Int.max : sum.partialValue
        }
    }
    var remainingMoves: Int? { effectiveMoveLimit.map { max(0, $0 - moves) } }
    var collectedCoinCells: Set<GridCell> { painted.intersection(level.coinCells) }
    var hintDirection: MoveDirection? { isComplete || isFailed ? nil : hintRoute.first }

    /// A false value means useful guidance remains, but the challenge budget may not suffice.
    var hintIsGuaranteed: Bool {
        !isFailed && (remainingMoves.map { hintRoute.count <= $0 } ?? true)
    }

    /// The app owns ad eligibility. A rewarded allowance can revive a failed move challenge.
    @discardableResult
    mutating func grantExtraMoves(count: Int) -> Bool {
        guard count > 0, !isComplete, let limit = effectiveMoveLimit else { return false }
        let granted = min(count, Int.max - limit)
        guard granted > 0 else { return false }
        extraMovesGranted += granted
        return true
    }

    @discardableResult
    mutating func move(_ direction: MoveDirection, recomputeFallbackHint: Bool = true) -> [GridCell] {
        guard !isComplete, !isFailed else { return [] }
        let cells = MazeSolver.path(from: position, direction: direction, in: level.openCells)
        guard let destination = cells.last else { return [] }
        position = destination
        painted.formUnion(cells)
        moves += 1
        if hintRoute.first == direction {
            hintRoute.removeFirst()
        } else {
            hintIsOptimal = false
            hintRoute = recomputeFallbackHint ? (MazeSolver.coveringRoute(
                openCells: level.openCells, position: position, painted: painted
            ) ?? []) : []
        }
        if isComplete { hintRoute.removeAll() }
        return cells
    }

    /// Install only routes returned by a proved optimizer result. Legality is
    /// checked here; proving minimality remains the native solver's responsibility.
    @discardableResult
    mutating func installOptimalRoute(_ route: [MoveDirection]) -> Bool {
        var cursor = position
        var covered = painted
        for direction in route {
            guard covered != level.openCells else { return false }
            let cells = MazeSolver.path(from: cursor, direction: direction, in: level.openCells)
            guard let destination = cells.last else { return false }
            covered.formUnion(cells)
            cursor = destination
        }
        guard covered == level.openCells else { return false }
        hintRoute = route
        hintIsOptimal = true
        return true
    }

    // Proof availability is ephemeral and is deliberately not trusted on decode.
    // Equality continues to describe persisted gameplay state.
    static func == (lhs: MazeRun, rhs: MazeRun) -> Bool {
        lhs.level == rhs.level && lhs.position == rhs.position && lhs.painted == rhs.painted
            && lhs.moves == rhs.moves && lhs.extraMovesGranted == rhs.extraMovesGranted
            && lhs.hintRoute == rhs.hintRoute
    }

    mutating func reset() { self = MazeRun(level: level) }
}
