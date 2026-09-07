import Foundation

/// Saves stage and timer metadata; GameStore refreshes legacy grids to the shared catalog.
struct TimeRushSession: Codable, Equatable, Sendable {
    let course: TimeRushCourse
    var stageIndex = 0

    var isValid: Bool {
        course.number >= 1 && course.levels.count == 5
            && course.levels.indices.contains(stageIndex)
            && course.timeLimit.isFinite && course.timeLimit > 0
            && course.levels.allSatisfy { $0.mode == .timed && $0.number == course.number }
    }

    var currentLevel: MazeLevel { course.levels[stageIndex] }
}
