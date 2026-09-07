import XCTest
@testable import PrismRoll

final class MazeGrowthTests: XCTestCase {
    func testPlayableGeometryGrowsBeyondTheFormerTenCellPlateau() {
        for mode in GameMode.allCases {
            let early = MazeLevel.generate(number: 1, mode: mode)
            let middle = MazeLevel.generate(number: 20, mode: mode)
            let advanced = MazeLevel.generate(number: 100, mode: mode)
            let late = MazeLevel.generate(number: 200, mode: mode)
            let earlySpan = spans(early.openCells)
            let middleSpan = spans(middle.openCells)
            let advancedSpan = spans(advanced.openCells)
            XCTAssertGreaterThan(middleSpan.rows, earlySpan.rows, "\(mode): the maze itself must grow")
            XCTAssertGreaterThan(middleSpan.columns, earlySpan.columns)
            XCTAssertGreaterThan(advancedSpan.rows, middleSpan.rows)
            XCTAssertGreaterThan(advancedSpan.columns, middleSpan.columns)
            XCTAssertGreaterThanOrEqual(advancedSpan.rows, 15)
            XCTAssertGreaterThanOrEqual(advancedSpan.columns, 15)
            XCTAssertGreaterThan(middle.openCells.count, early.openCells.count * 2)
            XCTAssertGreaterThan(advanced.openCells.count, middle.openCells.count)
            XCTAssertGreaterThanOrEqual(advanced.openCells.count, 128, "A larger frame cannot disguise a small playable maze")
            XCTAssertGreaterThanOrEqual(late.openCells.count, 128)
        }
    }

    func testEveryGrowthMilestoneFillsItsBoardWithoutPaddingAndRemainsDeterministic() {
        for mode in GameMode.allCases {
            for number in [1, 5, 10, 20, 40, 75, 100, 200, 1_000] {
                let level = MazeLevel.generate(number: number, mode: mode)
                XCTAssertEqual(level, MazeLevel.generate(number: number, mode: mode))
                XCTAssertLessThanOrEqual(level.width, 16)
                XCTAssertLessThanOrEqual(level.height, 16)
                assertGeometry(level.openCells, width: level.width, height: level.height)
                assertSolution(cells: level.openCells, start: level.start, route: level.solution)
            }
        }
    }

    func testMatureMazesRequireMoreIndependentCoverageDecisionsAndReturns() {
        for mode in GameMode.allCases {
            let early = [1, 2, 3].map { independentMetrics(MazeLevel.generate(number: $0, mode: mode)) }
            let mature = [200, 201, 202].map { independentMetrics(MazeLevel.generate(number: $0, mode: mode)) }
            let earlySwipes = early.reduce(0) { $0 + $1.swipeLowerBound }
            let matureSwipes = mature.reduce(0) { $0 + $1.swipeLowerBound }
            let earlyDecisions = early.reduce(0) { $0 + $1.decisions }
            let matureDecisions = mature.reduce(0) { $0 + $1.decisions }
            let earlyReturns = early.reduce(0) { $0 + $1.returnLowerBound }
            let matureReturns = mature.reduce(0) { $0 + $1.returnLowerBound }
            XCTAssertGreaterThan(matureSwipes, earlySwipes * 2, "\(mode): a long stored route alone is not proof of harder geometry")
            XCTAssertGreaterThan(matureDecisions, earlyDecisions * 2, "\(mode): added space must contain actual decisions")
            XCTAssertGreaterThan(matureReturns, earlyReturns, "\(mode): mature geometry must require more backtracking")
        }
    }

