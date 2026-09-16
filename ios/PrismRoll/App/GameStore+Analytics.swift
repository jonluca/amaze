extension GameStore {
    /// Events describe accepted play. Saved boards produce a resume event on their
    /// next valid move; opening a screen alone does not count as starting a level.
    var gameplayAnalyticsParameters: [String: Any] {
        var parameters: [String: Any] = [
            "game_mode": run.level.mode.rawValue,
            "level": run.level.number,
            "play_context": isDuel ? "duel" : isDaily ? "daily" : "solo",
            "moves": run.moves
        ]
        if isTimeRush { parameters["stage_index"] = timeRushMazeNumber }
        return parameters
    }

    func recordGameplayEvent(_ name: String, parameters: [String: Any] = [:]) {
        analytics.record(name, parameters: gameplayAnalyticsParameters.merging(parameters) { _, value in value })
    }

    func recordBoardInteraction(previousMoves: Int) {
        guard !analyticsBoardHasMoved else { return }
        analyticsBoardHasMoved = true
        if previousMoves > 0 {
            recordGameplayEvent("level_resumed")
        } else if isTimeRush {
            recordGameplayEvent("time_rush_maze_started")
            if timeRushMazeNumber == 1 { recordGameplayEvent("level_start") }
        } else {
            recordGameplayEvent("level_start")
        }
    }

    func recordCurrencyEarned(_ amount: Int, source: String, parameters: [String: Any] = [:]) {
        guard amount > 0 else { return }
        analytics.record("earn_virtual_currency", parameters: parameters.merging([
            "virtual_currency_name": "coins", "value": amount, "source": source
        ]) { _, value in value })
    }
}
