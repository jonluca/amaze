struct ArrayMoveQueue: BenchmarkQueue {
    private var moves: [MazeSceneMove] = []
    var isEmpty: Bool { moves.isEmpty }
    mutating func append(_ move: MazeSceneMove) { moves.append(move) }
    mutating func removeFirst() -> MazeSceneMove { moves.removeFirst() }
}
