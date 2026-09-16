@preconcurrency import GameKit
import Foundation

extension GameCenterService {
    func beginSynchronization() {
        guard !isSyncing else { return }
        baselineAttempted = false
        failedReportResources.removeAll()
        synchronize()
    }

    func synchronize() {
        guard runtime == .live, authenticated, !isSyncing,
              let playerID = activePlayerID, ledger.accounts[playerID] != nil,
              sessionIsCurrent(sessionID, playerID: playerID) else { return }
        let session = sessionID
        if !baselineLoaded && !baselineAttempted {
            isSyncing = true
            baselineAttempted = true
            GKAchievement.loadAchievements { [weak self] achievements, error in
                DispatchQueue.main.async {
                    guard let self, self.sessionIsCurrent(session, playerID: playerID) else { return }
                    self.isSyncing = false
                    guard error == nil else {
                        // A failed achievement fetch must not block leaderboard
                        // uploads. Retry the baseline on the next external trigger.
                        self.synchronize()
                        return
                    }
                    let percentages = Dictionary((achievements ?? []).map { ($0.identifier, $0.percentComplete) },
                        uniquingKeysWith: max)
                    self.ledger.mergeRemoteAchievements(percentages, playerID: playerID)
                    self.persistence.save(self.ledger)
                    self.baselineLoaded = true
                    self.synchronize()
                }
            }
            return
        }
        guard let operation = ledger.nextOperation(playerID: playerID, allowBanners: baselineLoaded,
            includeAchievements: baselineLoaded, excludingResources: failedReportResources) else {
            if ledger.nextOperation(playerID: playerID, allowBanners: false) != nil {
                reportingFailed()
            } else {
                status = "Achievements and scores are up to date."
            }
            return
        }
        isSyncing = true
        let completion: @Sendable (Error?) -> Void = { [weak self] error in
            DispatchQueue.main.async {
                guard let self, self.sessionIsCurrent(session, playerID: playerID) else { return }
                self.isSyncing = false
                guard error == nil else {
                    self.failedReportResources.insert(operation.resourceKey)
                    self.synchronize()
                    return
                }
                self.ledger.acknowledge(operation, playerID: playerID)
                self.persistence.save(self.ledger)
                self.synchronize()
            }
        }
        switch operation {
        case let .achievement(id, percent, showBanner):
            let achievement = GKAchievement(identifier: id)
            achievement.percentComplete = percent
            achievement.showsCompletionBanner = showBanner
            GKAchievement.report([achievement], withCompletionHandler: completion)
        case let .leaderboard(id, score):
            GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                leaderboardIDs: [id], completionHandler: completion)
        }
    }

    func reportingFailed() {
        status = "Your progress is saved. Game Center will sync when you reconnect."
    }
}
