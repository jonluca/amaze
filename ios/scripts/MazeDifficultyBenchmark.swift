import Foundation

/// Compile against either the captured baseline Core files or the current Core sources.
/// Reports structural measures separately; feasible route length is not a difficulty score.
@main
struct MazeDifficultyBenchmark {
    struct Edge {
        let destination: Int
        let mask: UInt64
    }
    struct State: Hashable {
        let position: Int
        let mask: UInt64
    }
    struct SearchResult {
        let minimum: Int?
        let lowerBound: Int
        let states: Int
        let status: String
    }
    struct Row: Codable {
        let mode: String
        let number: Int
        let band: String
        let width: Int
        let height: Int
        let cells: Int
        let solutionMoves: Int
        let greedyMoves: Int
        let moveLimit: Int?
        let reachableStops: Int
        let stopsWithThreeOrFourChoices: Int
        let deadEndTiles: Int
        let solutionMovesWithoutNewPaint: Int
        let solutionRevisitedCellSteps: Int
        let unavoidableRevisitedCellStepsLowerBound: Int
        let independentSwipeLowerBound: Int
        let searchSwipeLowerBound: Int
        let exactMinimumSwipes: Int?
        let exactSearchStates: Int
        let exactSearchStatus: String
        let exactSearchMilliseconds: Double
        let perimeterRing: Bool
        let canonicalShape: String
        let generationMilliseconds: Double
    }
    struct Report: Codable {
        let label: String
        let exactCellLimit: Int
        let exactStateLimit: Int
        let notes: [String]
        let rows: [Row]
    }

    static let exactCellLimit: Int = {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--exact-cells"), index + 1 < arguments.count,
              let value = Int(arguments[index + 1]) else { return 32 }
        return min(63, max(1, value))
    }()
    static let exactStateLimit = 80_000

