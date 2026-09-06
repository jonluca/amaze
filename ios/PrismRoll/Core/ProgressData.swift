import Foundation

struct ProgressData: Codable, Equatable, Sendable {
    var points = 0
    var endlessLevel = 1
    var challengeLevel = 1
    var timedLevel = 1
    var ownedSkinIDs: [String] = ["coral"]
    var selectedSkinID = "coral"
    var hapticsEnabled = true
    var soundEnabled = true
    private(set) var completedLevels = 0
    private(set) var claimedMilestoneIDs: Set<String> = []
    private var rewardedLevelKeys: Set<String> = []
    private var bonusLevelKeys: Set<String> = []
    private var collectedCoinKeys: Set<String> = []
    private var completedDailyChallengeIDs: Set<String> = []
    private var dailyLogin = DailyStreak()
    private var dailyChallenges = DailyStreak()

    private enum CodingKeys: String, CodingKey {
        case points, endlessLevel, challengeLevel, timedLevel, ownedSkinIDs, selectedSkinID
        case hapticsEnabled, soundEnabled, completedLevels, claimedMilestoneIDs
        case rewardedLevelKeys, bonusLevelKeys, collectedCoinKeys, completedDailyChallengeIDs
        case dailyLogin, dailyChallenges
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        points = try values.decodeIfPresent(Int.self, forKey: .points) ?? 0
        endlessLevel = try values.decodeIfPresent(Int.self, forKey: .endlessLevel) ?? 1
        challengeLevel = try values.decodeIfPresent(Int.self, forKey: .challengeLevel) ?? 1
        timedLevel = try values.decodeIfPresent(Int.self, forKey: .timedLevel) ?? 1
        ownedSkinIDs = try values.decodeIfPresent([String].self, forKey: .ownedSkinIDs) ?? ["coral"]
        selectedSkinID = try values.decodeIfPresent(String.self, forKey: .selectedSkinID) ?? "coral"
        hapticsEnabled = try values.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        soundEnabled = try values.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        rewardedLevelKeys = try values.decodeIfPresent(Set<String>.self, forKey: .rewardedLevelKeys) ?? []
        bonusLevelKeys = try values.decodeIfPresent(Set<String>.self, forKey: .bonusLevelKeys) ?? []
        completedLevels = try values.decodeIfPresent(Int.self, forKey: .completedLevels) ?? rewardedLevelKeys.count
        claimedMilestoneIDs = try values.decodeIfPresent(Set<String>.self, forKey: .claimedMilestoneIDs) ?? []
        collectedCoinKeys = try values.decodeIfPresent(Set<String>.self, forKey: .collectedCoinKeys) ?? []
        completedDailyChallengeIDs = try values.decodeIfPresent(Set<String>.self, forKey: .completedDailyChallengeIDs) ?? []
        dailyLogin = try values.decodeIfPresent(DailyStreak.self, forKey: .dailyLogin) ?? DailyStreak()
        dailyChallenges = try values.decodeIfPresent(DailyStreak.self, forKey: .dailyChallenges) ?? DailyStreak()
    }

    var dailyStreak: Int { dailyLogin.count }
    var lastDailyRewardDate: Date? { dailyLogin.lastClaimedAt }
    var dailyChallengeStreak: Int { dailyChallenges.count }

    func hasCompleted(_ level: MazeLevel) -> Bool {
        rewardedLevelKeys.contains(completionKey(for: level))
    }

    func hasClaimedAdBonus(level: MazeLevel) -> Bool {
        bonusLevelKeys.contains(completionKey(for: level))
    }

    /// The caller awards only a completed run. The ledger survives retries and relaunches.
    @discardableResult
    mutating func completeLevel(_ level: MazeLevel) -> Int {
        let key = completionKey(for: level)
        guard rewardedLevelKeys.insert(key).inserted else { return 0 }
        points += 50
        completedLevels += 1
        let nextLevel = level.number == Int.max ? Int.max : level.number + 1
        switch level.mode {
        case .endless: endlessLevel = max(endlessLevel, nextLevel)
        case .challenge: challengeLevel = max(challengeLevel, nextLevel)
        case .timed: timedLevel = max(timedLevel, nextLevel)
        }
        return 50
    }

