import XCTest
@testable import PrismRoll

final class TimeRushCourseTests: XCTestCase {
    func testCoursesHaveFiveDistinctMazesAndOneSharedBudget() {
        for number in 1...100 {
            let course = TimeRushCourse.generate(number: number)
            XCTAssertEqual(course.mazeCount, 5)
            XCTAssertEqual(course.number, number)
            XCTAssertEqual(Set(course.levels.map(\.openCells)).count, 5)
            XCTAssertTrue(course.levels.allSatisfy {
                $0.number == number && $0.mode == .timed && $0.timeLimit == course.timeLimit
                    && $0.moveLimit == nil && $0.coinCells.isEmpty
            })
            XCTAssertGreaterThanOrEqual(course.timeLimit, 45)
            XCTAssertLessThanOrEqual(course.timeLimit, 240)
            let moves = Double(course.levels.reduce(0) { $0 + $1.solution.count })
            XCTAssertGreaterThanOrEqual(course.timeLimit, moves * 0.25 + Double(course.mazeCount),
                "A known solution at four swipes per second, plus board-reading time, must fit without ads")
            let previousBudget = max(60, ceil((moves * (0.95 - min(0.20, Double(number - 1) * 0.008)) + 10) / 5) * 5)
            XCTAssertLessThanOrEqual(course.timeLimit, previousBudget * 0.55,
                "The generous build 6 timing must not return")
        }
    }

    func testEveryCourseStageHasAnExecutableRecoverableSolution() {
        for number in 1...100 {
            let course = TimeRushCourse.generate(number: number)
            for level in course.levels {
                XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: level.openCells, start: level.start))
                XCTAssertTrue(level.openCells.allSatisfy {
                    $0.row >= 0 && $0.row < level.height && $0.column >= 0 && $0.column < level.width
                })
                XCTAssertLessThan(level.openCells.count, level.width * level.height)
                var run = MazeRun(level: level)
                for direction in level.solution {
                    XCTAssertFalse(run.move(direction).isEmpty, "Course \(number)")
                }
                XCTAssertTrue(run.isComplete, "Course \(number)")
                XCTAssertEqual(run.painted, level.openCells)
                XCTAssertFalse(run.isFailed)
            }
        }
    }

    func testFirstCourseStartsPastTheTrivialBoardsAndHasSubstantialWork() {
        let first = TimeRushCourse.generate(number: 1)
        XCTAssertEqual(first.timeLimit, 55, "The opening round should require focused play")
        XCTAssertEqual(first.levels.map(\.width), [6, 7, 7, 8, 8])
        for (index, level) in first.levels.enumerated() {
            XCTAssertGreaterThanOrEqual(level.solution.count, 12 + index * 2)
        }
        XCTAssertGreaterThanOrEqual(first.levels.reduce(0) { $0 + $1.solution.count }, 90)
        XCTAssertGreaterThan(
            first.levels.reduce(0) { $0 + $1.openCells.count },
            MazeLevel.generate(number: 1, mode: .timed).openCells.count * 5
        )
    }

    func testLaterCoursesIncreaseBoardSizeAndSharedClockPressure() {
        let first = TimeRushCourse.generate(number: 1)
        let later = TimeRushCourse.generate(number: 25)
        XCTAssertTrue(later.levels.allSatisfy { $0.width == 16 && $0.solution.count >= 80 })
        let firstMovesPerSecond = Double(first.levels.reduce(0) { $0 + $1.solution.count }) / first.timeLimit
        let laterMovesPerSecond = Double(later.levels.reduce(0) { $0 + $1.solution.count }) / later.timeLimit
        XCTAssertGreaterThan(laterMovesPerSecond, firstMovesPerSecond)
    }

    func testCourseGeometryIsDeterministicAndVariedAtMaximumDifficulty() {
        var firstBoards: Set<Set<GridCell>> = []
        for number in [1, 2, 3, 4, 7, 13, 25, 100, 10_000, Int.max] {
            let course = TimeRushCourse.generate(number: number)
            XCTAssertEqual(course, .generate(number: number))
            firstBoards.insert(course.levels[0].openCells)
        }
        XCTAssertGreaterThanOrEqual(firstBoards.count, 9)
    }

    func testCourseRoundTripsWithoutRegeneratingSavedGeometry() throws {
        let original = TimeRushCourse.generate(number: 12)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(TimeRushCourse.self, from: data), original)
    }

    func testRetimingPreservesAllMazeDataAndIsIdempotent() {
        let current = TimeRushCourse.generate(number: 20)
        let legacy = TimeRushCourse(number: current.number, levels: current.levels, timeLimit: 500)
        let updated = legacy.retimed()
        XCTAssertLessThan(updated.timeLimit, legacy.timeLimit)
        XCTAssertEqual(updated, current)
        XCTAssertEqual(updated.retimed(), updated)
    }

    func testUnusedMovesAfterCompletionCannotInflateTheBudget() {
        let current = TimeRushCourse.generate(number: 1)
        let padded = current.levels.map { level in
            MazeLevel(number: level.number, mode: level.mode, width: level.width, height: level.height,
                openCells: level.openCells, start: level.start,
                solution: level.solution + Array(repeating: MoveDirection.allCases, count: 100).flatMap { $0 },
                moveLimit: nil, timeLimit: 1_000)
        }
        let inflated = TimeRushCourse(number: 1, levels: padded, timeLimit: 1_000)
        XCTAssertEqual(inflated.retimed().timeLimit, current.timeLimit)
    }

    func testRepaintingDetoursGetAnExecutionAllowanceInsteadOfFullThinkingTime() {
        // An executable U-shaped maze: visit the top arm, return, then paint
        // down the spine and across the bottom. Extra arm returns add no paint.
        let cells = Set((0..<5).flatMap { [GridCell(row: 0, column: $0),
                                         GridCell(row: $0, column: 0),
                                         GridCell(row: 4, column: $0)] })
        func course(detours: Int) -> TimeRushCourse {
            let level = MazeLevel(number: 1, mode: .timed, width: 5, height: 5,
                openCells: cells, start: GridCell(row: 0, column: 0),
                solution: Array(repeating: [.right, .left] as [MoveDirection], count: detours + 1)
                    .flatMap { $0 } + [.down, .right], moveLimit: nil)
            return TimeRushCourse(number: 1, levels: [level], timeLimit: 1_000).retimed()
        }
        let direct = course(detours: 0)
        let detouring = course(detours: 20)
        var run = MazeRun(level: detouring.levels[0])
        for move in run.level.solution { run.move(move) }
        XCTAssertTrue(run.isComplete)
        XCTAssertGreaterThan(detouring.timeLimit, direct.timeLimit, "Returns still need execution time")
        XCTAssertLessThanOrEqual(detouring.timeLimit - direct.timeLimit, 10,
            "Forty already-painted swipes must not buy forty full reaction allowances")
    }

    func testExtremeCourseNumbersRemainValidWithoutOverflow() {
        for number in [Int.min, -1, 0, 1, 100_000, Int.max] {
            let course = TimeRushCourse.generate(number: number)
            XCTAssertEqual(course.number, max(1, number))
            XCTAssertEqual(course.mazeCount, 5)
            for level in course.levels {
                var run = MazeRun(level: level)
                for direction in level.solution { run.move(direction) }
                XCTAssertTrue(run.isComplete)
            }
        }
    }
}
