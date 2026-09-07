/// Validated irregular layouts retain decisions and unavoidable corridor returns
/// even when the bounded random search does not find a qualifying candidate.
struct MazeFallbackLayouts {
    private static let layouts: [Int: MazeLayout] = {
        Dictionary(uniqueKeysWithValues: (5...10).map { size in
            var cells: Set<GridCell> = []
            for (row, line) in rows(size: size).enumerated() {
                for (column, value) in line.enumerated() where value == "." {
                    cells.insert(GridCell(row: row, column: column))
                }
            }
            let start = cells.min()!
            let route = MazeRoutePlanner.route(openCells: cells, start: start, exactStateLimit: size <= 6 ? 10_000 : 0)!
            return (size, MazeLayout(cells: cells, start: start, route: route,
                                    topology: MazeTopology(openCells: cells, start: start)))
        })
    }()

    static func make(size: Int, orientation: Int) -> MazeLayout {
        let base = layouts[size]!
        let transform: (GridCell) -> GridCell = { cell in
            var row = cell.row
            var column = orientation >= 4 ? size - 1 - cell.column : cell.column
            for _ in 0..<(orientation % 4) { (row, column) = (column, size - 1 - row) }
            return GridCell(row: row, column: column)
        }
        let origin = transform(GridCell(row: 1, column: 1))
        let route = base.route.map { direction in
            let next = transform(GridCell(row: 1, column: 1).neighbor(in: direction))
            return MoveDirection.allCases.first {
                origin.neighbor(in: $0) == next
            }!
        }
        return MazeLayout(cells: Set(base.cells.map(transform)), start: transform(base.start),
                          route: route, topology: base.topology)
    }

    private static func rows(size: Int) -> [String] {
        switch size {
        case 5:
            ["....#", ".##.#", ".....", ".###.", ".#..."]
        case 6:
            [".#...#", ".#....", "......", "#.##..", "#.....", "....#."]
        case 7:
            ["....##.", ".......", ".##...#", "......#", ".#.#...", "...#.#.", "#####.."]
        case 8:
            [".#...###", ".#..#...", "....#.##", "#...#.##", "#......#", "....#...", "###.....", ".....#.."]
        case 9:
            ["#........", "......#..", "...#....#", ".....#...", "##.....##", "...#.....", ".##......", ".##....#.", "...#..##."]
        default:
            ["##......#.", ".#........", ".####.##..", ".........#", "##.##.....", "...##..#..", ".#.##.....", ".....#....", ".###.#.###", "...#......"]
        }
    }
}
