struct MazeLayout: Sendable {
    let cells: Set<GridCell>
    let start: GridCell
    let route: [MoveDirection]
    let topology: MazeTopology

    static func candidate(cells: Set<GridCell>, difficulty: MazeDifficulty, preferredStart: GridCell? = nil) -> MazeLayout? {
        guard let region = MazeSolver.playableRegion(in: cells),
              region.cells.count >= difficulty.minimumOpenCells,
              region.cells.count < difficulty.size * difficulty.size,
              region.cells.contains(where: { $0.row == 0 }),
              region.cells.contains(where: { $0.column == 0 }),
              region.cells.contains(where: { $0.row == difficulty.size - 1 }),
              region.cells.contains(where: { $0.column == difficulty.size - 1 }) else { return nil }
        let start = preferredStart ?? region.start
        guard region.cells.contains(start),
              MazeSolver.isFullyPlayable(openCells: region.cells, start: start) else { return nil }
        let topology = MazeTopology(openCells: region.cells, start: start)
        guard topology.minimumSegments >= difficulty.minimumSegments,
              topology.decisionStops >= difficulty.minimumDecisions,
              topology.deadEnds >= difficulty.minimumDeadEnds,
              topology.minimumRevisitedSteps >= difficulty.minimumReturns,
              let route = MazeRoutePlanner.route(openCells: region.cells, start: start,
                  exactStateLimit: difficulty.size <= 6 ? 10_000 : 0) else { return nil }
        let layout = MazeLayout(cells: region.cells, start: start, route: route, topology: topology)
        return difficulty.accepts(layout) ? layout : nil
    }
}
