/// Five distinct mazes share one clock. Geometry is independent of the other modes.
struct TimeRushCourse: Codable, Equatable, Sendable {
    let number: Int
    let levels: [MazeLevel]
    let timeLimit: Double

    var mazeCount: Int { levels.count }

    static func generate(number: Int) -> TimeRushCourse {
        let number = max(1, number)
        let difficulty = min(8, (number - 1) / 3)
        let timeLimit = Double(60 + min(difficulty, 6) * 5)
        var random = SeededGenerator(seed: UInt64(number) &* 0x9E3779B97F4A7C15 ^ 0x52555348434F5552)
        var levels: [MazeLevel] = []

        for stage in 0..<5 {
            let size = min(9, 5 + stage / 2 + difficulty / 2)
            let minimumMoves = min(size * 4 - 8, 8 + stage * 2 + difficulty * 2)
            let board = makeBoard(
                size: size, minimumMoves: minimumMoves, random: &random,
                excluding: levels.map(\.openCells)
            )
            levels.append(MazeLevel(
                number: number, mode: .timed, width: size, height: size,
                openCells: board.cells, start: board.start, solution: board.route,
                moveLimit: nil, timeLimit: timeLimit
            ))
        }
        return TimeRushCourse(number: number, levels: levels, timeLimit: timeLimit)
    }

    private static func makeBoard(
        size: Int, minimumMoves: Int, random: inout SeededGenerator,
        excluding previousCells: [Set<GridCell>]
    ) -> (cells: Set<GridCell>, start: GridCell, route: [MoveDirection]) {
        // The covering route is executable, not an assertion of optimal difficulty.
        // Limit its range to avoid occasional huge boards exhausting the shared clock.
        for _ in 0..<24 {
            var candidate: Set<GridCell> = []
            for row in 0..<size {
                for column in 0..<size where random.integer(lessThan: 100) >= 26 {
                    candidate.insert(GridCell(row: row, column: column))
                }
            }
            guard let region = MazeSolver.playableRegion(in: candidate),
                  region.cells.count >= size * size / 2,
                  region.cells.count < size * size,
                  !previousCells.contains(region.cells),
                  MazeSolver.isFullyPlayable(openCells: region.cells, start: region.start),
                  let route = MazeSolver.coveringRoute(
                    openCells: region.cells, position: region.start, painted: [region.start]
                  ), route.count >= minimumMoves, route.count <= minimumMoves + 5 else { continue }
            return (region.cells, region.start, route)
        }

        return fallbackBoard(
            size: size, firstOrientation: random.integer(lessThan: 8), excluding: previousCells
        )
    }

    static func fallbackBoard(
        size: Int, firstOrientation: Int, excluding previousCells: [Set<GridCell>]
    ) -> (cells: Set<GridCell>, start: GridCell, route: [MoveDirection]) {
        // Validated asymmetric boards provide eight distinct orientations each.
        // At most four prior mazes can exclude one, so fallback work stays bounded.
        let rows = fallbackRows(size: size)
        var cells: Set<GridCell> = []
        for (row, line) in rows.enumerated() {
            for (column, character) in line.enumerated() where character == "." {
                cells.insert(GridCell(row: row, column: column))
            }
        }
        let start = cells.min()!
        let route = MazeSolver.coveringRoute(openCells: cells, position: start, painted: [start])!
        for offset in 0..<8 {
            let orientation = (firstOrientation + offset) % 8
            let transformed = Set(cells.map { transform($0, size: size, orientation: orientation) })
            guard !previousCells.contains(transformed) else { continue }
            let transformedRoute = route.map { direction in
                let origin = transform(GridCell(row: 1, column: 1), size: size, orientation: orientation)
                let next = transform(
                    GridCell(row: 1 + direction.rowDelta, column: 1 + direction.columnDelta),
                    size: size, orientation: orientation
                )
                return MoveDirection.allCases.first {
                    $0.rowDelta == next.row - origin.row && $0.columnDelta == next.column - origin.column
                }!
            }
            return (transformed, transform(start, size: size, orientation: orientation), transformedRoute)
        }
        preconditionFailure("Five mazes cannot exhaust eight distinct fallback orientations")
    }

    private static func transform(_ cell: GridCell, size: Int, orientation: Int) -> GridCell {
        var row = cell.row
        var column = orientation >= 4 ? size - 1 - cell.column : cell.column
        for _ in 0..<(orientation % 4) {
            (row, column) = (column, size - 1 - row)
        }
        return GridCell(row: row, column: column)
    }

    private static func fallbackRows(size: Int) -> [String] {
        switch size {
        case 5:
            [".....", "..##.", ".....", "#....", "....#"]
        case 6:
            [".....#", "....##", "#.....", "#.###.", "#.###.", "#.#..."]
        case 7:
            [".....#.", "...#...", "#......", "##.##..", "##.##.#", "##.....", "...##.."]
        case 8:
            ["....####", ".....#.#", "...#.#..", ".....#..", "#.....#.", "#..#..#.", "#..#....", "##..#..."]
        default:
            ["##.......", "##.##.##.", "##.##.##.", ".#.##.##.", "...##....", "#..##.###", "#.#...##.", "####.....", "###..#..."]
        }
    }
}
