/// A slide graph operates on stopping points, rather than walking between tiles.
struct MazeSolver {
    // This tie order is part of numbered level identity. Keep it independent of
    // the declaration order of MoveDirection cases used by UI and input code.
    private static let directionOrder: [MoveDirection] = [.up, .down, .left, .right]

    static func slides(from position: GridCell, in openCells: Set<GridCell>) -> [MazeSlide] {
        directionOrder.compactMap { direction in
            let cells = path(from: position, direction: direction, in: openCells)
            return cells.isEmpty ? nil : MazeSlide(direction: direction, cells: cells)
        }
    }

    static func path(
        from position: GridCell,
        direction: MoveDirection,
        in openCells: Set<GridCell>
    ) -> [GridCell] {
        var cursor = position.neighbor(in: direction)
        var cells: [GridCell] = []
        while openCells.contains(cursor) {
            cells.append(cursor)
            cursor = cursor.neighbor(in: direction)
        }
        return cells
    }

    /// Retain the largest mutually reachable region and the tiles its slides paint.
    /// Random connected walking mazes alone are insufficient: sliding can miss tiles.
    static func playableRegion(in openCells: Set<GridCell>) -> (cells: Set<GridCell>, start: GridCell)? {
        guard !openCells.isEmpty else { return nil }
        let ordered = openCells.sorted()
        let graph = Dictionary(uniqueKeysWithValues: ordered.map { ($0, slides(from: $0, in: openCells)) })
        var visited: Set<GridCell> = []
        var finishOrder: [GridCell] = []

        func visit(_ cell: GridCell) {
            guard visited.insert(cell).inserted else { return }
            for slide in graph[cell, default: []] { visit(slide.destination) }
            finishOrder.append(cell)
        }
        for cell in ordered { visit(cell) }

        var reverse: [GridCell: [GridCell]] = [:]
        for cell in ordered {
            for slide in graph[cell, default: []] {
                reverse[slide.destination, default: []].append(cell)
            }
        }

        visited.removeAll(keepingCapacity: true)
        var bestCells: Set<GridCell> = []
        var bestStart = ordered[0]

        func collect(_ cell: GridCell, into component: inout Set<GridCell>) {
            guard visited.insert(cell).inserted else { return }
            component.insert(cell)
            for previous in reverse[cell, default: []] { collect(previous, into: &component) }
        }
        for cell in finishOrder.reversed() where !visited.contains(cell) {
            var component: Set<GridCell> = []
            collect(cell, into: &component)
            var covered = component
            for stop in component {
                for slide in graph[stop, default: []] where component.contains(slide.destination) {
                    covered.formUnion(slide.cells)
                }
            }
            if covered.count > bestCells.count {
                bestCells = covered
                bestStart = component.min() ?? cell
            }
        }
        return (bestCells, bestStart)
    }

    /// Every reachable stop must return to start, and their slides must cover the board.
    /// This also rules out player-created dead ends after deviating from the solution.
    static func isFullyPlayable(openCells: Set<GridCell>, start: GridCell) -> Bool {
        guard openCells.contains(start), openCells.count > 1 else { return false }
        var graph: [GridCell: [MazeSlide]] = [:]
        var pending = [start]
        var covered: Set<GridCell> = [start]
        while let stop = pending.popLast() {
            guard graph[stop] == nil else { continue }
            let moves = slides(from: stop, in: openCells)
            graph[stop] = moves
            for slide in moves {
                covered.formUnion(slide.cells)
                if graph[slide.destination] == nil { pending.append(slide.destination) }
            }
        }
        guard covered == openCells else { return false }
        var reverse: [GridCell: [GridCell]] = [:]
        for (stop, moves) in graph {
            for slide in moves { reverse[slide.destination, default: []].append(stop) }
        }
        var canReturn: Set<GridCell> = []
        pending = [start]
        while let stop = pending.popLast() {
            guard canReturn.insert(stop).inserted else { continue }
            pending.append(contentsOf: reverse[stop, default: []])
        }
        return canReturn.count == graph.count
    }

    /// A deterministic covering route; each BFS segment reaches at least one new tile.
    /// It is feasible, but it does not claim to be the globally shortest solution.
    static func coveringRoute(
        openCells: Set<GridCell>,
        position: GridCell,
        painted: Set<GridCell>
    ) -> [MoveDirection]? {
        guard openCells.contains(position), painted.isSubset(of: openCells) else { return nil }
        var cursor = position
        var covered = painted.union([position])
        var solution: [MoveDirection] = []
        var cache: [GridCell: [MazeSlide]] = [:]
        while covered.count < openCells.count {
            var queue: [(cell: GridCell, route: [MoveDirection])] = [(cursor, [])]
            var visited: Set<GridCell> = [cursor]
            var index = 0
            var found: [MoveDirection]?
            while index < queue.count && found == nil {
                let item = queue[index]
                index += 1
                let moves = cache[item.cell] ?? slides(from: item.cell, in: openCells)
                cache[item.cell] = moves
                for slide in moves {
                    let route = item.route + [slide.direction]
                    if slide.cells.contains(where: { !covered.contains($0) }) {
                        found = route
                        break
                    }
                    if visited.insert(slide.destination).inserted {
                        queue.append((slide.destination, route))
                    }
                }
            }
            guard let route = found else { return nil }
            for direction in route {
                let cells = path(from: cursor, direction: direction, in: openCells)
                guard let destination = cells.last else { return nil }
                covered.formUnion(cells)
                cursor = destination
            }
            solution.append(contentsOf: route)
        }
        return solution
    }
}
