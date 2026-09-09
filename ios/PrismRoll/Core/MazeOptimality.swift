/// Finds or verifies the fewest effective swipes needed to paint a board.
///
/// Search is deliberately bounded. An exhausted budget never earns an award.
/// Call this CPU work from a background task with an immutable run snapshot.
enum MazeOptimality {
    enum Result: Equatable, Sendable {
        case optimal
        case notOptimal
        case undetermined
        case incomplete
    }

    private struct Paint: Hashable {
        var a: UInt64 = 0
        var b: UInt64 = 0
        var c: UInt64 = 0
        var d: UInt64 = 0

        mutating func insert(_ index: Int) {
            let bit = UInt64(1) << (index % 64)
            switch index / 64 {
            case 0: a |= bit
            case 1: b |= bit
            case 2: c |= bit
            default: d |= bit
            }
        }

        func union(_ other: Paint) -> Paint {
            Paint(a: a | other.a, b: b | other.b, c: c | other.c, d: d | other.d)
        }

        func intersection(_ other: Paint) -> Paint {
            Paint(a: a & other.a, b: b & other.b, c: c & other.c, d: d & other.d)
        }

        func contains(_ index: Int) -> Bool {
            var bit = Paint()
            bit.insert(index)
            return intersection(bit) == bit
        }

        var count: Int {
            a.nonzeroBitCount + b.nonzeroBitCount + c.nonzeroBitCount + d.nonzeroBitCount
        }
    }

    private struct State: Hashable {
        let stop: Int
        let painted: Paint
    }

    private struct Edge {
        let destination: Int
        let painted: Paint
    }

    private struct Graph {
        let goal: Paint
        let edges: [[Edge]]
        let maximumPaintPerMove: Int
    }

    /// Returns a proven minimum, or nil when the search cannot prove one within
    /// its budget. The generated solution is not necessarily a shortest route.
    /// Run this CPU work in the background using an immutable level snapshot.
    static func minimumMoves(
        for level: MazeLevel,
        stateLimit: Int = 500_000,
        timeLimit: Duration = .seconds(2),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> Int? {
        guard isSupported(level), stateLimit > 0 else { return nil }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeLimit)
        func shouldStop() -> Bool { isCancelled() || clock.now >= deadline }
        guard !shouldStop() else { return nil }
        if level.openCells.count == 1 { return 0 }
        guard let fullGraph = makeGraph(for: level, shouldStop: shouldStop),
              let graph = reducedGraph(fullGraph, for: level, shouldStop: shouldStop) else { return nil }

        var initialPaint = Paint()
        initialPaint.insert(level.start.row * 16 + level.start.column)
        let initial = State(stop: 0, painted: initialPaint.intersection(graph.goal))
        var visited: Set<State> = [initial]
        var frontier = [initial]
        var depth = 0

        // Every edge is one effective swipe. The first complete state reached
        // by breadth-first search therefore establishes the exact minimum.
        while !frontier.isEmpty {
            var next: [State] = []
            for (index, state) in frontier.enumerated() {
                if index.isMultiple(of: 256), shouldStop() { return nil }
                for edge in graph.edges[state.stop] {
                    let painted = state.painted.union(edge.painted)
                    if painted == graph.goal { return shouldStop() ? nil : depth + 1 }
                    let candidate = State(stop: edge.destination, painted: painted)
                    guard !visited.contains(candidate) else { continue }
                    guard visited.count < stateLimit else { return nil }
                    visited.insert(candidate)
                    next.append(candidate)
                }
            }
            frontier = next
            depth += 1
        }
        return nil
    }

    static func verify(
        _ run: MazeRun,
        stateLimit: Int = 100_000,
        timeLimit: Duration = .milliseconds(200),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> Result {
        guard run.isComplete else { return .incomplete }
        let level = run.level
        guard isSupported(level), run.moves >= 0 else { return .undetermined }
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeLimit)
        func shouldStop() -> Bool { isCancelled() || clock.now >= deadline }
        guard !shouldStop() else { return .undetermined }
        if level.openCells.count == 1 { return run.moves == 0 ? .optimal : .notOptimal }
        guard run.moves > 0 else { return .undetermined }

        // The generated route is an upper bound, never a proof of optimality.
        // It can cheaply disqualify a longer run after checking its actual slides.
        if level.solution.count < run.moves, solutionIsShorter(than: run) { return .notOptimal }
        guard stateLimit > 0 else { return .undetermined }
        guard let graph = makeGraph(for: level, shouldStop: shouldStop) else { return .undetermined }

        var initialPaint = Paint()
        initialPaint.insert(level.start.row * 16 + level.start.column)
        let initial = State(stop: 0, painted: initialPaint)
        var visited: Set<State> = [initial]
        var frontier = [initial]
        var depth = 0
        let shorterMoveLimit = run.moves - 1

        // Breadth-first search excludes every route with fewer moves. The run
        // itself supplies the matching upper bound when no such route exists.
        while !frontier.isEmpty && depth < shorterMoveLimit {
            var next: [State] = []
            for (index, state) in frontier.enumerated() {
                if index.isMultiple(of: 256), shouldStop() { return .undetermined }
                let movesRemaining = shorterMoveLimit - depth
                let unpainted = level.openCells.count - state.painted.count
                let coverageLowerBound = (unpainted + graph.maximumPaintPerMove - 1) / graph.maximumPaintPerMove
                guard coverageLowerBound <= movesRemaining else { continue }
                for edge in graph.edges[state.stop] {
                    let painted = state.painted.union(edge.painted)
                    if painted == graph.goal { return .notOptimal }
                    // Incomplete states at the last shorter depth cannot win.
                    guard depth + 1 < shorterMoveLimit else { continue }
                    let candidate = State(stop: edge.destination, painted: painted)
                    guard !visited.contains(candidate) else { continue }
                    guard visited.count < stateLimit else { return .undetermined }
                    visited.insert(candidate)
                    next.append(candidate)
                }
            }
            frontier = next
            depth += 1
        }
        return shouldStop() ? .undetermined : .optimal
    }

