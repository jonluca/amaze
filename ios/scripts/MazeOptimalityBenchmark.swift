import Foundation

/// Run with swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark.
/// Times only the exact native minimum calculation, including model construction.
/// References include independent integer flow proofs; levels 8, 72 and 150
/// use retained native proofs and replayed routes.
/// See OPTIMAL_SOLVER.md and Validation/PerfectCounts for provenance.
@main
struct MazeOptimalityBenchmark {
    static func main() async throws {
        if CommandLine.arguments.contains("--catalog-only") {
            try benchmarkBundledCatalog()
            return
        }
        let currentStateOnly = CommandLine.arguments.contains("--current-state-only")
        let reference: [(number: Int, minimum: Int)] = [
            (1, 8),
            (2, 19),
            (3, 17),
            (4, 20),
            (5, 20),
            (6, 19),
            (7, 28),
            (8, 26),
            (9, 26),
            (10, 31),
            (11, 34),
            (12, 32),
            (13, 34),
            (14, 36),
            (15, 43),
            (16, 38),
            (17, 39),
            (18, 39),
            (19, 40),
            (20, 46),
            (21, 40),
            (22, 51),
            (23, 44),
            (24, 47),
            (25, 42),
            (26, 42),
            (27, 42),
            (28, 50),
            (29, 46),
            (30, 58),
            (31, 51),
            (32, 53),
            (33, 52),
            (34, 51),
            (35, 48),
            (36, 55),
            (37, 57),
            (38, 56),
            (39, 54),
            (40, 52),
            (41, 53),
            (42, 62),
            (43, 56),
            (44, 56),
            (45, 61),
            (46, 58),
            (47, 61),
            (48, 58),
            (49, 60),
            (50, 58),
            (51, 57),
            (52, 61),
            (53, 59),
            (54, 58),
            (55, 54),
            (56, 62),
            (57, 63),
            (58, 64),
            (59, 65),
            (60, 62),
            (61, 65),
            (62, 67),
            (63, 68),
            (64, 66),
            (65, 65),
            (66, 63),
            (67, 65),
            (68, 60),
            (69, 75),
            (70, 68),
            (71, 66),
            (72, 62),
            (73, 62),
            (74, 62),
            (75, 74),
            (76, 80),
            (77, 79),
            (78, 79),
            (79, 77),
            (80, 80),
            (81, 76),
            (82, 77),
            (83, 77),
            (84, 81),
            (85, 75),
            (86, 82),
            (87, 80),
            (88, 78),
            (89, 81),
            (90, 76),
            (91, 71),
            (92, 80),
            (93, 80),
            (94, 79),
            (95, 73),
            (96, 80),
            (97, 80),
            (98, 77),
            (99, 74),
            (100, 90),
            (150, 84),
            (200, 91),
            (250, 88),
            (500, 91),
            (1000, 88),
            (1001, 85),
            (10000, 86),
            (100000, 89),
            (1000000, 89),
            (1000000000, 89),
            (Int.max, 92)
        ]
        let clock = ContinuousClock()
        var results: [[String: Any]] = []
        var proved = 0
        for item in currentStateOnly ? [] : reference {
            let level = MazeLevel.generate(number: item.number, mode: .endless)
            let start = clock.now
            guard let minimum = MazeOptimality.minimumMoves(for: level) else {
                fatalError("No exact result for level \(item.number)")
            }
            let duration = start.duration(to: clock.now).components
            let milliseconds = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
            precondition(minimum == item.minimum, "Incorrect minimum for level \(item.number): \(minimum) != \(item.minimum)")
            proved += 1
            let result: [String: Any] = [
                "level": item.number, "minimum": minimum,
                "reference": item.minimum, "milliseconds": milliseconds
            ]
            results.append(result)
            print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)
        }
        if !currentStateOnly {
            print("Proved \(proved)/\(reference.count); every reported minimum matches its verified reference count.")
        }
        results.append(contentsOf: try await benchmarkCurrentStates())
        if let output = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) {
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: output))
        }
    }

    private static func benchmarkBundledCatalog() throws {
        let clock = ContinuousClock()
        var results: [[String: Any]] = []
        var lookupTimes: [Double] = []
        for number in 1...1_000 {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let start = clock.now
            guard let minimum = MazePerfectMoveCatalog.minimumMoves(for: level) else {
                fatalError("Missing bundled count for canonical Classic level \(number)")
            }
            let elapsed = milliseconds(start.duration(to: clock.now))
            lookupTimes.append(elapsed)
            results.append([
                "measurement": "bundled-count", "level": number,
                "minimum": minimum, "milliseconds": elapsed
            ])
        }
        lookupTimes.sort()
        let summary: [String: Any] = [
            "measurement": "bundled-count-summary", "levels": lookupTimes.count,
            "medianMilliseconds": lookupTimes[lookupTimes.count / 2],
            "p95Milliseconds": lookupTimes[Int(Double(lookupTimes.count - 1) * 0.95)],
            "maximumMilliseconds": lookupTimes.last!
        ]
        results.append(summary)
        print(String(data: try JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]), encoding: .utf8)!)
        if let output = CommandLine.arguments.dropFirst().first(where: { !$0.hasPrefix("--") }) {
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: output))
        }
    }

    private static func benchmarkCurrentStates() async throws -> [[String: Any]] {
        let clock = ContinuousClock()
        var results: [[String: Any]] = []
        for (number, reference) in [(1, 8), (16, 38), (100, 90), (1_000, 88), (Int.max, 92)] {
            let level = MazeLevel.generate(number: number, mode: .endless)
            let cache = MazeMinimumMoveCache()
            let initialStart = clock.now
            guard case let .optimal(moves, route) = await cache.solution(
                for: level, position: level.start, painted: [level.start]
            ) else { fatalError("Missing initial proof for level \(number)") }
            let initialMilliseconds = milliseconds(initialStart.duration(to: clock.now))
            precondition(moves == reference)
            var position = level.start
            var painted: Set<GridCell> = [position]
            var lookupTimes: [Double] = []
            let halfway = route.count / 2
            var middlePosition = position
            var middlePainted = painted

            // Every position on an exact route has a proved suffix. Measure
            // each hit separately; this loop must never trigger native search.
            for index in 0...route.count {
                let start = clock.now
                let cached = await cache.cachedSolution(for: level, position: position, painted: painted)
                lookupTimes.append(milliseconds(start.duration(to: clock.now)))
                precondition(cached == .optimal(moves: moves - index, route: Array(route.dropFirst(index))))
                if index == halfway {
                    middlePosition = position
                    middlePainted = painted
                }
                guard index < route.count else { break }
                let path = MazeSolver.path(from: position, direction: route[index], in: level.openCells)
                precondition(!path.isEmpty)
                position = path.last!
                painted.formUnion(path)
            }
            precondition(painted == level.openCells)

            let stateStart = clock.now
            let current = MazeNativeOptimizer.solve(level: level, position: middlePosition, painted: middlePainted)
            let stateMilliseconds = milliseconds(stateStart.duration(to: clock.now))
            guard case let .optimal(remaining, currentRoute) = current else {
                fatalError("Missing current-state proof for level \(number)")
            }
            precondition(remaining == moves - halfway)
            verify(route: currentRoute, level: level, position: middlePosition, painted: middlePainted)

            lookupTimes.sort()
            let result: [String: Any] = [
                "measurement": "current-state", "level": number,
                "initialMoves": moves, "remainingMoves": remaining,
                "initialColdMilliseconds": initialMilliseconds,
                "currentStateColdMilliseconds": stateMilliseconds,
                "suffixCacheLookups": lookupTimes.count,
                "suffixCacheMedianMilliseconds": lookupTimes[lookupTimes.count / 2],
                "suffixCacheMaximumMilliseconds": lookupTimes.last!
            ]
            results.append(result)
            print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]), encoding: .utf8)!)

            // Also measure a real deviation from the optimum, where both the
            // position and paint set differ and a suffix is no longer enough.
            if let detour = MoveDirection.allCases.first(where: {
                $0 != route[halfway]
                    && !MazeSolver.path(from: middlePosition, direction: $0, in: level.openCells).isEmpty
            }) {
                let path = MazeSolver.path(from: middlePosition, direction: detour, in: level.openCells)
                let detourPosition = path.last!
                let detourPainted = middlePainted.union(path)
                let detourStart = clock.now
                let detourResult = MazeNativeOptimizer.solve(
                    level: level, position: detourPosition, painted: detourPainted
                )
                let detourMilliseconds = milliseconds(detourStart.duration(to: clock.now))
                guard case let .optimal(detourMoves, detourRoute) = detourResult else {
                    fatalError("Missing detour proof for level \(number)")
                }
                verify(route: detourRoute, level: level, position: detourPosition, painted: detourPainted)
                let detourMeasurement: [String: Any] = [
                    "measurement": "detour", "level": number,
                    "remainingMoves": detourMoves, "milliseconds": detourMilliseconds
                ]
                results.append(detourMeasurement)
                print(String(data: try JSONSerialization.data(withJSONObject: detourMeasurement, options: [.sortedKeys]), encoding: .utf8)!)
            }
        }
        return results
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }

    private static func verify(route: [MoveDirection], level: MazeLevel, position: GridCell, painted: Set<GridCell>) {
        var cursor = position
        var covered = painted
        for direction in route {
            precondition(covered != level.openCells, "Route continues past completion")
            let path = MazeSolver.path(from: cursor, direction: direction, in: level.openCells)
            precondition(!path.isEmpty, "Blocked direction in native route")
            cursor = path.last!
            covered.formUnion(path)
        }
        precondition(covered == level.openCells, "Native route did not finish current state")
    }
}
