import Foundation

/// Owned by the same caller as GameStore. No deferred writes or schema migration.
final class GameSnapshotEncoder {
    private let encoder = JSONEncoder()
    private var cachedProgress: ProgressData?
    private var cachedProgressData: Data?
    private var emptyProgressData: Data?

    init() {
        // An independently encoded progress value must match its nested encoding.
        encoder.outputFormatting = [.sortedKeys]
    }

    func encode(_ snapshot: GameSnapshot) throws -> Data {
        let progressData: Data
        if cachedProgress == snapshot.progress, let cachedProgressData {
            progressData = cachedProgressData
        } else {
            progressData = try encoder.encode(snapshot.progress)
            cachedProgress = snapshot.progress
            cachedProgressData = progressData
        }

        let empty = ProgressData()
        let placeholder = try emptyProgressData ?? encoder.encode(empty)
        emptyProgressData = placeholder
        var state = snapshot
        state.progress = empty
        // Encode the original type so newly added snapshot fields are preserved.
        // Substitute only an unambiguous encoded value, never user-supplied JSON.
        var data = try encoder.encode(state)
        guard let range = data.range(of: placeholder),
              data.range(of: placeholder, in: range.upperBound..<data.endIndex) == nil else {
            return try encoder.encode(snapshot)
        }
        data.replaceSubrange(range, with: progressData)
        return data
    }
}
