struct MazeDifficulty: Sendable {
    let size: Int
    let minimumMoves: Int
    let maximumMoves: Int
    let targetMoves: Int
    let minimumSegments: Int
    let minimumDecisions: Int
    let minimumReturns: Int
    let minimumOpenCells: Int
    let minimumDeadEnds: Int

    init(number: Int, mode: GameMode) {
        let number = max(1, number)
        let classicSize: Int
        switch number {
        case 1: classicSize = 5
        case 2...3: classicSize = 6
        case 4...6: classicSize = 7
        case 7...9: classicSize = 8
        case 10...14: classicSize = 9
        case 15...21: classicSize = 10
        case 22...29: classicSize = 11
        case 30...41: classicSize = 12
        case 42...55: classicSize = 13
        case 56...74: classicSize = 14
        case 75...99: classicSize = 15
        default: classicSize = 16
        }
        size = min(16, classicSize + (mode == .endless ? 0 : 1))
        // Columns are route minimum/maximum/target, segment lower bound,
        // decisions, unavoidable repeated corridor steps, and dead ends.
        let values: (Int, Int, Int, Int, Int, Int, Int)
        switch size {
        case 5: values = (7, 8, 8, 5, 2, 0, 2)
        case 6: values = (12, 22, 18, 8, 4, 1, 3)
        case 7: values = (18, 30, 24, 10, 6, 2, 3)
        case 8: values = (24, 38, 31, 13, 8, 2, 3)
        case 9: values = (30, 46, 39, 16, 11, 3, 4)
        case 10: values = (38, 56, 47, 19, 14, 4, 4)
        case 11: values = (46, 66, 56, 22, 17, 5, 4)
        case 12: values = (55, 78, 66, 25, 20, 6, 5)
        case 13: values = (64, 90, 77, 28, 24, 6, 5)
        case 14: values = (73, 104, 88, 31, 28, 7, 6)
        case 15: values = (82, 118, 99, 35, 32, 8, 6)
        default: values = (90, 140, 112, 38, 36, 9, 7)
        }
        let maturity = size == 16
            ? min(2, (number >= 200 ? 2 : number >= 150 ? 1 : 0)
                  + (mode != .endless && number >= 100 ? 1 : 0)) : 0
        minimumMoves = values.0 + maturity * 6
        maximumMoves = values.1
        targetMoves = values.2 + maturity * 6
        minimumSegments = values.3 + maturity * 2
        minimumDecisions = values.4 + maturity * 3
        minimumReturns = values.5 + maturity * 2
        minimumDeadEnds = values.6 + maturity
        minimumOpenCells = (size * size * (50 + maturity * 3) + 99) / 100
    }

    func accepts(_ layout: MazeLayout) -> Bool {
        (minimumMoves...maximumMoves).contains(layout.route.count)
            && layout.cells.count >= minimumOpenCells
            && layout.cells.count < size * size
            && layout.cells.contains { $0.row == 0 }
            && layout.cells.contains { $0.column == 0 }
            && layout.cells.contains { $0.row == size - 1 }
            && layout.cells.contains { $0.column == size - 1 }
            && layout.topology.minimumSegments >= minimumSegments
            && layout.topology.decisionStops >= minimumDecisions
            && layout.topology.deadEnds >= minimumDeadEnds
            && layout.topology.minimumRevisitedSteps >= minimumReturns
    }

    func score(_ layout: MazeLayout) -> Int {
        layout.topology.minimumSegments * 16 + layout.topology.decisionStops * 3
            + min(layout.topology.minimumRevisitedSteps, 10) * 4
            - abs(layout.route.count - targetMoves) * 2
    }
}
