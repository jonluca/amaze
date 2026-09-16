import SwiftUI

struct GameCenterView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var gameCenter: GameCenterService

    var body: some View {
        List {
            Section {
                Label(gameCenter.playerAlias ?? "Play with Game Center", systemImage: "person.crop.circle")
                    .font(.headline)
                Text(gameCenter.status)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("gameCenterStatus")
                if !gameCenter.authenticated {
                    Button("Check sign-in status", action: gameCenter.retry)
                        .accessibilityIdentifier("signInGameCenter")
                } else {
                    Button("Sync progress", action: gameCenter.retry)
                        .disabled(gameCenter.isSyncing)
                        .accessibilityIdentifier("gameCenterSync")
                }
            } footer: {
                Text("Keep playing offline. Saved achievements and scores sync when Game Center is available. Your mazes, coins, and collection stay on this device.")
            }

            Section {
                Button {
                    gameCenter.showDashboard(.leaderboards)
                } label: {
                    Label("Compare scores", systemImage: "list.number")
                }
                .accessibilityIdentifier("gameCenterLeaderboards")
                ForEach(GameCenterLeaderboard.allCases) { leaderboard in
                    Button {
                        gameCenter.showDashboard(.leaderboard(leaderboard))
                    } label: {
                        LabeledContent(leaderboard.title) {
                            HStack(spacing: 8) {
                                Text(leaderboard.score(in: store.gameCenterProgress).formatted())
                                    .monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption)
                                    .accessibilityHidden(true)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .accessibilityLabel(leaderboard.title)
                    .accessibilityValue(leaderboard.score(in: store.gameCenterProgress).formatted())
                    .accessibilityIdentifier("gameCenterLeaderboard_\(leaderboard.rawValue)")
                }
            } header: {
                Text("Leaderboards")
            } footer: {
                Text("These are your device's completed mazes and verified perfect solves. Replays, skipped levels, and coin purchases do not increase these totals.")
            }

            Section {
                Button {
                    gameCenter.showDashboard(.achievements)
                } label: {
                    Label("View Game Center achievements", systemImage: "trophy")
                }
                .accessibilityIdentifier("gameCenterAchievements")
                ForEach(GameCenterAchievement.allCases) { achievement in
                    achievementRow(achievement)
                }
            } header: {
                Text("Achievements")
            } footer: {
                Text("Progress shown here belongs to this device. Game Center keeps your submitted achievements and best scores with your Apple account.")
            }
        }
        .navigationTitle("Game Center")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("gameCenterPage")
    }

    private func achievementRow(_ achievement: GameCenterAchievement) -> some View {
        let value = min(achievement.target, achievement.progress(in: store.gameCenterProgress))
        let completed = value >= achievement.target
        return VStack(alignment: .leading, spacing: 6) {
            Label(achievement.title, systemImage: completed ? "checkmark.seal.fill" : "seal")
                .font(.headline)
                .foregroundStyle(completed ? Palette.gold : .primary)
            Text(completed ? achievement.achievedDescription : achievement.unachievedDescription)
                .font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: Double(value), total: Double(achievement.target)) {
                Text("\(value.formatted()) of \(achievement.target.formatted())")
                    .font(.caption).monospacedDigit()
            }
            .tint(completed ? Palette.gold : Palette.violet)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameCenterAchievement_\(achievement.rawValue)")
    }
}
