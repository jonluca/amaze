import DequeModule

struct DequeMoveQueue: BenchmarkQueue {
    private var moves: Deque<MazeSceneMove> = []
    var isEmpty: Bool { moves.isEmpty }
    mutating func append(_ move: MazeSceneMove) { moves.append(move) }
    mutating func removeFirst() -> MazeSceneMove { moves.removeFirst() }
}