    func completedLevelCount(in mode: GameMode) -> Int {
        rewardedLevelKeys.lazy.filter { $0.hasPrefix("\(mode.rawValue):") }.count
    }

    /// Credit a coin the first time that tile is painted, even if the run is still in progress.
    @discardableResult
    mutating func awardCollectedCoins(for run: MazeRun) -> Int {
        let prefix = completionKey(for: run.level)
        var award = 0
        for cell in run.collectedCoinCells {
            let key = "\(prefix):\(cell.row),\(cell.column)"
            if collectedCoinKeys.insert(key).inserted { award += MazeLevel.coinValue }
        }
        points += award
        return award
    }

    func dailyCurrentStreak(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        dailyLogin.currentCount(at: date, calendar: calendar)
    }

    func canClaimDailyReward(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        dailyLogin.nextCount(at: date, calendar: calendar) != nil
    }

    func dailyRewardAmount(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let streak = dailyLogin.nextCount(at: date, calendar: calendar) else { return 0 }
        return 25 + 5 * min(streak - 1, 6)
    }

    @discardableResult
    mutating func claimDailyReward(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let streak = dailyLogin.claim(at: date, calendar: calendar) else { return 0 }
        let award = 25 + 5 * min(streak - 1, 6)
        points += award
        return award
    }

    func dailyChallengeCurrentStreak(at date: Date = Date(), calendar: Calendar = .current) -> Int {
        dailyChallenges.currentCount(at: date, calendar: calendar)
    }

    func hasCompletedDailyChallenge(_ challenge: DailyChallenge) -> Bool {
        completedDailyChallengeIDs.contains(challenge.id)
    }

    func hasCompletedDailyChallenge(on date: Date, calendar: Calendar = .current) -> Bool {
        completedDailyChallengeIDs.contains(DailyCalendar.dayID(for: date, calendar: calendar))
    }

    /// The app calls this only after finishing today's separate daily run.
    @discardableResult
    mutating func completeDailyChallenge(
        _ challenge: DailyChallenge, at date: Date = Date(), calendar: Calendar = .current
    ) -> Int {
        guard challenge.id == DailyCalendar.dayID(for: date, calendar: calendar),
              !completedDailyChallengeIDs.contains(challenge.id),
              dailyChallenges.claim(at: date, calendar: calendar) != nil else { return 0 }
        completedDailyChallengeIDs.insert(challenge.id)
        points += challenge.reward
        return challenge.reward
    }

    @discardableResult
    mutating func claimMilestone(id: String) -> Int {
        guard !claimedMilestoneIDs.contains(id),
              let milestone = MilestoneChallenge.catalog.first(where: { $0.id == id }),
              milestone.isComplete(in: self) else { return 0 }
        claimedMilestoneIDs.insert(id)
        points += milestone.reward
        return milestone.reward
    }

    /// Call only from the ad provider's earned-reward callback, never on dismissal.
    @discardableResult
    mutating func claimAdBonus(level: MazeLevel) -> Int {
        let key = completionKey(for: level)
        guard rewardedLevelKeys.contains(key), bonusLevelKeys.insert(key).inserted else { return 0 }
        points += 50
        return 50
    }

    /// Catalog lookup prevents a caller from substituting a discounted skin value.
    @discardableResult
    mutating func purchaseSkin(_ skin: BallSkin) -> Bool {
        guard let item = BallSkin.catalog.first(where: { $0.id == skin.id }) else { return false }
        if ownedSkinIDs.contains(item.id) {
            selectedSkinID = item.id
            return true
        }
        guard points >= item.price else { return false }
        points -= item.price
        ownedSkinIDs.append(item.id)
        selectedSkinID = item.id
        return true
    }

    @discardableResult
    mutating func selectSkin(id: String) -> Bool {
        guard ownedSkinIDs.contains(id), BallSkin.catalog.contains(where: { $0.id == id }) else { return false }
        selectedSkinID = id
        return true
    }

    private func completionKey(for level: MazeLevel) -> String {
        "\(level.mode.rawValue):\(level.number)"
    }
}
