import Foundation
import simd

/// A continuous clock consumes ordered slides, including every intermediate turn.
/// Catch-up changes speed, never replaces a route with a diagonal shortcut.
struct MazeMotionTimeline {
    private var moves: [MazeSceneMove] = []
    private var elapsed = 0.0
    private var remainingDuration = 0.0
    private var playbackRate = 1.0
    private var crossedCells = 0
    private(set) var position = SIMD2<Float>(repeating: 0)
    private(set) var painted: Set<GridCell> = []
    var pendingMoveCount: Int { moves.count }
    var isMoving: Bool { !moves.isEmpty }

    mutating func reset(position cell: GridCell, painted: Set<GridCell>) {
        moves.removeAll(keepingCapacity: true)
        elapsed = 0
        remainingDuration = 0
        playbackRate = 1
        crossedCells = 0
        position = SIMD2(Float(cell.column), Float(cell.row))
        self.painted = painted
    }

    mutating func enqueue(_ move: MazeSceneMove) {
        guard !move.path.isEmpty else { return }
        moves.append(move)
        remainingDuration += move.duration
        // The current route must drain within 100 ms of this input. Keep the
        // catch-up rate until idle: slowing down as debt shrinks creates a long
        // trailing animation after the player has already finished swiping.
        playbackRate = max(playbackRate, remainingDuration / 0.10)
    }

    mutating func advance(by interval: TimeInterval) -> MazeMotionUpdate {
        var update = MazeMotionUpdate()
        guard interval > 0, interval.isFinite else { return update }
        // Walk all original segments even when one display frame crosses more
        // than one turn. A long suspended frame cannot advance a paused scene.
        var remaining = min(interval, 1.0 / 15) * playbackRate
        while remaining > 0, let move = moves.first {
            let step = min(remaining, move.duration - elapsed)
            elapsed += step
            remaining -= step
            remainingDuration = max(0, remainingDuration - step)
            // Floating-point remainder must not cost another whole display
            // frame after the ball has effectively reached its destination.
            if move.duration - elapsed < 0.000000001 { elapsed = move.duration }
            let fraction = min(1, elapsed / move.duration)
            let origin = SIMD2(Float(move.origin.column), Float(move.origin.row))
            let target = SIMD2(Float(move.position.column), Float(move.position.row))
            let next = origin + (target - origin) * Float(fraction)
            update.rotations.append(next - position)
            position = next
            let reached = min(move.path.count, Int(fraction * Double(move.path.count) + 0.5))
            if reached > crossedCells {
                for cell in move.path[crossedCells..<reached] where painted.insert(cell).inserted {
                    update.paintedCells.append(cell)
                }
                crossedCells = reached
            }
            if fraction >= 1 {
                painted.formUnion(move.painted)
                if move.isComplete { update.completedAt = move.position }
                moves.removeFirst()
                elapsed = 0
                crossedCells = 0
            }
        }
        if moves.isEmpty {
            remainingDuration = 0
            playbackRate = 1
        }
        return update
    }
}