    func testTimeRushCoursesGrowInActualAreaAndStructureWhileKeepingFiveDistinctMazes() {
        let rounds = [1, 2, 5, 10, 20, 40]
        let courses = rounds.map { TimeRushCourse.generate(number: $0) }
        for course in courses {
            XCTAssertEqual(course.mazeCount, 5)
            XCTAssertEqual(course, TimeRushCourse.generate(number: course.number))
            XCTAssertEqual(Set(course.levels.map(\.openCells)).count, 5)
            XCTAssertTrue(course.timeLimit.isFinite)
            XCTAssertGreaterThan(course.timeLimit, 0)
            for level in course.levels {
                XCTAssertLessThanOrEqual(level.width, 16)
                XCTAssertLessThanOrEqual(level.height, 16)
                assertGeometry(level.openCells, width: level.width, height: level.height)
                assertSolution(cells: level.openCells, start: level.start, route: level.solution)
            }
        }
        let early = courses[0]
        let middle = courses[3]
        let mature = courses[5]
        let earlyArea = early.levels.reduce(0) { $0 + $1.openCells.count }
        let middleArea = middle.levels.reduce(0) { $0 + $1.openCells.count }
        let matureArea = mature.levels.reduce(0) { $0 + $1.openCells.count }
        XCTAssertGreaterThan(middleArea, earlyArea * 2)
        XCTAssertGreaterThan(matureArea, middleArea)
        for level in courses[4].levels + mature.levels {
            let span = spans(level.openCells)
            XCTAssertGreaterThanOrEqual(span.rows, 15)
            XCTAssertGreaterThanOrEqual(span.columns, 15)
            XCTAssertGreaterThanOrEqual(level.openCells.count, 128)
        }
        let earlyStructure = independentMetrics(early.levels[0])
        let matureStructure = independentMetrics(mature.levels[0])
        XCTAssertGreaterThan(matureStructure.swipeLowerBound, earlyStructure.swipeLowerBound * 2)
        XCTAssertGreaterThan(matureStructure.decisions, earlyStructure.decisions * 2)
        XCTAssertGreaterThan(matureStructure.returnLowerBound, earlyStructure.returnLowerBound)
    }

