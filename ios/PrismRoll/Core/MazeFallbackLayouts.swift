/// Full-size irregular layouts retain decisions and unavoidable corridor returns.
/// Each size has its own lazy immutable cache; small boards never prepare large ones.
struct MazeFallbackLayouts {
    private static let size5 = load(size: 5)
    private static let size6 = load(size: 6)
    private static let size7 = load(size: 7)
    private static let size8 = load(size: 8)
    private static let size9 = load(size: 9)
    private static let size10 = load(size: 10)
    private static let size11 = load(size: 11)
    private static let size12 = load(size: 12)
    private static let size13 = load(size: 13)
    private static let size14 = load(size: 14)
    private static let size15 = load(size: 15)
    private static let size16 = load(size: 16)

    static func variantCount(size: Int) -> Int { layouts(size: size).count }

    static func make(size: Int, orientation: Int, variant: Int = 0) -> MazeLayout {
        let choices = layouts(size: size)
        let remainder = variant % choices.count
        let base = choices[remainder < 0 ? remainder + choices.count : remainder]
        let orientation = (orientation % 8 + 8) % 8
        let transform: (GridCell) -> GridCell = { cell in
            var row = cell.row
            var column = orientation >= 4 ? size - 1 - cell.column : cell.column
            for _ in 0..<(orientation % 4) { (row, column) = (column, size - 1 - row) }
            return GridCell(row: row, column: column)
        }
        let origin = transform(GridCell(row: 1, column: 1))
        let route = base.route.map { direction in
            let next = transform(GridCell(row: 1, column: 1).neighbor(in: direction))
            return MoveDirection.allCases.first { origin.neighbor(in: $0) == next }!
        }
        return MazeLayout(cells: Set(base.cells.map(transform)), start: transform(base.start),
                          route: route, topology: base.topology)
    }

    private static func load(size: Int) -> [MazeLayout] {
        MazeFallbackCatalog.rows(size: size).map { rows in
            var cells: Set<GridCell> = []
            for (row, line) in rows.enumerated() {
                for (column, value) in line.enumerated() where value == "." {
                    cells.insert(GridCell(row: row, column: column))
                }
            }
            let start = cells.min()!
            let route = MazeRoutePlanner.route(openCells: cells, start: start,
                                               exactStateLimit: size <= 6 ? 10_000 : 0)!
            return MazeLayout(cells: cells, start: start, route: route,
                              topology: MazeTopology(openCells: cells, start: start))
        }
    }

    private static func layouts(size: Int) -> [MazeLayout] {
        switch size {
        case 5: size5
        case 6: size6
        case 7: size7
        case 8: size8
        case 9: size9
        case 10: size10
        case 11: size11
        case 12: size12
        case 13: size13
        case 14: size14
        case 15: size15
        case 16: size16
        default: preconditionFailure("Maze size must be between 5 and 16")
        }
    }
}
