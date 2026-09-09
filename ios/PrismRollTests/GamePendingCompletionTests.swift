#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class GamePendingCompletionTests: XCTestCase {
    func testNoncanonicalClassicPendingProofIsDiscardedBeforeVerification() throws {
        let suite = "PrismRoll.GamePendingCompletionTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let level = MazeLevel.generate(number: 8, mode: .endless)
        let minimum = try XCTUnwrap(MazePerfectMoveCatalog.minimumMoves(for: level))
        let changedStart = try XCTUnwrap(level.openCells.sorted().first { $0 != level.start })
        let otherBoard = MazeLevel(number: level.number, mode: level.mode, width: level.width, height: level.height,
                                   openCells: level.openCells, start: changedStart, solution: [], moveLimit: nil)
        let pending = PendingCompletion(id: UUID(), run: try completedSnapshot(otherBoard, moves: 1), stageIndex: nil)
        var progress = ProgressData()
        progress.completeLevel(level)
        progress.recordCompletedRun(try completedSnapshot(level, moves: minimum), optimality: .optimal)
        progress.hapticsEnabled = false
        progress.soundEnabled = false
        let snapshot = GameSnapshot(progress: progress, runs: ["endless": MazeRun(level: level)], clocks: [:],
                                    mode: .endless, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora",
                                    pendingCompletions: [pending])
        defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")

        let store = GameStore(defaults: defaults, uptime: { 0 }, completionVerifier: { _ in
            XCTFail("A different Classic board must not start a completion proof")
            return .undetermined
        }, optimalHintSolver: { _, _, _ in nil })

        XCTAssertEqual(store.progress, progress)
        XCTAssertEqual(store.progress.optimalMoves(for: level), minimum)
        XCTAssertNil(store.progress.optimalMoves(for: otherBoard))
        XCTAssertEqual(store.run, MazeRun(level: level))
        let saved = try JSONDecoder().decode(GameSnapshot.self, from: XCTUnwrap(defaults.data(forKey: "prism.snapshot.v2")))
        XCTAssertNil(saved.pendingCompletions)
    }

    private func completedSnapshot(_ level: MazeLevel, moves: Int) throws -> MazeRun {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(MazeRun(level: level))) as? [String: Any])
        object["painted"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(level.openCells))
        object["moves"] = moves
        return try JSONDecoder().decode(MazeRun.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
#endif
