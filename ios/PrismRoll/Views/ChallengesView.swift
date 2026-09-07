import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var duel: DuelService
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
                LabeledContent(store.dailyChallenge.date.formatted(date: .abbreviated, time: .omitted)) {
                    CoinBadge(amount: store.dailyChallenge.reward)
                }
                Button { store.openDaily(); onPlay() } label: {
                    Label(store.progress.hasCompletedDailyChallenge(store.dailyChallenge) ? "Replay daily maze" : "Play today's challenge",
                          systemImage: "calendar")
                }
                .accessibilityIdentifier("playDaily")
                Text("One new move challenge each day. Finish it to earn your daily prize.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Section("Duel") {
                Label("Same maze. Two players. Paint it first.", systemImage: "person.2")
                Text(duel.status).font(.subheadline).foregroundStyle(.secondary)
                Button(duel.isMatching ? "Cancel matchmaking" : duel.authenticated ? "Find match" : "Connect Game Center") {
                    if duel.isMatching { duel.cancel() } else { duel.findMatch() }
                }
                .accessibilityIdentifier("findDuel")
            }

            Section("Milestones") {
                ForEach(MilestoneChallenge.catalog) { milestone in
                    milestoneRow(milestone)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func milestoneRow(_ milestone: MilestoneChallenge) -> some View {
        let value = milestone.progress(in: store.progress)
        let claimed = store.progress.claimedMilestoneIDs.contains(milestone.id)
        return VStack(alignment: .leading, spacing: 10) {
            Label(milestone.title, systemImage: milestone.icon).font(.headline)
            Text(milestone.subtitle).font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: Double(value), total: Double(milestone.target)) {
                Text("\(value) / \(milestone.target)").font(.caption).monospacedDigit()
            }
            Button { store.claimMilestone(milestone.id) } label: {
                Label(claimed ? "Claimed" : "Claim \(milestone.reward) coins", systemImage: claimed ? "checkmark.circle" : "circle.inset.filled")
            }
            .buttonStyle(.bordered)
            .disabled(claimed || !milestone.isComplete(in: store.progress))
            .accessibilityLabel(claimed ? "\(milestone.title), claimed" : "Claim \(milestone.reward) coins for \(milestone.title)")
        }
        .padding(.vertical, 6)
    }
}
