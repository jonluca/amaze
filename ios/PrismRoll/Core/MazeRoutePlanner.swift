/// Generation-only route improvement. The live hint solver retains its stable tie order.
struct MazeRoutePlanner {
    private struct SearchState: Hashable {
        let stop: Int
        let painted: UInt64
    }

    private struct SearchNode {
        let state: SearchState
        let parent: Int
        let direction: MoveDirection?
    }

    static func route(openCells: Set<GridCell>, start: GridCell, exactStateLimit: Int = 0) -> [MoveDirection]? {
        var graph: [GridCell: [MazeSlide]] = [:]
        var pending = [start]
        while let cell = pending.popLast() {
            guard graph[cell] == nil else { continue }
            let slides = MazeSolver.slides(from: cell, in: openCells)
            graph[cell] = slides
            pending.append(contentsOf: slides.map(\.destination))
        }
        if exactStateLimit > 0, openCells.count < 64,
           let exact = shortestRoute(openCells: openCells, start: start, graph: graph, limit: exactStateLimit) {
            return exact
        }
        let orders: [[MoveDirection]] = [
            [.up, .down, .left, .right], [.right, .left, .down, .up],
            [.down, .right, .up, .left], [.left, .up, .right, .down]
        ]
        var best: [MoveDirection]?
        for order in orders {
            var position = start
            var painted: Set<GridCell> = [start]
            var result: [MoveDirection] = []
            while painted.count < openCells.count {
                var queue: [(cell: GridCell, route: [MoveDirection])] = [(position, [])]
                var visited: Set<GridCell> = [position]
                var found: [MoveDirection]?
                var index = 0
                while index < queue.count && found == nil {
                    let item = queue[index]
                    index += 1
                    for direction in order {
                        guard let slide = graph[item.cell]?.first(where: { $0.direction == direction }) else { continue }
                        let route = item.route + [direction]
                        if slide.cells.contains(where: { !painted.contains($0) }) {
                            found = route
                            break
                        }
                        if visited.insert(slide.destination).inserted { queue.append((slide.destination, route)) }
                    }
                }
                guard let found else { return nil }
                for direction in found {
                    guard let slide = graph[position]?.first(where: { $0.direction == direction }) else { return nil }
                    painted.formUnion(slide.cells)
                    position = slide.destination
                }
                result.append(contentsOf: found)
            }
            if best == nil || result.count < best!.count { best = result }
        }
        return best
    }

    private static func shortestRoute(
        openCells: Set<GridCell>, start: GridCell, graph: [GridCell: [MazeSlide]], limit: Int
    ) -> [MoveDirection]? {
        let cells = openCells.sorted()
        let bits = Dictionary(uniqueKeysWithValues: cells.enumerated().map { ($1, UInt64(1) << $0) })
        let stops = graph.keys.sorted()
        let indices = Dictionary(uniqueKeysWithValues: stops.enumerated().map { ($1, $0) })
        let edges = stops.map { stop in
            graph[stop, default: []].map { slide in
                (destination: indices[slide.destination]!,
                 mask: slide.cells.reduce(UInt64(0)) { $0 | bits[$1]! }, direction: slide.direction)
            }
        }
        let goal = (UInt64(1) << cells.count) - 1
        let initial = SearchState(stop: indices[start]!, painted: bits[start]!)
        var nodes = [SearchNode(state: initial, parent: -1, direction: nil)]
        var visited: Set<SearchState> = [initial]
        var index = 0
        while index < nodes.count {
            let node = nodes[index]
            for edge in edges[node.state.stop] {
                let state = SearchState(stop: edge.destination, painted: node.state.painted | edge.mask)
                guard visited.insert(state).inserted else { continue }
                if state.painted == goal {
                    var route = [edge.direction]
                    var previous = index
                    while let direction = nodes[previous].direction {
                        route.append(direction)
                        previous = nodes[previous].parent
                    }
                    return route.reversed()
                }
                guard nodes.count < limit else { return nil }
                nodes.append(SearchNode(state: state, parent: index, direction: edge.direction))
            }
            index += 1
        }
        return nil
    }
}
