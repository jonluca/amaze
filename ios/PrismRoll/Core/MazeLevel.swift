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

    /// Numbered boards are a shared catalog: a mode and number always identify
    /// the same grid for every player. Keep the seed, ordering, difficulty curve,
    /// and fallback layouts compatible with the frozen catalog regression tests.
    static func generate(number: Int, mode: GameMode) -> MazeLevel {
        generate(number: number, mode: mode, difficultyNumber: number)
    }

    /// Route and reward metadata can evolve without invalidating painted tiles.
    func hasSameGrid(as other: MazeLevel) -> Bool {
        width == other.width && height == other.height
            && start == other.start && openCells == other.openCells
    }

    /// Separate the seeded identity from progression for multi-maze courses.
    static func generate(number: Int, mode: GameMode, difficultyNumber: Int) -> MazeLevel {
        let number = max(1, number)
        let difficultyNumber = max(1, difficultyNumber)
        let difficulty = MazeDifficulty(number: difficultyNumber, mode: mode)
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
        let baseline = size > 5 ? MazeFallbackLayouts.make(
            size: size, orientation: random.integer(lessThan: 8),
            variant: random.integer(lessThan: MazeFallbackLayouts.variantCount(size: size))
        ) : nil

        // Score structure after improving routes. Raw greedy length does not
        // establish difficulty; distinct segment coverage and branches do.
        for attempt in 0..<(size == 5 ? 48 : 32) {
            var candidate: Set<GridCell> = []
            var preferredStart: GridCell?
            if attempt >= 4, !attempt.isMultiple(of: 4), let baseline {
                // Full-size, well-connected starting shapes make constrained large
                // boards affordable. Every mutation still passes the complete gate.
                candidate = baseline.cells
                preferredStart = baseline.start
                var changed: Set<GridCell> = []
                for _ in 0..<(1 + random.integer(lessThan: 3)) {
                    let cell = GridCell(row: random.integer(lessThan: height), column: random.integer(lessThan: width))
                    guard cell != baseline.start, changed.insert(cell).inserted else { continue }
                    if !candidate.insert(cell).inserted { candidate.remove(cell) }
                }
            } else {
                let density = [66, 72, 78, 74][attempt % 4]
                for row in 0..<height {
                    for column in 0..<width where random.integer(lessThan: 100) < density {
                        candidate.insert(GridCell(row: row, column: column))
                    }
                }
            }
            guard let layout = MazeLayout.candidate(cells: candidate, difficulty: difficulty, preferredStart: preferredStart),
                  baseline == nil || layout.cells != baseline?.cells else { continue }
            qualifyingCandidates += 1
            if selected == nil || difficulty.score(layout) > difficulty.score(selected!) {
                selected = layout
            }
            if attempt >= 11 && qualifyingCandidates >= (size == 5 ? 3 : 2) { break }
        }
        let board = selected ?? baseline ?? MazeFallbackLayouts.make(size: size, orientation: random.integer(lessThan: 8))
        let allowance = difficultyNumber <= 5 ? 3 : difficultyNumber <= 20 ? 2 : 1
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
