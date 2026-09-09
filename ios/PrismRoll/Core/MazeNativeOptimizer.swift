import CPrismOptimizer

/// Exact native optimization. Call from the cache actor or another background
/// task: difficult boards keep solving until proved, cancelled, or failed.
enum MazeNativeOptimizer {
    enum Result: Equatable, Sendable {
        case optimal(moves: Int, route: [MoveDirection])
        case infeasible
        case cancelled
        case failure
    }

    private final class CallbackContext {
        let isCancelled: @Sendable () -> Bool
        init(isCancelled: @escaping @Sendable () -> Bool) { self.isCancelled = isCancelled }
    }

    static func solve(
        level: MazeLevel,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) -> Result {
        solve(level: level, position: level.start, painted: [level.start], isCancelled: isCancelled)
    }

    /// Returns the exact number of additional swipes from this paint state.
    static func solve(
        level: MazeLevel,
        position: GridCell,
        painted: Set<GridCell>,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) -> Result {
        guard !isCancelled() else { return .cancelled }
        guard (1...16).contains(level.width), (1...16).contains(level.height),
              !level.openCells.isEmpty, level.openCells.contains(position),
              painted.contains(position), painted.isSubset(of: level.openCells),
              level.openCells.allSatisfy({
                  (0..<level.height).contains($0.row) && (0..<level.width).contains($0.column)
              }) else { return .failure }

        var cells = [UInt8](repeating: 0, count: level.width * level.height)
        for cell in level.openCells { cells[cell.row * level.width + cell.column] = 1 }
        var initialPaint = [UInt8](repeating: 0, count: cells.count)
        for cell in painted { initialPaint[cell.row * level.width + cell.column] = 1 }
        let hint = position == level.start ? level.solution.map(encode) : []
        guard hint.count <= Int(Int32.max) else { return .failure }
        var nativeRoute = [UInt8](repeating: 0, count: Int(PrismOptimizerMaximumRouteCount))
        let context = CallbackContext(isCancelled: isCancelled)
        // Native callbacks run synchronously on this solving thread. This keeps
        // Task cancellation attached to its original task throughout the call.
        let result = withExtendedLifetime(context) {
            cells.withUnsafeBufferPointer { cells in
                hint.withUnsafeBufferPointer { hint in
                    nativeRoute.withUnsafeMutableBufferPointer { route in
                        initialPaint.withUnsafeBufferPointer { paint in
                            PrismOptimizerSolveState(
                                Int32(level.width), Int32(level.height), cells.baseAddress,
                                Int32(position.row * level.width + position.column), paint.baseAddress,
                                hint.baseAddress, Int32(hint.count),
                                { pointer in
                                    guard let pointer else { return 1 }
                                    let context = Unmanaged<CallbackContext>.fromOpaque(pointer).takeUnretainedValue()
                                    return context.isCancelled() ? 1 : 0
                                }, Unmanaged.passUnretained(context).toOpaque(),
                                route.baseAddress, Int32(route.count)
                            )
                        }
                    }
                }
            }
        }
        guard !isCancelled() else { return .cancelled }
        switch result.status {
        case PrismOptimizerStatusCancelled: return .cancelled
        case PrismOptimizerStatusInfeasible: return .infeasible
        case PrismOptimizerStatusOptimal:
            guard result.minimum_moves >= 0, result.minimum_moves == result.route_count,
                  Int(result.route_count) <= nativeRoute.count else { return .failure }
        default: return .failure
        }

        // Independently replay the C++ result through the actual game rules.
        // No native incumbent or numerical rounding alone can supply a target.
        let route = nativeRoute.prefix(Int(result.route_count)).compactMap(decode)
        guard route.count == Int(result.route_count) else { return .failure }
        var cursor = position
        var covered = painted
        for (index, direction) in route.enumerated() {
            if index.isMultiple(of: 128), isCancelled() { return .cancelled }
            guard covered != level.openCells else { return .failure }
            let cells = MazeSolver.path(from: cursor, direction: direction, in: level.openCells)
            guard let destination = cells.last else { return .failure }
            covered.formUnion(cells)
            cursor = destination
        }
        guard covered == level.openCells else { return .failure }
        return .optimal(moves: route.count, route: route)
    }

    private static func encode(_ direction: MoveDirection) -> UInt8 {
        switch direction {
        case .up: 0
        case .down: 1
        case .left: 2
        case .right: 3
        }
    }

    private static func decode(_ direction: UInt8) -> MoveDirection? {
        switch direction {
        case 0: .up
        case 1: .down
        case 2: .left
        case 3: .right
        default: nil
        }
    }
}
