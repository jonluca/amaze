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
            XCTAssertGreaterThanOrEqual(course.timeLimit, 60)
            XCTAssertLessThanOrEqual(course.timeLimit, 90)
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
        XCTAssertEqual(first.timeLimit, 60)
        XCTAssertEqual(first.levels.map(\.width), [5, 5, 6, 6, 7])
        for (index, level) in first.levels.enumerated() {
            XCTAssertGreaterThanOrEqual(level.solution.count, 8 + index * 2)
        }
        XCTAssertGreaterThanOrEqual(first.levels.reduce(0) { $0 + $1.solution.count }, 60)
        XCTAssertGreaterThan(
            first.levels.reduce(0) { $0 + $1.openCells.count },
            MazeLevel.generate(number: 1, mode: .timed).openCells.count * 5
        )
    }

    func testLaterCoursesIncreaseBoardSizeAndSharedClockPressure() {
        let first = TimeRushCourse.generate(number: 1)
        let later = TimeRushCourse.generate(number: 25)
        XCTAssertTrue(later.levels.allSatisfy { $0.width == 9 && $0.solution.count >= 24 })
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

    func testBoundedFallbackHasEightDistinctExecutableOrientations() {
        for size in 5...9 {
            var previousCells: [Set<GridCell>] = []
            for _ in 0..<8 {
                let board = TimeRushCourse.fallbackBoard(size: size, firstOrientation: 0, excluding: previousCells)
                XCTAssertFalse(previousCells.contains(board.cells))
                XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: board.cells, start: board.start))
                XCTAssertGreaterThanOrEqual(board.route.count, size * 4 - 8)
                var position = board.start
                var painted: Set<GridCell> = [position]
                for direction in board.route {
                    let path = MazeSolver.path(from: position, direction: direction, in: board.cells)
                    XCTAssertFalse(path.isEmpty)
                    painted.formUnion(path)
                    position = path.last ?? position
                }
                XCTAssertEqual(painted, board.cells)
                previousCells.append(board.cells)
            }
        }
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
