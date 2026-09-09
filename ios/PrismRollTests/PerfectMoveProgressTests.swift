#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class PerfectMoveProgressTests: XCTestCase {
    func testBundledFirstAndThousandthLevelCountsClassifyCompletedRunsImmediately() async throws {
        for number in [1, 1_000] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let minimum = try XCTUnwrap(MazePerfectMoveCatalog.minimumMoves(for: level))
            XCTAssertEqual(minimum, number == 1 ? 8 : 88)
            for (moves, wasPending) in [(minimum, false), (minimum, true), (minimum + 1, false), (minimum + 1, true)] {
                let suite = "PerfectMoveProgressTests.Bundled.\(UUID().uuidString)"
                let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
                defer { defaults.removePersistentDomain(forName: suite) }
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(MazeRun(level: level))) as? [String: Any])
                object["painted"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(level.openCells))
                object["moves"] = moves
                object["hintRoute"] = []
                let run = try JSONDecoder().decode(MazeRun.self, from: JSONSerialization.data(withJSONObject: object))
                var progress = ProgressData()
                progress.completeLevel(level)
                progress.hapticsEnabled = false
                progress.soundEnabled = false
                let snapshot = GameSnapshot(progress: progress, runs: ["endless": run], clocks: [:],
                                            mode: .endless, dailyRun: nil, dailyID: nil, dailyActive: false, themeID: "aurora",
                                            pendingCompletions: wasPending ? [PendingCompletion(id: UUID(), run: run, stageIndex: nil)] : nil)
                defaults.set(try JSONEncoder().encode(snapshot), forKey: "prism.snapshot.v2")
                let store = GameStore(defaults: defaults, completionVerifier: { _ in
                    XCTFail("A bundled minimum must classify this run without invoking the native verifier")
                    return .undetermined
                }, optimalHintSolver: { _, _, _ in
                    XCTFail("A completed board must not request a hint route")
                    return nil
                })
                let expected: MazeOptimality.Result = moves == minimum ? .optimal : .notOptimal

                // Read before the first suspension: initial presentation must
                // already know whether this completion matches the exact count.
                XCTAssertEqual(store.completedRunOptimalityIfReady(for: store.runID), expected,
                               "Level \(number), \(moves) moves, pending on disk: \(wasPending)")
                let completed = await store.completedRunOptimality(for: store.runID)
                XCTAssertEqual(completed, expected)
            }
        }
    }

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
