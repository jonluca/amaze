import XCTest
@testable import PrismRoll

final class MazeClassicUniquenessTests: XCTestCase {
    func testFirstThousandClassicBoardsAreUniquePlayableAndHaveExactCounts() {
        var currentIdentities: [Identity: Int] = [:]
        var currentShapes: [Set<GridCell>: Int] = [:]
        for number in 1...1_000 {
            let current = MazeLevel.generate(number: number, mode: .endless)
            let currentIdentity = Identity(current)
            guard let minimum = MazePerfectMoveCatalog.minimumMoves(for: current) else {
                XCTFail("Missing exact count for Classic level \(number)")
                continue
            }
            if let prior = currentIdentities.updateValue(number, forKey: currentIdentity) {
                XCTFail("Classic levels \(prior) and \(number) repeat the same full board/start identity")
            }
            if let prior = currentShapes.updateValue(number, forKey: current.openCells) {
                XCTFail("Classic levels \(prior) and \(number) repeat the same walls even when ignoring start")
            }
            XCTAssertGreaterThan(minimum, 0)
            XCTAssertLessThanOrEqual(minimum, current.solution.count)
            assertPlayableDifficulty(current)
        }
        XCTAssertEqual(currentIdentities.count, 1_000)
        XCTAssertEqual(currentShapes.count, 1_000)
    }

    func testCatalogGenerationIsDeterministicForUnorderedAndConcurrentRequests() async {
        let numbers = [998, 8, 1_000, 72, 1, 150, 149, 8, 142, 998, 1_001]
        let expected = Dictionary(uniqueKeysWithValues: Set(numbers).map {
            ($0, MazeLevel.generate(number: $0, mode: .endless))
        })
        for number in numbers.reversed() {
            XCTAssertEqual(MazeLevel.generate(number: number, mode: .endless), expected[number])
        }
        await withTaskGroup(of: MazeLevel.self) { group in
            for number in numbers {
                group.addTask { MazeLevel.generate(number: number, mode: .endless) }
            }
            for await level in group { XCTAssertEqual(level, expected[level.number]) }
        }
    }

    func testClassicSeedCatalogAppliesOnlyToCanonicalClassicRequests() {
        for mode in [GameMode.challenge, .timed] {
            for number in [8, 72, 150, 998] {
                XCTAssertEqual(MazeLevel.generate(number: number, mode: mode),
                               MazeLevel.generateProcedural(number: number, mode: mode, difficultyNumber: number))
            }
        }
        for (number, difficulty) in [(8, 72), (72, 8), (150, 1_000), (998, 1)] {
            XCTAssertEqual(MazeLevel.generate(number: number, mode: .endless, difficultyNumber: difficulty),
                           MazeLevel.generateProcedural(number: number, mode: .endless, difficultyNumber: difficulty))
        }
        for number in [0, -1, 1_001, 10_000, Int.max] {
            XCTAssertEqual(MazeLevel.generate(number: number, mode: .endless),
                           MazeLevel.generateProcedural(number: number, mode: .endless, difficultyNumber: number))
        }
    }

    private func assertPlayableDifficulty(_ level: MazeLevel) {
        let difficulty = MazeDifficulty(number: level.number, mode: .endless)
        let topology = MazeTopology(openCells: level.openCells, start: level.start)
        let layout = MazeLayout(cells: level.openCells, start: level.start, route: level.solution, topology: topology)
        XCTAssertTrue(difficulty.accepts(layout), "Classic \(level.number) must meet its difficulty gate")
        XCTAssertTrue(MazeSolver.isFullyPlayable(openCells: level.openCells, start: level.start),
                      "Classic \(level.number) must be recoverable from every stop")
        var run = MazeRun(level: level)
        for direction in level.solution {
            XCTAssertFalse(run.isComplete, "Padded route for Classic \(level.number)")
            XCTAssertFalse(run.move(direction).isEmpty, "Blocked swipe for Classic \(level.number)")
        }
        XCTAssertTrue(run.isComplete, "Stored route must finish Classic \(level.number)")
    }

    private struct Identity: Hashable {
        let width: Int
        let height: Int
        let start: GridCell
        let cells: Set<GridCell>

        init(_ level: MazeLevel) {
            width = level.width
            height = level.height
            start = level.start
            cells = level.openCells
        }
    }
}