    func testAllFallbackSizesAndOrientationsUseRealPlayableSpace() {
        for size in 5...16 {
            var shapes: Set<Set<GridCell>> = []
            for variant in 0..<MazeFallbackLayouts.variantCount(size: size) {
                for orientation in 0..<8 {
                    let layout = MazeFallbackLayouts.make(size: size, orientation: orientation, variant: variant)
                    let repeated = MazeFallbackLayouts.make(size: size, orientation: orientation, variant: variant)
                    XCTAssertEqual(layout.cells, repeated.cells)
                    XCTAssertEqual(layout.start, repeated.start)
                    XCTAssertEqual(layout.route, repeated.route)
                    assertGeometry(layout.cells, width: size, height: size)
                    assertSolution(cells: layout.cells, start: layout.start, route: layout.route)
                    XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: layout.cells, start: layout.start))
                    shapes.insert(layout.cells)
                }
            }
            XCTAssertEqual(shapes.count, 8 * MazeFallbackLayouts.variantCount(size: size),
                           "Size \(size) must preserve eight distinct orientations of each independent shape family")
        }
    }

    func testLargeMazesRemainRecoverableAfterOffRouteSwipes() throws {
        for mode in GameMode.allCases {
            for number in [40, 100, 200, Int.max] {
                let level = MazeLevel.generate(number: number, mode: mode)
                var position = level.start
                var painted: Set<GridCell> = [position]
                var random = SeededGenerator(seed: UInt64(max(1, number)))
                for _ in 0..<12 {
                    let slides = MazeSolver.slides(from: position, in: level.openCells)
                    let slide = try XCTUnwrap(slides.isEmpty ? nil : slides[random.integer(lessThan: slides.count)])
                    painted.formUnion(slide.cells)
                    position = slide.destination
                }
                let recovery = try XCTUnwrap(MazeSolver.coveringRoute(
                    openCells: level.openCells, position: position, painted: painted
                ))
                for direction in recovery {
                    let path = MazeSolver.path(from: position, direction: direction, in: level.openCells)
                    position = try XCTUnwrap(path.last)
                    painted.formUnion(path)
                }
                XCTAssertEqual(painted, level.openCells, "\(mode) \(number) must remain geometrically solvable after a deviation")
            }
        }
    }

    func testExtremeLevelNumbersKeepBoundedDimensionsAndExecutableRoutes() {
        for mode in GameMode.allCases {
            for number in [Int.min, -1, 0, Int.max - 1, Int.max] {
                let level = MazeLevel.generate(number: number, mode: mode)
                XCTAssertEqual(level.number, max(1, number))
                XCTAssertGreaterThanOrEqual(level.width, 5)
                XCTAssertLessThanOrEqual(level.width, 16)
                XCTAssertLessThanOrEqual(level.height, 16)
                assertGeometry(level.openCells, width: level.width, height: level.height)
                assertSolution(cells: level.openCells, start: level.start, route: level.solution)
            }
        }
    }

    private func spans(_ cells: Set<GridCell>) -> (rows: Int, columns: Int) {
        let rows = cells.map(\.row)
        let columns = cells.map(\.column)
        return ((rows.max() ?? 0) - (rows.min() ?? 0) + 1, (columns.max() ?? 0) - (columns.min() ?? 0) + 1)
    }

    /// These measurements do not use the generator's difficulty gates or stored route.
    private func independentMetrics(_ level: MazeLevel) -> (swipeLowerBound: Int, decisions: Int, returnLowerBound: Int) {
        var graph: [GridCell: [MazeSlide]] = [:]
        var pending = [level.start]
        while let stop = pending.popLast() {
            guard graph[stop] == nil else { continue }
            let slides = MazeSolver.slides(from: stop, in: level.openCells)
            graph[stop] = slides
            pending.append(contentsOf: slides.map(\.destination))
        }

        // No possible single swipe covers two chosen witnesses, so each needs a move.
        let candidates = level.openCells.subtracting([level.start])
        var conflicts = Dictionary(uniqueKeysWithValues: candidates.map { ($0, Set([$0])) })
        for slides in graph.values {
            for slide in slides {
                let cells = Set(slide.cells).intersection(candidates)
                for cell in cells { conflicts[cell, default: []].formUnion(cells) }
            }
        }
        var remaining = candidates
        var witnesses = 0
        while let next = remaining.min(by: { first, second in
            let firstCount = conflicts[first, default: []].intersection(remaining).count
            let secondCount = conflicts[second, default: []].intersection(remaining).count
            return firstCount == secondCount ? first < second : firstCount < secondCount
        }) {
            remaining.subtract(conflicts[next, default: [next]])
            witnesses += 1
        }

        // Every terminal corridor except the last one must be walked back out.
        func neighbors(_ cell: GridCell) -> [GridCell] {
            MoveDirection.allCases.map { cell.neighbor(in: $0) }.filter { level.openCells.contains($0) }
        }
        var returns: [Int] = []
        for leaf in level.openCells where leaf != level.start && neighbors(leaf).count == 1 {
            var previous = leaf
            var cursor = neighbors(leaf)[0]
            var distance = 1
            while cursor != level.start && neighbors(cursor).count == 2 {
                guard let next = neighbors(cursor).first(where: { $0 != previous }) else { break }
                previous = cursor
                cursor = next
                distance += 1
            }
            returns.append(distance)
        }
        return (witnesses, graph.values.filter { $0.count >= 3 }.count, returns.reduce(0, +) - (returns.max() ?? 0))
    }

    private func assertGeometry(
        _ cells: Set<GridCell>, width: Int, height: Int,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let span = spans(cells)
        XCTAssertGreaterThanOrEqual(span.rows, height - 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(span.columns, width - 1, file: file, line: line)
        XCTAssertGreaterThanOrEqual(cells.count, width * height / 2, file: file, line: line)
        XCTAssertLessThan(cells.count, width * height, file: file, line: line)
        XCTAssertTrue(cells.allSatisfy {
            (0..<height).contains($0.row) && (0..<width).contains($0.column)
        }, file: file, line: line)
    }

    private func assertSolution(
        cells: Set<GridCell>, start: GridCell, route: [MoveDirection],
        file: StaticString = #filePath, line: UInt = #line
    ) {
        var painted: Set<GridCell> = [start]
        var position = start
        for direction in route {
            XCTAssertNotEqual(painted, cells, "Winning routes must not be padded", file: file, line: line)
            let path = MazeSolver.path(from: position, direction: direction, in: cells)
            XCTAssertFalse(path.isEmpty, file: file, line: line)
            painted.formUnion(path)
            position = path.last ?? position
        }
        XCTAssertEqual(painted, cells, file: file, line: line)
    }
}
