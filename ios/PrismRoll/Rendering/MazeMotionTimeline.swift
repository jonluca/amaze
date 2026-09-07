import Foundation
import simd

/// A continuous clock consumes ordered slides, including every intermediate turn.
/// Catch-up changes speed, never replaces a route with a diagonal shortcut.
struct MazeMotionTimeline {
    private static let maximumQueuedStartDelay = 1.0 / 120
    private var moves: [MazeSceneMove] = []
    private var elapsed = 0.0
    private var remainingDuration = 0.0
    private var playbackRate = 1.0
    private var finalMovePlaybackRate = 1.0
    private var continuationStart: (elapsed: Double, fraction: Double)?
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
        finalMovePlaybackRate = 1
        continuationStart = nil
        crossedCells = 0
        position = SIMD2(Float(cell.column), Float(cell.row))
        self.painted = painted
    }

    mutating func enqueue(_ move: MazeSceneMove) {
        guard !move.path.isEmpty else { return }
        if let current = moves.first {
            // Clear older input within one ProMotion interval so the newest
            // turn is visibly moving within two frames at 120 Hz during bursts.
            playbackRate = max(playbackRate, remainingDuration / Self.maximumQueuedStartDelay)
            finalMovePlaybackRate = max(1, move.duration / (0.10 - Self.maximumQueuedStartDelay))
            if continuationStart == nil {
                // Rebase from the visible eased position. Switching straight
                // to linear progress would rewind a slide already in flight.
                let time = elapsed / current.duration
                continuationStart = (elapsed, time + time * time * (1 - time))
            }
        }
        moves.append(move)
        remainingDuration += move.duration
    }

    mutating func advance(by interval: TimeInterval) -> MazeMotionUpdate {
        var update = MazeMotionUpdate()
        guard interval > 0, interval.isFinite else { return update }
        // Walk all original segments even when one display frame crosses more
        // than one turn. A long suspended frame cannot advance a paused scene.
        var remaining = min(interval, 1.0 / 15)
        while remaining > 0, let move = moves.first {
            // Accelerate the older turns, then give the newest swipe its own
            // visible roll. A burst must not compress that fresh roll to a snap.
            let rate = moves.count > 1 ? playbackRate : finalMovePlaybackRate
            let step = min(remaining * rate, move.duration - elapsed)
            elapsed += step
            remaining = max(0, remaining - step / rate)
            remainingDuration = max(0, remainingDuration - step)
            // Floating-point remainder must not cost another whole display
            // frame after the ball has effectively reached its destination.
            if move.duration - elapsed < 0.000000001 { elapsed = move.duration }
            let timeFraction = min(1, elapsed / move.duration)
            let fraction: Double
            if let continuationStart {
                // A queued turn continues through the wall contact without
                // braking to zero. Only the final move eases into its stop.
                let progress = (elapsed - continuationStart.elapsed) / (move.duration - continuationStart.elapsed)
                fraction = continuationStart.fraction + (1 - continuationStart.fraction) * progress
            } else {
                fraction = timeFraction + timeFraction * timeFraction * (1 - timeFraction)
            }
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
            if timeFraction >= 1 {
                painted.formUnion(move.painted)
                if move.isComplete { update.completedAt = move.position }
                moves.removeFirst()
                elapsed = 0
                crossedCells = 0
                continuationStart = moves.count > 1 ? (0, 0) : nil
            }
        }
        if moves.isEmpty {
            remainingDuration = 0
            playbackRate = 1
            finalMovePlaybackRate = 1
        }
        return update
    }
}