    static func main() throws {
        let arguments = CommandLine.arguments
        func argument(_ flag: String, default fallback: String) -> String {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return fallback }
            return arguments[index + 1]
        }
        validateSearch()
        let label = argument("--label", default: "current")
        let output = argument("--output", default: "/tmp/maze-difficulty.json")
        let boardsOutput = argument("--boards-output", default: output.replacingOccurrences(of: ".json", with: "-boards.json"))
        let allBands: [(String, ClosedRange<Int>)] = [
            ("1–20", 1...20), ("21–40", 21...40), ("101–120", 101...120),
            ("1001–1020", 1_001...1_020), ("10001–10020", 10_001...10_020)
        ]
        let bands = arguments.contains("--early-only") ? Array(allBands.prefix(1)) : allBands
        var rows: [Row] = []
        for mode in [GameMode.endless, .challenge] {
            for (band, numbers) in bands {
                for number in numbers {
                    let started = ProcessInfo.processInfo.systemUptime
                    let level = MazeLevel.generate(number: number, mode: mode)
                    let duration = (ProcessInfo.processInfo.systemUptime - started) * 1_000
                    rows.append(measure(level, band: band, milliseconds: duration))
                }
                print("Measured \(label) \(mode.rawValue) \(band)")
            }
        }
        let report = Report(label: label, exactCellLimit: exactCellLimit, exactStateLimit: exactStateLimit, notes: [
            "Each band contains 20 deterministic levels per mode. Generation timings exclude analysis.",
            "Exact minimum uses breadth-first search over stopping position plus painted-cell mask. A capped search reports only a proven lower bound, never an estimated optimum.",
            "Independent swipe bound selects unpainted witness tiles such that no reachable slide paints two witnesses; each requires a distinct move.",
            "Mandatory revisit bound sums leaf-corridor exits, excluding the largest possible final exit and truncating at the starting tile where appropriate. This counts unavoidable repeated cell steps, not repeated whole moves.",
            "Perimeter-ring geometry identifies the old fallback shape, but does not instrument the generator to distinguish a coincidentally selected ring.",
            "Canonical shape removes translation, rotation and reflection and ignores start location; corridor lengths remain part of geometry.",
            "Greedy route lengths and route-specific revisits are feasible-solution properties, not proofs of human difficulty or optimality."
        ], rows: rows)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: URL(fileURLWithPath: output))
        let examples = [GameMode.endless, .challenge].flatMap { mode in
            [1, 3, 12, 30].map { MazeLevel.generate(number: $0, mode: mode) }
        }
        try encoder.encode(examples).write(to: URL(fileURLWithPath: boardsOutput))
        print("Saved \(rows.count) boards to \(output)")
        print("Saved \(examples.count) representative boards to \(boardsOutput)")
    }

    static func measure(_ level: MazeLevel, band: String, milliseconds: Double) -> Row {
        let stops = reachableStops(level)
        let slides = Dictionary(uniqueKeysWithValues: stops.map { ($0, MazeSolver.slides(from: $0, in: level.openCells)) })
        let allSlides = stops.flatMap { slides[$0, default: []] }
        let witnessBound = independentSwipeBound(level: level, slides: allSlides)
        let searchStarted = ProcessInfo.processInfo.systemUptime
        let result = minimumSwipes(level: level, stops: stops, slides: slides, lowerBound: witnessBound)
        let searchDuration = (ProcessInfo.processInfo.systemUptime - searchStarted) * 1_000
        var covered: Set<GridCell> = [level.start]
        var position = level.start
        var emptyMoves = 0
        var revisits = 0
        for direction in level.solution {
            let path = MazeSolver.path(from: position, direction: direction, in: level.openCells)
            precondition(!path.isEmpty, "Stored solution includes blocked move")
            let newCells = Set(path).subtracting(covered)
            if newCells.isEmpty { emptyMoves += 1 }
            revisits += path.count - newCells.count
            covered.formUnion(path)
            position = path.last!
        }
        precondition(covered == level.openCells, "Stored solution does not cover board")
        var ring: Set<GridCell> = []
        for row in 0..<level.height {
            for column in 0..<level.width where row == 0 || row == level.height - 1 || column == 0 || column == level.width - 1 {
                ring.insert(GridCell(row: row, column: column))
            }
        }
        let leafTiles = level.openCells.filter { neighbors($0, in: level.openCells).count == 1 }
        return Row(mode: level.mode.rawValue, number: level.number, band: band,
            width: level.width, height: level.height, cells: level.openCells.count,
            solutionMoves: level.solution.count,
            greedyMoves: MazeSolver.coveringRoute(openCells: level.openCells, position: level.start, painted: [level.start])!.count,
            moveLimit: level.moveLimit, reachableStops: stops.count,
            stopsWithThreeOrFourChoices: stops.filter { slides[$0, default: []].count >= 3 }.count,
            deadEndTiles: leafTiles.count, solutionMovesWithoutNewPaint: emptyMoves,
            solutionRevisitedCellSteps: revisits,
            unavoidableRevisitedCellStepsLowerBound: mandatoryReturnBound(level: level, leaves: leafTiles),
            independentSwipeLowerBound: witnessBound, searchSwipeLowerBound: result.lowerBound,
            exactMinimumSwipes: result.minimum, exactSearchStates: result.states, exactSearchStatus: result.status,
            exactSearchMilliseconds: searchDuration,
            perimeterRing: level.openCells == ring, canonicalShape: canonicalShape(level.openCells),
            generationMilliseconds: milliseconds)
    }

    static func reachableStops(_ level: MazeLevel) -> [GridCell] {
        var seen: Set<GridCell> = [level.start]
        var pending = [level.start]
        while let cell = pending.popLast() {
            for slide in MazeSolver.slides(from: cell, in: level.openCells) {
                if seen.insert(slide.destination).inserted { pending.append(slide.destination) }
            }
        }
        return seen.sorted()
    }

    static func independentSwipeBound(level: MazeLevel, slides: [MazeSlide]) -> Int {
        let candidates = level.openCells.subtracting([level.start])
        var conflicts = Dictionary(uniqueKeysWithValues: candidates.map { ($0, Set([$0])) })
        for slide in slides {
            let cells = Set(slide.cells).intersection(candidates)
            for cell in cells { conflicts[cell, default: []].formUnion(cells) }
        }
        // Several deterministic starting orders strengthen this valid packing bound.
        var best = 0
        let ordered = candidates.sorted()
        for offset in 0..<min(ordered.count, 8) {
            var remaining = candidates
            var count = 0
            if !ordered.isEmpty {
                let first = ordered[offset * ordered.count / min(ordered.count, 8)]
                remaining.subtract(conflicts[first, default: [first]])
                count = 1
            }
            while !remaining.isEmpty {
                let next = remaining.min { first, second in
                    let lhs = conflicts[first, default: []].intersection(remaining).count
                    let rhs = conflicts[second, default: []].intersection(remaining).count
                    return lhs == rhs ? first < second : lhs < rhs
                }!
                remaining.subtract(conflicts[next, default: [next]])
                count += 1
            }
            best = max(best, count)
        }
        return best
    }

    static func minimumSwipes(level: MazeLevel, stops: [GridCell], slides: [GridCell: [MazeSlide]], lowerBound: Int) -> SearchResult {
        guard level.openCells.count <= exactCellLimit else {
            return SearchResult(minimum: nil, lowerBound: lowerBound, states: 0, status: "cell-limit")
        }
        let cells = level.openCells.sorted()
        let cellIndex = Dictionary(uniqueKeysWithValues: cells.enumerated().map { ($1, $0) })
        let stopIndex = Dictionary(uniqueKeysWithValues: stops.enumerated().map { ($1, $0) })
        let edges = stops.map { stop in
            slides[stop, default: []].map { slide in
                Edge(destination: stopIndex[slide.destination]!,
                    mask: slide.cells.reduce(UInt64(0)) { $0 | (UInt64(1) << cellIndex[$1]!) })
            }
        }
        let full = (UInt64(1) << cells.count) - 1
        let initial = State(position: stopIndex[level.start]!, mask: UInt64(1) << cellIndex[level.start]!)
        var seen: Set<State> = [initial]
        var queue: [(State, Int)] = [(initial, 0)]
        var cursor = 0
        while cursor < queue.count {
            let (current, depth) = queue[cursor]
            cursor += 1
            for edge in edges[current.position] {
                let next = State(position: edge.destination, mask: current.mask | edge.mask)
                if next.mask == full {
                    precondition(depth + 1 >= lowerBound, "Invalid independent bound")
                    return SearchResult(minimum: depth + 1, lowerBound: depth + 1, states: seen.count, status: "exact")
                }
                guard seen.insert(next).inserted else { continue }
                if seen.count >= exactStateLimit {
                    return SearchResult(minimum: nil, lowerBound: max(lowerBound, depth + 1), states: seen.count, status: "state-limit")
                }
                queue.append((next, depth + 1))
            }
        }
        preconditionFailure("Validated board has no covering solution")
    }

    static func neighbors(_ cell: GridCell, in open: Set<GridCell>) -> [GridCell] {
        MoveDirection.allCases.map { cell.neighbor(in: $0) }.filter { open.contains($0) }
    }

    static func mandatoryReturnBound(level: MazeLevel, leaves: Set<GridCell>) -> Int {
        var costs: [Int] = []
        for leaf in leaves where leaf != level.start {
            var previous = leaf
            var cursor = neighbors(leaf, in: level.openCells)[0]
            var distance = 1
            while cursor != level.start && neighbors(cursor, in: level.openCells).count == 2 {
                let next = neighbors(cursor, in: level.openCells).first { $0 != previous }!
                previous = cursor
                cursor = next
                distance += 1
            }
            costs.append(distance)
        }
        return costs.reduce(0, +) - (costs.max() ?? 0)
    }

    static func canonicalShape(_ cells: Set<GridCell>) -> String {
        (0..<8).map { orientation in
            let transformed = cells.map { cell -> GridCell in
                var row = cell.row
                var column = orientation >= 4 ? -cell.column : cell.column
                for _ in 0..<(orientation % 4) { (row, column) = (column, -row) }
                return GridCell(row: row, column: column)
            }
            let minimumRow = transformed.map(\.row).min()!
            let minimumColumn = transformed.map(\.column).min()!
            return transformed.map { GridCell(row: $0.row - minimumRow, column: $0.column - minimumColumn) }
                .sorted().map { "\($0.row),\($0.column)" }.joined(separator: ";")
        }.min()!
    }

    static func validateSearch() {
        for size in [2, 4] {
            let open = Set((0..<size).flatMap { row in
                (0..<size).filter { row == 0 || row == size - 1 || $0 == 0 || $0 == size - 1 }
                    .map { GridCell(row: row, column: $0) }
            })
            let level = MazeLevel(number: 1, mode: .endless, width: size, height: size,
                openCells: open, start: GridCell(row: 0, column: 0), solution: [.down, .right, .up, .left], moveLimit: nil)
            let stops = reachableStops(level)
            let slides = Dictionary(uniqueKeysWithValues: stops.map { ($0, MazeSolver.slides(from: $0, in: open)) })
            let result = minimumSwipes(level: level, stops: stops, slides: slides, lowerBound: 0)
            precondition(result.minimum == (size == 2 ? 3 : 4))
        }
    }
}
