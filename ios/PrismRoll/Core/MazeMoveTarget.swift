/// A proven minimum and an achievable target must remain distinguishable.
enum MazeMoveTarget: Equatable, Sendable {
    case perfect(Int)
    case bestKnown(Int)

    static func knownSolution(for level: MazeLevel, completedBest: Int?) -> MazeMoveTarget? {
        var position = level.start
        var painted: Set<GridCell> = [position]
        var moves = 0
        for direction in level.solution where painted != level.openCells {
            let path = MazeSolver.path(from: position, direction: direction, in: level.openCells)
            guard let destination = path.last else { continue }
            position = destination
            painted.formUnion(path)
            moves += 1
        }
        let saved = completedBest.flatMap { $0 >= 0 ? $0 : nil }
        if painted == level.openCells { return .bestKnown(min(moves, saved ?? moves)) }
        return saved.map(Self.bestKnown)
    }
}
