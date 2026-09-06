struct GridCell: Hashable, Codable, Comparable, Sendable {
    let row: Int
    let column: Int

    static func < (lhs: GridCell, rhs: GridCell) -> Bool {
        lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
    }

    func neighbor(in direction: MoveDirection) -> GridCell {
        GridCell(row: row + direction.rowDelta, column: column + direction.columnDelta)
    }
}
