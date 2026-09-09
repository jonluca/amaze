/// Reuses bounded searches across views and completion checks without blocking
/// the main actor. Both proven counts and completed, unproven searches are kept.
actor MazeMinimumMoveCache {
    static let shared = MazeMinimumMoveCache()

    private struct Entry {
        let level: MazeLevel
        let minimumMoves: Int?
    }

    private var entries: [Entry] = []
    private let capacity = 32

    func minimumMoves(for level: MazeLevel) -> Int? {
        guard !Task.isCancelled else { return nil }
        if let index = entries.firstIndex(where: { $0.level.hasSameGrid(as: level) }) {
            let entry = entries.remove(at: index)
            entries.append(entry)
            return entry.minimumMoves
        }

        let minimum = MazeOptimality.minimumMoves(for: level, isCancelled: { Task.isCancelled })
        // A cancelled request must not suppress a later attempt for this board.
        guard !Task.isCancelled else { return nil }
        if entries.count == capacity { entries.removeFirst() }
        entries.append(Entry(level: level, minimumMoves: minimum))
        return minimum
    }

    /// Reuses a proof for awards without starting another potentially costly search.
    func cachedMinimumMoves(for level: MazeLevel) -> Int? {
        entries.first(where: { $0.level.hasSameGrid(as: level) })?.minimumMoves
    }
}
