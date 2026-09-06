struct MilestoneChallenge: Identifiable, Sendable {
    private enum Metric: Sendable {
        case completedLevels, timedCompletions, ownedSkins
    }

    let id: String
    let title: String
    let subtitle: String
    let target: Int
    let reward: Int
    let icon: String
    private let metric: Metric

    func progress(in data: ProgressData) -> Int {
        let current: Int
        switch metric {
        case .completedLevels: current = data.completedLevels
        case .timedCompletions: current = data.completedLevelCount(in: .timed)
        case .ownedSkins: current = Set(data.ownedSkinIDs).count
        }
        return min(target, current)
    }

    func isComplete(in data: ProgressData) -> Bool { progress(in: data) >= target }

    static let catalog: [MilestoneChallenge] = [
        MilestoneChallenge(id: "first-five", title: "First Steps", subtitle: "Finish 5 levels in any mode",
                           target: 5, reward: 75, icon: "flag.checkered", metric: .completedLevels),
        MilestoneChallenge(id: "twenty-five", title: "Maze Explorer", subtitle: "Finish 25 levels in any mode",
                           target: 25, reward: 200, icon: "map.fill", metric: .completedLevels),
        MilestoneChallenge(id: "timed-ten", title: "Against the Clock", subtitle: "Finish 10 Time Rush levels",
                           target: 10, reward: 200, icon: "timer", metric: .timedCompletions),
        MilestoneChallenge(id: "skin-collector", title: "Ball Collector", subtitle: "Unlock a collection of 4 balls",
                           target: 4, reward: 150, icon: "paintpalette.fill", metric: .ownedSkins)
    ]
}
