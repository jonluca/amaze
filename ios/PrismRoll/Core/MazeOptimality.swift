/// Native integer optimization proves the minimum before a target or crown is
/// awarded. Call this CPU work from a background task with an immutable snapshot.
enum MazeOptimality {
    enum Result: Equatable, Sendable {
        case optimal
        case notOptimal
        case undetermined
        case incomplete
    }

    /// No time, search-state, or difficulty cutoff. Nil means cancellation,
    /// invalid input, infeasibility, or a native failure; never an approximation.
    static func minimumMoves(
        for level: MazeLevel,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) -> Int? {
        guard case let .optimal(moves, _) = MazeNativeOptimizer.solve(level: level, isCancelled: isCancelled)
        else { return nil }
        return moves
    }

    static func verify(
        _ run: MazeRun,
        isCancelled: @escaping @Sendable () -> Bool = { false }
    ) -> Result {
        guard run.isComplete else { return .incomplete }
        guard run.moves >= 0,
              let minimum = minimumMoves(for: run.level, isCancelled: isCancelled) else { return .undetermined }
        return run.moves == minimum ? .optimal : .notOptimal
    }
}
