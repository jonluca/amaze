import Foundation

/// Compile with the production Core sources, GameSnapshot, and TimedRunState.
/// This measures the same synchronous engine/JSON/UserDefaults operations as GameStore,
/// excluding SwiftUI publishing, SceneKit, audio, haptics, and operating-system disk flushes.
@main
struct MovePersistenceBenchmark {
    static func main() throws {
        let suite = "PrismRoll.MoveBenchmark.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let encoder = JSONEncoder()
        let cachedEncoder = GameSnapshotEncoder()
        let useCache = CommandLine.arguments.contains("--cached")
        print(useCache ? "Cached progress encoding" : "Full snapshot encoding")
        let date = Date(timeIntervalSince1970: 1_788_696_000)
        let daily = DailyChallenge.generate(for: date)
        var progress = ProgressData()
        var completed = 0

        for historySize in [0, 100, 1_000, 5_000, 20_000] {
            while completed < historySize {
                completed += 1
                let level = MazeLevel.generate(number: completed, mode: .endless)
                progress.completeLevel(level)
                if completed.isMultiple(of: 3) { progress.claimAdBonus(level: level) }
                if !level.coinCells.isEmpty {
                    var run = MazeRun(level: level)
                    for direction in level.solution { run.move(direction) }
                    precondition(run.isComplete)
                    progress.awardCollectedCoins(for: run)
                }
            }
            let level = MazeLevel.generate(number: historySize + 1, mode: .endless)
            var run = MazeRun(level: level)
            let forward = run.hintDirection!
            let backward: MoveDirection
            switch forward {
            case .up: backward = .down
            case .down: backward = .up
            case .left: backward = .right
            case .right: backward = .left
            }
            var snapshot = GameSnapshot(
                progress: progress,
                runs: ["endless": run,
                       "challenge": MazeRun(level: .generate(number: 1_000, mode: .challenge)),
                       "timed": MazeRun(level: .generate(number: 1_000, mode: .timed))],
                clocks: ["timed": TimedRunState(remainingSeconds: 47)], mode: .endless,
                dailyRun: MazeRun(level: daily.level), dailyID: daily.id,
                dailyActive: false, themeID: "aurora"
            )
            var samples: [String: [Double]] = [:]
            var bytes = 0
            for index in 0..<310 {
                let start = ProcessInfo.processInfo.systemUptime
                _ = DailyCalendar.dayID(for: date, calendar: .current)
                let path = run.move(index.isMultiple(of: 2) ? forward : backward)
                precondition(!path.isEmpty && !run.isComplete)
                snapshot.progress.awardCollectedCoins(for: run)
                snapshot.runs["endless"] = run
                let moved = ProcessInfo.processInfo.systemUptime
                let data = try useCache ? cachedEncoder.encode(snapshot) : encoder.encode(snapshot)
                let encoded = ProcessInfo.processInfo.systemUptime
                defaults.set(data, forKey: "prism.snapshot.v2")
                let saved = ProcessInfo.processInfo.systemUptime
                bytes = data.count
                if index >= 10 {
                    samples["move", default: []].append((moved - start) * 1_000)
                    samples["encode", default: []].append((encoded - moved) * 1_000)
                    samples["defaults", default: []].append((saved - encoded) * 1_000)
                    samples["total", default: []].append((saved - start) * 1_000)
                }
            }
            let restored = try JSONDecoder().decode(GameSnapshot.self, from: defaults.data(forKey: "prism.snapshot.v2")!)
            precondition(restored.runs["endless"] == run && restored.progress == snapshot.progress)
            print("History \(historySize), board \(level.number), \(level.openCells.count) cells, \(bytes) JSON bytes; 300 measured moves after 10 warmups")
            for name in ["move", "encode", "defaults", "total"] {
                let values = samples[name]!.sorted()
                print(String(format: "  %@ median=%.3f p95=%.3f max=%.3f ms", name, values[150], values[284], values[299]))
            }
        }
    }
}
