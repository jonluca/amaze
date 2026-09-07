import Foundation

/// Five increasingly complex mazes share one clock and the solo difficulty curve.
struct TimeRushCourse: Codable, Equatable, Sendable {
    let number: Int
    let levels: [MazeLevel]
    let timeLimit: Double

    var mazeCount: Int { levels.count }

    static func generate(number: Int) -> TimeRushCourse {
        let number = max(1, number)
        let completed = (number - 1).multipliedReportingOverflow(by: 5)
        // Seed identity is separate from difficulty, so even saturated progression
        // produces five different boards without overflowing an Int.
        let seedBase = Int((UInt64(number) &* 0x52555348434F5552) & UInt64(Int.max - 7))
        var stages: [MazeLevel] = []
        for stage in 0..<5 {
            let next = completed.partialValue.addingReportingOverflow(stage + 1)
            let difficultyNumber = completed.overflow || next.overflow ? Int.max : next.partialValue
            var level = MazeLevel.generate(
                number: seedBase + stage + 1, mode: .timed, difficultyNumber: difficultyNumber
            )
            if stages.contains(where: { $0.openCells == level.openCells }) {
                // Eight asymmetric orientations cannot be exhausted by four stages.
                let board = (0..<8).lazy.map {
                    MazeFallbackLayouts.make(size: level.width, orientation: $0)
                }.first { board in !stages.contains { $0.openCells == board.cells } }!
                level = MazeLevel(number: number, mode: .timed, width: level.width, height: level.height,
                    openCells: board.cells, start: board.start, solution: board.route, moveLimit: nil)
            }
            stages.append(level)
        }

        let timeLimit = currentTimeLimit(number: number, levels: stages)
        let levels = stages.map { level in
            MazeLevel(number: number, mode: .timed, width: level.width, height: level.height,
                openCells: level.openCells, start: level.start, solution: level.solution,
                moveLimit: nil, timeLimit: timeLimit)
        }
        return TimeRushCourse(number: number, levels: levels, timeLimit: timeLimit)
    }

    /// Apply current pacing to a fresh attempt without changing its saved mazes.
    /// An active run keeps its own remaining clock until the player restarts.
    func retimed() -> TimeRushCourse {
        let limit = Self.currentTimeLimit(number: number, levels: levels)
        let updated = levels.map { level in
            MazeLevel(number: level.number, mode: level.mode, width: level.width, height: level.height,
                openCells: level.openCells, start: level.start, solution: level.solution,
                moveLimit: level.moveLimit, timeLimit: limit, coinCells: level.coinCells)
        }
        return TimeRushCourse(number: number, levels: updated, timeLimit: limit)
    }

    private static func currentTimeLimit(number: Int, levels: [MazeLevel]) -> Double {
        // Stored routes guarantee coverage, but their detours are not optimal.
        // Allow thinking time for new paint and only execution time for returns.
        // Later rounds tighten the new-paint pace from 0.50 to 0.35 seconds.
        let paintMoveSeconds = 0.50 - min(0.15, Double(max(1, number) - 1) * 0.0075)
        var seconds = Double(levels.count) // One second to read each new board.
        for level in levels {
            var run = MazeRun(level: level)
            for direction in level.solution {
                guard !run.isComplete else { break }
                let paintedBefore = run.painted.count
                guard !run.move(direction).isEmpty else { continue }
                seconds += run.painted.count > paintedBefore ? paintMoveSeconds : 0.16
            }
        }
        return max(5, ceil(seconds / 5) * 5)
    }
}
