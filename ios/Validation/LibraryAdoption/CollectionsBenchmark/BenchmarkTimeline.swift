import Foundation

protocol BenchmarkTimeline {
    init()
    var pendingMoveCount: Int { get }
    var isMoving: Bool { get }
    var position: SIMD2<Float> { get }
    var painted: Set<GridCell> { get }
    mutating func reset(position cell: GridCell, painted: Set<GridCell>)
    mutating func enqueue(_ move: MazeSceneMove)
    mutating func advance(by interval: TimeInterval) -> MazeMotionUpdate
}
