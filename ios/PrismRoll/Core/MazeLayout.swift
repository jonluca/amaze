struct MazeLayout: Sendable {
    let cells: Set<GridCell>
    let start: GridCell
    let route: [MoveDirection]
    let topology: MazeTopology

    static func candidate(cells: Set<GridCell>, difficulty: MazeDifficulty) -> MazeLayout? {
        guard let region = MazeSolver.playableRegion(in: cells),
              region.cells.count >= difficulty.size * difficulty.size / 2,
              region.cells.count < difficulty.size * difficulty.size,
              MazeSolver.isFullyPlayable(openCells: region.cells, start: region.start) else { return nil }
        let topology = MazeTopology(openCells: region.cells, start: region.start)
        guard topology.minimumSegments >= difficulty.minimumSegments,
              topology.decisionStops >= difficulty.minimumDecisions,
              topology.deadEnds >= 2,
              topology.minimumRevisitedSteps >= difficulty.minimumReturns,
              let route = MazeRoutePlanner.route(openCells: region.cells, start: region.start,
                  exactStateLimit: difficulty.size <= 6 ? 10_000 : 0) else { return nil }
        let layout = MazeLayout(cells: region.cells, start: region.start, route: route, topology: topology)
        return difficulty.accepts(layout) ? layout : nil
    }
}
