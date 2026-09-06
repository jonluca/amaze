import CryptoKit
import Foundation

/// Compile with Core/*.swift using `swiftc -O`; this is separate from the iOS target.
@main
struct EngineAudit {
    struct SearchState: Hashable {
        let position: Int
        let painted: UInt64
    }

    static func main() throws {
        let fingerprintLevels = [1, 2, 5, 10, 26, 100, 1_000_000, Int.max]
        let canonical = fingerprintLevels.flatMap { number in
            GameMode.allCases.map { mode in
                let level = MazeLevel.generate(number: number, mode: mode)
                return "\(number):\(mode.rawValue):\(signature(level)):"
                    + level.solution.map(\.rawValue).joined(separator: ",")
                    + ":\(level.moveLimit ?? -1):\(level.timeLimit ?? -1):"
                    + level.coinCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
            }
        }.joined(separator: "\n")
        let fingerprint = SHA256.hash(data: Data(canonical.utf8)).map { String(format: "%02x", $0) }.joined()
        if CommandLine.arguments.contains("--fingerprint-only") {
            print(fingerprint)
            return
        }

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        var timings: [Double] = []
        var hintTimings: [Double] = []
        var sections: [[String: Any]] = []
        var saveSizes: [Int] = []
        var allSignatures: Set<String> = []
        var modeTimings: [String: [Double]] = [:]
        var timeBudgets: [Double] = []
        var coinBoards = 0
        var collectibleTiles = 0
        let ranges = [
            ("levels_1_through_1000", Array(1...1_000)),
            ("levels_1000000_through_1000999", Array(1_000_000...1_000_999)),
            ("highest_1000_integer_levels", Array((Int.max - 999)...Int.max))
        ]
        for (name, numbers) in ranges {
            var signatures: Set<String> = []
            var solutions: [Int] = []
            var floors: [Int] = []
            var rings = 0
            for number in numbers {
                for mode in GameMode.allCases {
                    let before = ProcessInfo.processInfo.systemUptime
                    let level = MazeLevel.generate(number: number, mode: mode)
                    let elapsed = (ProcessInfo.processInfo.systemUptime - before) * 1_000
                    timings.append(elapsed)
                    modeTimings[mode.rawValue, default: []].append(elapsed)
                    precondition(MazeSolver.isFullyPlayable(openCells: level.openCells, start: level.start))
                    signatures.insert(signature(level))
                    allSignatures.insert(signature(level))
                    solutions.append(level.solution.count)
                    floors.append(level.openCells.count)
                    if isPerimeter(level) { rings += 1 }
                    if mode == .timed {
                        precondition(level.moveLimit == nil && level.timeLimit! >= Double(level.solution.count * 2))
                        timeBudgets.append(level.timeLimit!)
                    } else { precondition(level.timeLimit == nil) }
                    let expectedCoins = mode == .endless && number.isMultiple(of: 5) ? 3 : 0
                    precondition(level.coinCells.count == expectedCoins)
                    precondition(level.coinCells.isSubset(of: level.openCells) && !level.coinCells.contains(level.start))
                    if expectedCoins > 0 { coinBoards += 1 }
                    collectibleTiles += expectedCoins
                    var run = MazeRun(level: level)
                    for direction in level.solution { precondition(!run.move(direction).isEmpty) }
                    precondition(run.isComplete && !run.isFailed)
                    precondition(run.collectedCoinCells == level.coinCells)
                    var coinProgress = ProgressData()
                    precondition(coinProgress.awardCollectedCoins(for: run) == expectedCoins * MazeLevel.coinValue)
                    precondition(coinProgress.awardCollectedCoins(for: run) == 0)
                    coinProgress = try decoder.decode(ProgressData.self, from: encoder.encode(coinProgress))

                    run.reset()
                    run.move(run.hintDirection!)
                    let saved = try encoder.encode(run)
                    saveSizes.append(saved.count)
                    var restored = try decoder.decode(MazeRun.self, from: saved)
                    precondition(restored == run)
                    while let hint = restored.hintDirection { restored.move(hint) }
                    precondition(restored.isComplete)
                    precondition(coinProgress.awardCollectedCoins(for: restored) == 0)

                    // A deviation exercises the recovery planner rather than the saved route.
                    if let deviation = MoveDirection.allCases.first(where: {
                        $0 != run.hintDirection && !MazeSolver.path(from: run.position, direction: $0, in: level.openCells).isEmpty
                    }) {
                        let beforeHint = ProcessInfo.processInfo.systemUptime
                        run.move(deviation)
                        hintTimings.append((ProcessInfo.processInfo.systemUptime - beforeHint) * 1_000)
                    }
                }
            }
            sections.append([
                "range": name, "boards": numbers.count * GameMode.allCases.count,
                "distinct_board_geometry_and_start": signatures.count,
                "perimeter_boards": rings,
                "solution_moves_min": solutions.min()!, "solution_moves_median": percentile(solutions, 0.5),
                "solution_moves_max": solutions.max()!,
                "paintable_tiles_min": floors.min()!, "paintable_tiles_median": percentile(floors, 0.5),
                "paintable_tiles_max": floors.max()!
            ])
        }

        let challengeDifficulty = (1...25).map { number -> [String: Any] in
            let level = MazeLevel.generate(number: number, mode: .challenge)
            let shortest = shortestSolution(level, stateLimit: 250_000)
            return [
                "level": number, "width": level.width, "height": level.height,
                "paintable_tiles": level.openCells.count, "known_solution": level.solution.count,
                "move_limit": level.moveLimit!, "exact_shortest_solution": shortest.moves ?? -1,
                "exact_search_states": shortest.states
            ]
        }

        var progress = ProgressData()
        let template = MazeLevel.generate(number: 1, mode: .endless)
        for number in 1...10_000 {
            let level = MazeLevel(number: number, mode: .endless, width: template.width,
                                  height: template.height, openCells: template.openCells,
                                  start: template.start, solution: template.solution, moveLimit: nil)
            progress.completeLevel(level)
            if number.isMultiple(of: 2) { progress.claimAdBonus(level: level) }
        }
        let progressSave = try encoder.encode(progress)
        let restoredProgress = try decoder.decode(ProgressData.self, from: progressSave)
        precondition(restoredProgress == progress)
        let dailyReport = try auditDailyChallenges(encoder: encoder, decoder: decoder)
        let report: [String: Any] = [
            "build": "swiftc -O", "os": ProcessInfo.processInfo.operatingSystemVersionString,
            "modes": GameMode.allCases.map(\.rawValue),
            "canonical_fingerprint": fingerprint, "total_boards_verified": timings.count,
            "distinct_board_geometry_and_start_overall": allSignatures.count,
            "generation_milliseconds": statistics(timings),
            "generation_milliseconds_by_mode": modeTimings.mapValues { statistics($0) },
            "deviation_and_hint_replan_milliseconds": statistics(hintTimings),
            "run_save_bytes_median": percentile(saveSizes, 0.5), "run_save_bytes_max": saveSizes.max()!,
            "ranges": sections, "challenge_difficulty": challengeDifficulty,
            "timed_budget_seconds": statistics(timeBudgets),
            "coin_boards_verified": coinBoards, "collectible_tiles_verified": collectibleTiles,
            "progress_bytes_after_10000_completions_5000_bonuses": progressSave.count,
            "daily_challenges": dailyReport,
            "milestones": try auditMilestones(encoder: encoder, decoder: decoder)
        ]
        let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: json, as: UTF8.self))
    }

    static func auditDailyChallenges(encoder: JSONEncoder, decoder: JSONDecoder) throws -> [String: Any] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let first = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: 12))!
        var progress = ProgressData()
        var identifiers: Set<String> = []
        var geometries: Set<String> = []
        var timings: [Double] = []
        var loginCoins = 0
        var challengeCoins = 0
        for offset in 0..<365 {
            let date = calendar.date(byAdding: .day, value: offset, to: first)!
            let before = ProcessInfo.processInfo.systemUptime
            let challenge = DailyChallenge.generate(for: date, calendar: calendar)
            timings.append((ProcessInfo.processInfo.systemUptime - before) * 1_000)
            precondition(identifiers.insert(challenge.id).inserted && challenge.level.coinCells.isEmpty)
            geometries.insert(signature(challenge.level))
            var run = MazeRun(level: challenge.level)
            for direction in challenge.level.solution { precondition(!run.move(direction).isEmpty) }
            precondition(run.isComplete && !run.isFailed)
            let reward = progress.completeDailyChallenge(challenge, at: date, calendar: calendar)
            precondition(reward == 100)
            challengeCoins += reward
            precondition(progress.completeDailyChallenge(challenge, at: date, calendar: calendar) == 0)
            let login = progress.claimDailyReward(at: date, calendar: calendar)
            precondition(login == 25 + 5 * min(offset, 6))
            loginCoins += login
            precondition(progress.claimDailyReward(at: date, calendar: calendar) == 0)
            let restored = try decoder.decode(ProgressData.self, from: encoder.encode(progress))
            precondition(restored == progress && restored.hasCompletedDailyChallenge(challenge))
        }
        precondition(progress.dailyStreak == 365 && progress.dailyChallengeStreak == 365)
        precondition(progress.completedLevels == 0 && progress.challengeLevel == 1)
        return ["boards_verified": identifiers.count, "distinct_geometry_and_start": geometries.count,
                "generation_milliseconds": statistics(timings), "login_coins": loginCoins,
                "completion_coins": challengeCoins, "login_streak": progress.dailyStreak,
                "completion_streak": progress.dailyChallengeStreak]
    }

    static func auditMilestones(encoder: JSONEncoder, decoder: JSONDecoder) throws -> [String: Any] {
        var progress = ProgressData()
        for milestone in MilestoneChallenge.catalog { precondition(progress.claimMilestone(id: milestone.id) == 0) }
        for number in 1...25 { progress.completeLevel(.generate(number: number, mode: .endless)) }
        for number in 1...10 { progress.completeLevel(.generate(number: number, mode: .timed)) }
        for skin in BallSkin.catalog.prefix(4) { precondition(progress.purchaseSkin(skin)) }
        var coins = 0
        for milestone in MilestoneChallenge.catalog {
            precondition(milestone.isComplete(in: progress))
            let reward = progress.claimMilestone(id: milestone.id)
            precondition(reward == milestone.reward)
            coins += reward
            precondition(progress.claimMilestone(id: milestone.id) == 0)
        }
        var restored = try decoder.decode(ProgressData.self, from: encoder.encode(progress))
        precondition(restored == progress)
        for milestone in MilestoneChallenge.catalog { precondition(restored.claimMilestone(id: milestone.id) == 0) }
        return ["claimed_ids": progress.claimedMilestoneIDs.sorted(), "reward_coins": coins,
                "verified": MilestoneChallenge.catalog.count]
    }

    static func signature(_ level: MazeLevel) -> String {
        "\(level.width)x\(level.height):\(level.start.row),\(level.start.column):"
            + level.openCells.sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
    }

    static func isPerimeter(_ level: MazeLevel) -> Bool {
        level.openCells.count == 2 * level.width + 2 * level.height - 4
            && level.openCells.allSatisfy {
                $0.row == 0 || $0.column == 0 || $0.row == level.height - 1 || $0.column == level.width - 1
            }
    }

    static func percentile<T: Comparable>(_ values: [T], _ fraction: Double) -> T {
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction))]
    }

    static func statistics(_ values: [Double]) -> [String: Double] {
        ["min": values.min()!, "median": percentile(values, 0.5),
         "p95": percentile(values, 0.95), "p99": percentile(values, 0.99), "max": values.max()!]
    }

    /// Independent full-state BFS measures actual early challenge difficulty.
    /// -1 in the report means the explicit search cap was reached, not an unsolvable level.
    static func shortestSolution(_ level: MazeLevel, stateLimit: Int) -> (moves: Int?, states: Int) {
        let cells = level.openCells.sorted()
        guard cells.count < 64 else { return (nil, 0) }
        let indices = Dictionary(uniqueKeysWithValues: cells.enumerated().map { ($0.element, $0.offset) })
        let transitions = cells.map { cell in
            MoveDirection.allCases.compactMap { direction -> (position: Int, mask: UInt64)? in
                var cursor = cell
                var mask: UInt64 = 0
                while level.openCells.contains(cursor.neighbor(in: direction)) {
                    cursor = cursor.neighbor(in: direction)
                    mask |= UInt64(1) << indices[cursor]!
                }
                return mask == 0 ? nil : (indices[cursor]!, mask)
            }
        }
        let start = SearchState(position: indices[level.start]!, painted: UInt64(1) << indices[level.start]!)
        let allPainted = (UInt64(1) << cells.count) - 1
        var queue = [(state: start, depth: 0)]
        var seen: Set<SearchState> = [start]
        var index = 0
        while index < queue.count {
            let item = queue[index]
            index += 1
            if item.state.painted == allPainted { return (item.depth, seen.count) }
            for transition in transitions[item.state.position] {
                let next = SearchState(position: transition.position, painted: item.state.painted | transition.mask)
                if seen.insert(next).inserted { queue.append((next, item.depth + 1)) }
                if seen.count >= stateLimit { return (nil, seen.count) }
            }
        }
        return (nil, seen.count)
    }
}
