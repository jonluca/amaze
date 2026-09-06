struct MazeSlide {
    let direction: MoveDirection
    let cells: [GridCell]

    var destination: GridCell { cells[cells.count - 1] }
}
