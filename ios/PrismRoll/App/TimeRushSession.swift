import Foundation

/// A saved round owns its exact mazes so updates do not change an active course.
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
