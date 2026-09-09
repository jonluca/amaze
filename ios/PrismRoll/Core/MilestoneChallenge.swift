import Foundation

struct MilestoneChallenge: Identifiable, Sendable {
    enum Track: String, CaseIterable, Sendable {
        case levels, timeRush, coins
    }

    let id: String
    let trackID: String
    let title: String
    let subtitle: String
    /// A nil target is beyond the representable counter range, never a free reward.
    let target: Int?
    let reward: Int
    let icon: String
    private let track: Track?

    func progress(in data: ProgressData) -> Int {
        let current: Int
        switch track {
        case .levels: current = data.completedLevels
        case .timeRush: current = data.completedLevelCount(in: .timed)
        case .coins: current = data.collectedMazeCoinCount
        case nil: current = Set(data.ownedSkinIDs).count
        }
        return min(target ?? Int.max, max(0, current))
    }

    func isComplete(in data: ProgressData) -> Bool {
        guard let target else { return false }
        return progress(in: data) >= target
    }

    static func current(in data: ProgressData) -> [MilestoneChallenge] {
        Track.allCases.map { track in
            var tier = 0
            var milestone = make(track: track, tier: tier)
            // Each successful iteration consumes a distinct saved claim ID.
            // Missing earlier legacy rewards remain claimable, even if a later
            // milestone was claimed first in a previous version.
            while data.claimedMilestoneIDs.contains(milestone.id) {
                tier += 1
                milestone = make(track: track, tier: tier)
            }
            return milestone
        }
    }

    static let legacyBallCollector = MilestoneChallenge(
        id: "skin-collector", trackID: "legacy-ball-collector", title: "Ball Collector",
        subtitle: "Your collection of 4 balls earned a reward", target: 4, reward: 150,
        icon: "paintpalette.fill", track: nil
    )

    static func make(track: Track, tier: Int) -> MilestoneChallenge {
        let tier = max(0, tier)
        let target = target(for: track, tier: tier)
        let amount = target?.formatted()
        let id: String
        if track == .levels && tier == 0 { id = "first-five" }
        else if track == .levels && tier == 1 { id = "twenty-five" }
        else if track == .timeRush && tier == 0 { id = "timed-ten" }
        else { id = "\(track.rawValue):\(tier)" }

        let title: String
        let subtitle: String
        let icon: String
        switch track {
        case .levels:
            title = "Maze Explorer"
            subtitle = amount.map { "Finish \($0) levels in any mode" } ?? "Keep finishing levels"
            icon = "map.fill"
        case .timeRush:
            title = "Against the Clock"
            subtitle = amount.map { "Finish \($0) Time Rush rounds" } ?? "Keep finishing Time Rush rounds"
            icon = "timer"
        case .coins:
            title = "Coin Collector"
            subtitle = amount.map { "Collect \($0) coins inside mazes" } ?? "Keep collecting coins inside mazes"
            icon = "circle.inset.filled"
        }
        return MilestoneChallenge(
            id: id, trackID: track.rawValue, title: title, subtitle: subtitle,
            target: target, reward: reward(for: track, tier: tier), icon: icon, track: track
        )
    }

    private static func target(for track: Track, tier: Int) -> Int? {
        if tier == 0 { return track == .levels ? 5 : 10 }
        // 25, 50, 100, then the same three steps at each power of ten.
        var target = [25, 50, 100][(tier - 1) % 3]
        let exponent = (tier - 1) / 3
        // Even 25 * 10^19 exceeds Int64. Avoid looping over a malformed tier.
        guard exponent < 19 else { return nil }
        for _ in 0..<exponent {
            let result = target.multipliedReportingOverflow(by: 10)
            guard !result.overflow else { return nil }
            target = result.partialValue
        }
        return target
    }

    private static func reward(for track: Track, tier: Int) -> Int {
        if track == .levels && tier == 0 { return 75 }
        if track == .levels && tier == 1 { return 200 }
        if track == .timeRush && tier == 0 { return 200 }
        let base = track == .coins ? 100 : 200
        return min(5_000, base + min(tier, 50) * 100)
    }
}
