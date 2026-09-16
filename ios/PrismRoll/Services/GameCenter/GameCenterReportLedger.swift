import Foundation

/// A durable high-water queue. Taking an operation never removes it: only an
/// acknowledgement does, and it acknowledges exactly the value that was sent.
struct GameCenterReportLedger: Codable, Equatable {
    private(set) var accounts: [String: GameCenterAccountProgress] = [:]
    private(set) var lastPlayerID: String?
    private(set) var lastObservedSnapshot: GameCenterProgressSnapshot?

    mutating func activate(playerID: String, snapshot: GameCenterProgressSnapshot) {
        if accounts.isEmpty {
            // The first player on this installation adopts existing solo progress.
            accounts[playerID] = GameCenterAccountProgress(progress: snapshot)
        } else if accounts[playerID] == nil {
            accounts[playerID] = GameCenterAccountProgress()
        } else if lastPlayerID == playerID {
            observe(snapshot, playerID: playerID, allowBanners: false)
            return
        }
        // A different player starts earning at today's local baseline. Returning
        // to an old account does not copy progress earned under the other one.
        lastPlayerID = playerID
        lastObservedSnapshot = snapshot
    }

    mutating func observe(_ snapshot: GameCenterProgressSnapshot, playerID: String, allowBanners: Bool) {
        guard lastPlayerID == playerID, var account = accounts[playerID],
              let previous = lastObservedSnapshot else { return }
        var counters = account.progress.counters
        var observedHighWater = previous.counters
        for (key, value) in snapshot.counters {
            let previousValue = max(0, observedHighWater[key] ?? 0)
            let currentValue = max(0, value)
            let increment = max(0, currentValue - previousValue)
            let total = (counters[key] ?? 0).addingReportingOverflow(increment)
            counters[key] = total.overflow ? Int.max : total.partialValue
            observedHighWater[key] = max(previousValue, currentValue)
        }
        let updated = GameCenterProgressSnapshot(counters: counters)
        if allowBanners {
            for achievement in GameCenterAchievement.allCases
            where achievement.percentComplete(in: account.progress) < 100
                && achievement.percentComplete(in: updated) >= 100
                && (account.reportedAchievements[achievement.id] ?? 0) < 100 {
                account.bannerEligibleAchievements.insert(achievement.id)
            }
        }
        account.progress = updated
        accounts[playerID] = account
        // A restored older save or replaced board proof can reduce a count.
        // Recovering that old count must not earn the same progress twice.
        lastObservedSnapshot = GameCenterProgressSnapshot(counters: observedHighWater)
    }

    mutating func mergeRemoteAchievements(_ percentages: [String: Double], playerID: String) {
        guard var account = accounts[playerID] else { return }
        for (id, percent) in percentages where percent.isFinite {
            let value = min(100, max(0, percent))
            account.reportedAchievements[id] = max(account.reportedAchievements[id] ?? 0, value)
            if value >= 100 { account.bannerEligibleAchievements.remove(id) }
        }
        accounts[playerID] = account
    }

    func nextOperation(playerID: String, allowBanners: Bool, includeAchievements: Bool = true,
                       excludingResources: Set<String> = []) -> GameCenterReportOperation? {
        guard let account = accounts[playerID] else { return nil }
        for achievement in GameCenterAchievement.allCases where includeAchievements {
            let percent = achievement.percentComplete(in: account.progress)
            if percent > (account.reportedAchievements[achievement.id] ?? 0) {
                let operation = GameCenterReportOperation.achievement(id: achievement.id, percent: percent,
                    showBanner: allowBanners && account.bannerEligibleAchievements.contains(achievement.id))
                if !excludingResources.contains(operation.resourceKey) { return operation }
            }
        }
        for leaderboard in GameCenterLeaderboard.allCases {
            let score = leaderboard.score(in: account.progress)
            if score > (account.reportedScores[leaderboard.id] ?? 0) {
                let operation = GameCenterReportOperation.leaderboard(id: leaderboard.id, score: score)
                if !excludingResources.contains(operation.resourceKey) { return operation }
            }
        }
        return nil
    }

    mutating func acknowledge(_ operation: GameCenterReportOperation, playerID: String) {
        guard var account = accounts[playerID] else { return }
        switch operation {
        case let .achievement(id, percent, _):
            account.reportedAchievements[id] = max(account.reportedAchievements[id] ?? 0, percent)
            if percent >= 100 { account.bannerEligibleAchievements.remove(id) }
        case let .leaderboard(id, score):
            account.reportedScores[id] = max(account.reportedScores[id] ?? 0, score)
        }
        accounts[playerID] = account
    }
}
