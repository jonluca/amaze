struct MazeDifficulty: Sendable {
    let size: Int
    let minimumMoves: Int
    let maximumMoves: Int
    let targetMoves: Int
    let minimumSegments: Int
    let minimumDecisions: Int
    let minimumReturns: Int

    init(number: Int, mode: GameMode) {
        let values: (Int, Int, Int, Int, Int, Int, Int)
        if mode == .endless {
            switch number {
            case ...1: values = (5, 7, 8, 8, 5, 2, 0)
            case 2...3: values = (6, 10, 14, 12, 7, 3, 1)
            case 4...5: values = (6, 12, 16, 14, 8, 4, 1)
            case 6...10: values = (7, 16, 24, 20, 9, 5, 1)
            case 11...20: values = (8, 20, 28, 25, 11, 7, 1)
            case 21...79: values = (9, 25, 38, 32, 13, 9, 1)
            default: values = (10, 30, 45, 39, 16, 11, 1)
            }
        } else {
            switch number {
            case ...1: values = (6, 12, 17, 15, 8, 4, 1)
            case 2...5: values = (7, 16, 24, 20, 9, 6, 1)
            case 6...20: values = (8, 22, 32, 27, 12, 8, 1)
            case 21...79: values = (9, 28, 40, 35, 14, 10, 1)
            default: values = (10, 33, 45, 40, 16, 12, 1)
            }
        }
        (size, minimumMoves, maximumMoves, targetMoves, minimumSegments, minimumDecisions, minimumReturns) = values
    }

    func accepts(_ layout: MazeLayout) -> Bool {
        (minimumMoves...maximumMoves).contains(layout.route.count)
            && layout.topology.minimumSegments >= minimumSegments
            && layout.topology.decisionStops >= minimumDecisions
            && layout.topology.deadEnds >= 2
            && layout.topology.minimumRevisitedSteps >= minimumReturns
    }

    func score(_ layout: MazeLayout) -> Int {
        layout.topology.minimumSegments * 16 + layout.topology.decisionStops * 3
            + min(layout.topology.minimumRevisitedSteps, 10) * 4
            - abs(layout.route.count - targetMoves) * 2
    }
}
