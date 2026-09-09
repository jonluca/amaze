/// Offline native proofs for the first 1,000 Classic boards. Counts are bundled
/// with exact geometry, so level-generation changes fall back to a fresh proof.
enum MazePerfectMoveCatalog {
    struct Entry: Sendable {
        let width: Int
        let height: Int
        let startIndex: Int
        let mask0: UInt64
        let mask1: UInt64
        let mask2: UInt64
        let mask3: UInt64
        let minimumMoves: Int
    }

    /// Cheap in-memory lookup; no level generation, file access, or native work.
    static func minimumMoves(for level: MazeLevel) -> Int? {
        guard level.mode == .endless, level.number > 0, level.number <= entries.count else { return nil }
        let entry = entries[level.number - 1]
        guard level.width == entry.width, level.height == entry.height,
              (0..<level.height).contains(level.start.row),
              (0..<level.width).contains(level.start.column),
              level.start.row * 16 + level.start.column == entry.startIndex else { return nil }

        var masks: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        for cell in level.openCells {
            guard (0..<level.height).contains(cell.row),
                  (0..<level.width).contains(cell.column) else { return nil }
            let index = cell.row * 16 + cell.column
            let bit = UInt64(1) << (index % 64)
            switch index / 64 {
            case 0: masks.0 |= bit
            case 1: masks.1 |= bit
            case 2: masks.2 |= bit
            case 3: masks.3 |= bit
            default: return nil
            }
        }
        guard masks == (entry.mask0, entry.mask1, entry.mask2, entry.mask3) else { return nil }
        return entry.minimumMoves
    }
}