    private static func isSupported(_ level: MazeLevel) -> Bool {
        (1...16).contains(level.width) && (1...16).contains(level.height)
            && !level.openCells.isEmpty && level.openCells.count <= 256
            && level.openCells.contains(level.start)
            && level.openCells.allSatisfy {
                (0..<level.height).contains($0.row) && (0..<level.width).contains($0.column)
            }
    }

    private static func makeGraph(for level: MazeLevel, shouldStop: () -> Bool) -> Graph? {
        var goal = Paint()
        for cell in level.openCells { goal.insert(cell.row * 16 + cell.column) }

        var stops = [level.start]
        var stopIndices = [level.start: 0]
        var graph: [[Edge]] = []
        var maximumPaintPerMove = 1
        var graphIndex = 0
        while graphIndex < stops.count {
            guard !shouldStop() else { return nil }
            let slides = MazeSolver.slides(from: stops[graphIndex], in: level.openCells)
            let edges = slides.map { slide in
                let destination: Int
                if let index = stopIndices[slide.destination] {
                    destination = index
                } else {
                    destination = stops.count
                    stopIndices[slide.destination] = destination
                    stops.append(slide.destination)
                }
                var painted = Paint()
                for cell in slide.cells { painted.insert(cell.row * 16 + cell.column) }
                maximumPaintPerMove = max(maximumPaintPerMove, slide.cells.count)
                return Edge(destination: destination, painted: painted)
            }
            graph.append(edges)
            graphIndex += 1
        }
        return Graph(goal: goal, edges: graph, maximumPaintPerMove: maximumPaintPerMove)
    }

    private static func reducedGraph(_ graph: Graph, for level: MazeLevel, shouldStop: () -> Bool) -> Graph? {
        let cells = level.openCells.subtracting([level.start]).sorted()
        let edges = graph.edges.flatMap { $0 }
        var coveringEdges: [(cell: GridCell, edges: Set<Int>)] = []
        for cell in cells {
            guard !shouldStop() else { return nil }
            let cellIndex = cell.row * 16 + cell.column
            let coverage = Set(edges.indices.filter { edges[$0].painted.contains(cellIndex) })
            guard !coverage.isEmpty else { return nil }
            coveringEdges.append((cell, coverage))
        }
        coveringEdges.sort {
            $0.edges.count == $1.edges.count ? $0.cell < $1.cell : $0.edges.count < $1.edges.count
        }
        var necessary: [(cell: GridCell, edges: Set<Int>)] = []
        var goal = Paint()
        for coverage in coveringEdges {
            guard !shouldStop() else { return nil }
            // If every slide that paints a necessary tile also paints this tile,
            // completing the necessary tile already guarantees this one. Omitting
            // it merges histories that differ only in redundant partial coverage.
            guard !necessary.contains(where: { $0.edges.isSubset(of: coverage.edges) }) else { continue }
            necessary.append(coverage)
            goal.insert(coverage.cell.row * 16 + coverage.cell.column)
        }
        return Graph(goal: goal, edges: graph.edges.map { moves in
            moves.map { Edge(destination: $0.destination, painted: $0.painted.intersection(goal)) }
        }, maximumPaintPerMove: graph.maximumPaintPerMove)
    }

    private static func solutionIsShorter(than run: MazeRun) -> Bool {
        var position = run.level.start
        var painted: Set<GridCell> = [position]
        var moves = 0
        for direction in run.level.solution {
            let path = MazeSolver.path(from: position, direction: direction, in: run.level.openCells)
            guard let destination = path.last else { continue }
            position = destination
            painted.formUnion(path)
            moves += 1
            if painted == run.level.openCells { return moves < run.moves }
        }
        return false
    }
}
