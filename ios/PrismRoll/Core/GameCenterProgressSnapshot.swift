/// Monotonic gameplay evidence suitable for Game Center achievements and scores.
struct GameCenterProgressSnapshot: Codable, Equatable, Sendable {
    let classicCompleted: Int
    let perfectCompleted: Int
    let limitedCompleted: Int
    let rushCompleted: Int
    let dailyCompleted: Int
    let mazeCoinsCollected: Int

    static let empty = Self()

    init(
        classicCompleted: Int = 0, perfectCompleted: Int = 0, limitedCompleted: Int = 0,
        rushCompleted: Int = 0, dailyCompleted: Int = 0, mazeCoinsCollected: Int = 0
    ) {
        self.classicCompleted = max(0, classicCompleted)
        self.perfectCompleted = max(0, perfectCompleted)
        self.limitedCompleted = max(0, limitedCompleted)
        self.rushCompleted = max(0, rushCompleted)
        self.dailyCompleted = max(0, dailyCompleted)
        self.mazeCoinsCollected = max(0, mazeCoinsCollected)
    }

    init(progress: ProgressData) {
        let classic = progress.completedLevelNumbers(in: .endless)
        let limited = progress.completedLevelNumbers(in: .challenge)
        let rush = progress.completedLevelNumbers(in: .timed)
        let perfect = [(GameMode.endless, classic), (.challenge, limited), (.timed, rush)]
            .reduce(0) { count, entry in
                count + entry.1.filter { progress.hasOptimalCompletion(number: $0, mode: entry.0) }.count
            }
        self.init(
            classicCompleted: classic.count, perfectCompleted: perfect,
            limitedCompleted: limited.count, rushCompleted: rush.count,
            dailyCompleted: progress.completedDailyChallengeCount,
            mazeCoinsCollected: progress.collectedMazeCoinCount
        )
    }

    /// Stable metric keys let the reporting ledger track account-specific earned deltas.
    var counters: [String: Int] {
        [
            "classicCompleted": classicCompleted, "perfectCompleted": perfectCompleted,
            "limitedCompleted": limitedCompleted, "rushCompleted": rushCompleted,
            "dailyCompleted": dailyCompleted, "mazeCoinsCollected": mazeCoinsCollected
        ]
    }

    init(counters: [String: Int]) {
        self.init(
            classicCompleted: counters["classicCompleted", default: 0],
            perfectCompleted: counters["perfectCompleted", default: 0],
            limitedCompleted: counters["limitedCompleted", default: 0],
            rushCompleted: counters["rushCompleted", default: 0],
            dailyCompleted: counters["dailyCompleted", default: 0],
            mazeCoinsCollected: counters["mazeCoinsCollected", default: 0]
        )
    }
}
