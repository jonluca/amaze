import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onPlay: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Text("\(store.currentStreak) days").monospacedDigit()
                } label: {
                    Label("Current streak", systemImage: "flame.fill")
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(1...7, id: \.self) { day in
                            VStack(spacing: 6) {
                                Text("Day \(day)").font(.caption2)
                                Image(systemName: min(store.currentStreak, 7) >= day ? "checkmark.circle.fill" : "circle.inset.filled")
                                    .foregroundStyle(min(store.currentStreak, 7) >= day ? Palette.cyan : Palette.gold)
                                Text("\(25 + (day - 1) * 5)").font(.caption.weight(.semibold))
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                Button(action: store.claimDaily) {
                    Label(store.canClaimDaily ? "Claim \(store.dailyReward) coins" : "Claimed · Come back tomorrow",
                          systemImage: store.canClaimDaily ? "gift" : "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!store.canClaimDaily)
                .accessibilityIdentifier("claimDaily")
            } header: {
                Text("Daily rewards")
            } footer: {
                Text("Claim each day to grow your reward, up to 55 coins a day.")
            }

            Section("The daily maze") {
                let rewardLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 12))
                rewardLayout {
                    Text(store.dailyChallenge.date.formatted(date: .abbreviated, time: .omitted))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CoinBadge(amount: store.dailyChallenge.reward)
                }
                Button { store.openDaily(replayCompleted: true); onPlay() } label: {
                    Label(store.progress.hasCompletedDailyChallenge(store.dailyChallenge) ? "Replay daily maze" : "Play today's challenge",
                          systemImage: "calendar")
                }
                .accessibilityIdentifier("playDaily")
                Text("One new move challenge each day. Finish it to earn your daily prize.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Section("Milestones") {
                ForEach(store.progress.currentMilestones) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func milestoneRow(_ milestone: MilestoneChallenge) -> some View {
        let value = milestone.progress(in: store.progress)
        return VStack(alignment: .leading, spacing: 10) {
            Label(milestone.title, systemImage: milestone.icon)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(milestone.subtitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("milestoneTarget-\(milestone.trackID)")
            if let target = milestone.target {
                ProgressView(value: Double(value), total: Double(target)) {
                    Text("\(value.formatted()) / \(target.formatted())")
                        .font(.caption).monospacedDigit()
                }
            }
            Button { store.claimMilestone(milestone.id) } label: {
                Label("Claim \(milestone.reward.formatted()) coins", systemImage: "circle.inset.filled")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!milestone.isComplete(in: store.progress))
            .accessibilityIdentifier("claimMilestone-\(milestone.id)")
            .accessibilityLabel("Claim \(milestone.reward) coins for \(milestone.subtitle)")
        }
        .padding(.vertical, 6)
    }
}
