protocol BenchmarkQueue {
    init()
    var isEmpty: Bool { get }
    mutating func append(_ move: MazeSceneMove)
    mutating func removeFirst() -> MazeSceneMove
}
