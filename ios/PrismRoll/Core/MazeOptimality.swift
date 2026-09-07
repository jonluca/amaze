/// Proves whether a completed run uses the fewest effective swipes.
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

    static func verify(
        _ run: MazeRun,
        stateLimit: Int = 100_000,
        timeLimit: Duration = .milliseconds(200),
        isCancelled: @Sendable () -> Bool = { false }
    ) -> Result {
        guard run.isComplete else { return .incomplete }
        let level = run.level
        guard (1...16).contains(level.width), (1...16).contains(level.height),
              !level.openCells.isEmpty, level.openCells.count <= 256,
              level.openCells.contains(level.start), run.moves >= 0,
              level.openCells.allSatisfy({
                  (0..<level.height).contains($0.row) && (0..<level.width).contains($0.column)
              }) else { return .undetermined }
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

        let cells = level.openCells.sorted()
        var goal = Paint()
        for cell in cells { goal.insert(cell.row * 16 + cell.column) }

        var stops = [level.start]
        var stopIndices = [level.start: 0]
        var graph: [[Edge]] = []
        var maximumPaintPerMove = 1
        var graphIndex = 0
        while graphIndex < stops.count {
            guard !shouldStop() else { return .undetermined }
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
                let unpainted = cells.count - state.painted.count
                let coverageLowerBound = (unpainted + maximumPaintPerMove - 1) / maximumPaintPerMove
                guard coverageLowerBound <= movesRemaining else { continue }
                for edge in graph[state.stop] {
                    let painted = state.painted.union(edge.painted)
                    if painted == goal { return .notOptimal }
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
