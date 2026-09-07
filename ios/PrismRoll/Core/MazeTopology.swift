/// Structural constraints independent of a particular greedy covering route.
struct MazeTopology: Equatable, Sendable {
    let decisionStops: Int
    let deadEnds: Int
    let stoppingCells: Int
    let minimumSegments: Int
    let minimumRevisitedSteps: Int

    init(openCells: Set<GridCell>, start: GridCell) {
        var graph: [GridCell: [MazeSlide]] = [:]
        var pending = [start]
        while let cell = pending.popLast() {
            guard graph[cell] == nil else { continue }
            let slides = MazeSolver.slides(from: cell, in: openCells)
            graph[cell] = slides
            pending.append(contentsOf: slides.map(\.destination))
        }
        decisionStops = graph.values.filter { $0.count >= 3 }.count
        deadEnds = graph.values.filter { $0.count == 1 }.count
        stoppingCells = graph.count
        minimumSegments = Self.segmentCoverLowerBound(openCells: openCells, start: start)
        var returns: [Int] = []
        for (cell, slides) in graph where slides.count == 1 && cell != start {
            let direction = slides[0].direction
            var cursor = cell
            var distance = 0
            while openCells.contains(cursor.neighbor(in: direction)) {
                cursor = cursor.neighbor(in: direction)
                distance += 1
                if cursor == start { break }
                let neighbors = MoveDirection.allCases.filter { openCells.contains(cursor.neighbor(in: $0)) }
                if neighbors.count != 2 { break }
            }
            returns.append(distance)
        }
        // Every visited leaf except the final one requires leaving along its
        // already-painted corridor. Exclude a starting leaf and the longest
        // possible final leaf to keep this a conservative structural bound.
        minimumRevisitedSteps = returns.reduce(0, +) - (returns.max() ?? 0)
    }

    /// Each move paints part of one maximal horizontal or vertical segment.
    /// Tiles form edges between those two segment sets. By Konig's theorem,
    /// maximum matching is the minimum segment cover, hence a valid swipe lower
    /// bound. It ignores travel and segment accessibility, so never claims optimality.
    private static func segmentCoverLowerBound(openCells: Set<GridCell>, start: GridCell) -> Int {
        var horizontal: [GridCell: Int] = [:]
        var vertical: [GridCell: Int] = [:]
        var horizontalCount = 0
        var verticalCount = 0
        for cell in openCells.sorted() {
            if !openCells.contains(cell.neighbor(in: .left)) {
                var cursor = cell
                while openCells.contains(cursor) {
                    horizontal[cursor] = horizontalCount
                    cursor = cursor.neighbor(in: .right)
                }
                horizontalCount += 1
            }
            if !openCells.contains(cell.neighbor(in: .up)) {
                var cursor = cell
                while openCells.contains(cursor) {
                    vertical[cursor] = verticalCount
                    cursor = cursor.neighbor(in: .down)
                }
                verticalCount += 1
            }
        }
        var edges = Array(repeating: [Int](), count: horizontalCount)
        for cell in openCells.sorted() where cell != start {
            edges[horizontal[cell]!].append(vertical[cell]!)
        }
        var matches = Array<Int?>(repeating: nil, count: verticalCount)
        var count = 0
        func augment(_ segment: Int, visited: inout Set<Int>) -> Bool {
            for other in edges[segment] where visited.insert(other).inserted {
                let previous = matches[other]
                if previous == nil || augment(previous!, visited: &visited) {
                    matches[other] = segment
                    return true
                }
            }
            return false
        }
        for segment in edges.indices {
            var visited: Set<Int> = []
            if augment(segment, visited: &visited) { count += 1 }
        }
        return count
    }
}
