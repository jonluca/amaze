struct MazeSceneMove {
    let origin: GridCell
    let path: [GridCell]
    let position: GridCell
    let painted: Set<GridCell>
    let isComplete: Bool

    var duration: Double { min(0.18, max(0.07, Double(path.count) * 0.035)) }
}
