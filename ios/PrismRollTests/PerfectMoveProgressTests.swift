#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class PerfectMoveProgressTests: XCTestCase {
    func testMeetingDisplayedLevelSixteenMinimumEarnsCrownAfterRestore() async throws {
        let level = MazeLevel.generate(number: 16, mode: .endless)
        let minimum = await MazeMinimumMoveCache.shared.minimumMoves(for: level)
        XCTAssertEqual(minimum, 38)
        let perfectMoves = try XCTUnwrap(minimum)
        for moves in [perfectMoves, perfectMoves + 2] {
            let suite = "PerfectMoveProgressTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            // Restore the same completed-run snapshot the app persists. The
            // separately proven level minimum controls whether it earns a crown.
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(MazeRun(level: level))) as? [String: Any])
            object["painted"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(level.openCells))
            object["moves"] = moves
            object["hintRoute"] = []
            let run = try JSONDecoder().decode(MazeRun.self, from: JSONSerialization.data(withJSONObject: object))
            var progress = ProgressData()
            progress.completeLevel(level)
            let snapshot = GameSnapshot(progress: progress, runs: ["endless": run], clocks: [:],
                                        mode: .endless, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora")
            defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
            let store = GameStore(defaults: defaults)
            let result = await store.completedRunOptimality(for: store.runID)
            XCTAssertEqual(result, moves == perfectMoves ? .optimal : .notOptimal)
            XCTAssertEqual(store.progress.hasOptimalCompletion(number: 16, mode: .endless), moves == perfectMoves)
        }
    }
}
#endif
