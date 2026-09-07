struct MazeLevel: Codable, Equatable, Sendable {
    let number: Int
    let mode: GameMode
    let width: Int
    let height: Int
    let openCells: Set<GridCell>
    let start: GridCell
    let solution: [MoveDirection]
    let moveLimit: Int?
    let timeLimit: Double?
    let coinCells: Set<GridCell>

    static let coinValue = 5
    static let maximumCoinCount = 3

    private enum CodingKeys: String, CodingKey {
        case number, mode, width, height, openCells, start, solution, moveLimit, timeLimit, coinCells
    }

    init(
        number: Int, mode: GameMode, width: Int, height: Int,
        openCells: Set<GridCell>, start: GridCell, solution: [MoveDirection],
        moveLimit: Int?, timeLimit: Double? = nil, coinCells: Set<GridCell> = []
    ) {
        self.number = number
        self.mode = mode
        self.width = width
        self.height = height
        self.openCells = openCells
        self.start = start
        self.solution = solution
        self.moveLimit = moveLimit
        self.timeLimit = timeLimit
        self.coinCells = coinCells
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        number = try values.decode(Int.self, forKey: .number)
        mode = try values.decode(GameMode.self, forKey: .mode)
        width = try values.decode(Int.self, forKey: .width)
        height = try values.decode(Int.self, forKey: .height)
        openCells = try values.decode(Set<GridCell>.self, forKey: .openCells)
        start = try values.decode(GridCell.self, forKey: .start)
        solution = try values.decode([MoveDirection].self, forKey: .solution)
        moveLimit = try values.decodeIfPresent(Int.self, forKey: .moveLimit)
        timeLimit = try values.decodeIfPresent(Double.self, forKey: .timeLimit)
        coinCells = try values.decodeIfPresent(Set<GridCell>.self, forKey: .coinCells) ?? []
    }

    static func generate(number: Int, mode: GameMode) -> MazeLevel {
        let number = max(1, number)
        let difficulty = MazeDifficulty(number: number, mode: mode)
        let size = difficulty.size
        let salt: UInt64
        switch mode {
        case .endless: salt = 0x505249534D524F4C
        case .challenge: salt = 0x4348414C4C454E47
        case .timed: salt = 0x54494D4552555348
        }
        var random = SeededGenerator(seed: UInt64(number) &* 0x9E3779B97F4A7C15 ^ salt)
        let width = size
        let height = size
        var selected: MazeLayout?
        var qualifyingCandidates = 0

        // Score structure after improving routes. Raw greedy length does not
        // establish difficulty; distinct segment coverage and branches do.
        for attempt in 0..<48 {
            var candidate: Set<GridCell> = []
            let density = [66, 72, 78, 74][attempt % 4]
            for row in 0..<height {
                for column in 0..<width where random.integer(lessThan: 100) < density {
                    candidate.insert(GridCell(row: row, column: column))
                }
            }
            guard let layout = MazeLayout.candidate(cells: candidate, difficulty: difficulty) else { continue }
            qualifyingCandidates += 1
            if selected == nil || difficulty.score(layout) > difficulty.score(selected!) {
                selected = layout
            }
            if attempt >= 11 && qualifyingCandidates >= 3 { break }
        }
        let board = selected ?? MazeFallbackLayouts.make(size: size, orientation: random.integer(lessThan: 8))
        let allowance = number <= 5 ? 3 : number <= 20 ? 2 : 1
        let moveLimit = mode == .challenge ? board.route.count + allowance : nil
        let timeLimit = mode == .timed ? Double(max(30, board.route.count * 2 + 15)) : nil
        var coinCells: Set<GridCell> = []
        if mode == .endless && number.isMultiple(of: 5) {
            // Use a separate generator so adding collectibles cannot change the maze.
            var coinRandom = SeededGenerator(seed: UInt64(number) ^ 0x434F494E424F4E55)
            var available = board.cells.subtracting([board.start]).sorted()
            for _ in 0..<min(maximumCoinCount, available.count) {
                coinCells.insert(available.remove(at: coinRandom.integer(lessThan: available.count)))
            }
        }
        return MazeLevel(
            number: number, mode: mode, width: width, height: height,
            openCells: board.cells, start: board.start, solution: board.route,
            moveLimit: moveLimit, timeLimit: timeLimit, coinCells: coinCells
        )
    }
}
