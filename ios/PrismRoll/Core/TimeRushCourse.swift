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

        // Larger courses need time proportional to their executable route. Tighten
        // the pace gradually while retaining time to read each new board.
        let secondsPerMove = 0.95 - min(0.20, Double(number - 1) * 0.008)
        let moves = stages.reduce(0) { $0 + $1.solution.count }
        let timeLimit = max(60, ceil((Double(moves) * secondsPerMove + 10) / 5) * 5)
        let levels = stages.map { level in
            MazeLevel(number: number, mode: .timed, width: level.width, height: level.height,
                openCells: level.openCells, start: level.start, solution: level.solution,
                moveLimit: nil, timeLimit: timeLimit)
        }
        return TimeRushCourse(number: number, levels: levels, timeLimit: timeLimit)
    }
}
