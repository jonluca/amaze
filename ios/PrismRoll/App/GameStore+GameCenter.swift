extension GameStore {
    /// An explicit Games app launch resumes a saved mode and gives a failed
    /// Time Rush round a fresh start. Existing solo and daily saves stay separate.
    func openGameCenterActivity(_ destination: GameCenterActivityDestination) {
        switch destination {
        case .classic:
            switchMode(.endless)
        case .timeRush:
            switchMode(.timed)
            if isFailed { replay() }
        case .daily:
            openDaily(replayCompleted: true)
        }
    }
}
