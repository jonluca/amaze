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
        let size = min(9, 4 + (number - 1) / 5)
        let salt: UInt64
        switch mode {
        case .endless: salt = 0x505249534D524F4C
        case .challenge: salt = 0x4348414C4C454E47
        case .timed: salt = 0x54494D4552555348
        }
        var random = SeededGenerator(seed: UInt64(number) &* 0x9E3779B97F4A7C15 ^ salt)
        let width = size
        let height = max(4, size - random.integer(lessThan: 2))
        var selected: (cells: Set<GridCell>, start: GridCell, route: [MoveDirection])?

        // Bound generation work. A validated perimeter board is the safe fallback.
        for _ in 0..<12 {
            var candidate: Set<GridCell> = []
            for row in 0..<height {
                for column in 0..<width where random.integer(lessThan: 100) >= 24 {
                    candidate.insert(GridCell(row: row, column: column))
                }
            }
            guard let region = MazeSolver.playableRegion(in: candidate),
                  region.cells.count >= max(8, width * height / 3),
                  region.cells.count < width * height,
                  MazeSolver.isFullyPlayable(openCells: region.cells, start: region.start),
                  let route = MazeSolver.coveringRoute(
                    openCells: region.cells, position: region.start, painted: [region.start]
                  ), route.count >= 3 else { continue }
            if selected == nil || region.cells.count > selected!.cells.count {
                selected = (region.cells, region.start, route)
            }
            if region.cells.count >= width * height * 3 / 5 && route.count >= size + 2 { break }
        }

        if selected == nil {
            var ring: Set<GridCell> = []
            for row in 0..<height {
                for column in 0..<width where row == 0 || row == height - 1 || column == 0 || column == width - 1 {
                    ring.insert(GridCell(row: row, column: column))
                }
            }
            selected = (ring, GridCell(row: 0, column: 0), [.down, .right, .up, .left])
        }
        let board = selected!
        let moveLimit = mode == .challenge ? board.route.count + max(2, board.route.count / 5) : nil
        let timeLimit = mode == .timed ? Double(max(30, board.route.count * 2 + 15)) : nil
        var coinCells: Set<GridCell> = []
        if mode == .endless && number.isMultiple(of: 5) {
            // Use a separate generator so adding collectibles cannot change the maze.
            var coinRandom = SeededGenerator(seed: UInt64(number) ^ 0x434F494E424F4E55)
            var available = board.cells.subtracting([board.start]).sorted()
            for _ in 0..<min(3, available.count) {
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
