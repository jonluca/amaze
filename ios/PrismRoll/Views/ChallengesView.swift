import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var duel: DuelService
    let onPlay: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("A REASON TO RETURN").font(.system(size: 9, weight: .heavy)).tracking(2.5).foregroundStyle(Palette.cyan)
                    Text("Make it a streak.").font(.system(size: 31, weight: .bold, design: .rounded))
                    Text("Fresh mazes. Small victories. Something every day.")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                dailyRewards
                dailyMaze
                duelCard
                Text("MILESTONES").font(.system(size: 10, weight: .heavy)).tracking(2).foregroundStyle(Palette.secondary)
                ForEach(MilestoneChallenge.catalog) { milestone in milestoneCard(milestone) }
            }.padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }

    private var dailyRewards: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Image(systemName: "flame.fill").foregroundStyle(Palette.accent)
                Text("Daily rewards").font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Text("\(store.currentStreak) day streak").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.accent)
            }
            HStack(spacing: 5) {
                ForEach(1...7, id: \.self) { day in
                    let earned = min(store.currentStreak, 7) >= day
                    VStack(spacing: 8) {
                        Text("D\(day)").font(.system(size: 8, weight: .heavy)).foregroundStyle(Palette.secondary)
                        Image(systemName: earned ? "checkmark.circle.fill" : "circle.inset.filled")
                            .font(.system(size: 18)).foregroundStyle(earned ? Palette.cyan : Palette.gold)
                        Text("\(25 + (day - 1) * 5)").font(.system(size: 10, weight: .bold, design: .rounded))
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(earned ? Palette.cyan.opacity(0.10) : Palette.background, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Button(action: store.claimDaily) {
                HStack {
                    Image(systemName: store.canClaimDaily ? "gift.fill" : "checkmark")
                    Text(store.canClaimDaily ? "Claim \(store.dailyReward) coins" : "Claimed · Come back tomorrow")
                }.font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(store.canClaimDaily ? Palette.button : LinearGradient(colors: [Palette.mint], startPoint: .top, endPoint: .bottom), in: Capsule())
            }.disabled(!store.canClaimDaily).accessibilityIdentifier("claimDaily")
            Text("Claim each day to grow your reward, up to 55 coins a day.")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }.padding(18).background(Palette.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private var dailyMaze: some View {
        let completed = store.progress.hasCompletedDailyChallenge(store.dailyChallenge)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar").font(.system(size: 24)).foregroundStyle(Palette.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text("The daily maze").font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(store.dailyChallenge.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                CoinBadge(amount: store.dailyChallenge.reward)
            }
            Text("One new move challenge each day. Finish it to earn your daily prize.")
                .font(.system(size: 12)).foregroundStyle(Palette.secondary)
            Button { store.openDaily(); onPlay() } label: {
                HStack { Text(completed ? "Replay daily maze" : "Play today's challenge"); Spacer(); Image(systemName: completed ? "checkmark.seal.fill" : "arrow.right") }
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.cyan)
            }.accessibilityIdentifier("playDaily")
        }.padding(20).background(Palette.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Palette.cyan.opacity(0.18)))
    }

    private var duelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2.fill").foregroundStyle(Palette.violet)
                Text("Duel").font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Text("LIVE 1 v 1").font(.system(size: 9, weight: .heavy)).tracking(1).foregroundStyle(Palette.violet)
            }
            Text("Same maze. Two players. Paint it first.").font(.system(size: 12))
            Text(duel.status).font(.system(size: 11)).foregroundStyle(Palette.secondary)
            Button(duel.isMatching ? "Cancel matchmaking" : duel.authenticated ? "Find match" : "Connect Game Center") {
                if duel.isMatching { duel.cancel() } else { duel.findMatch() }
            }.font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.violet)
                .accessibilityIdentifier("findDuel")
        }.padding(20).background(Palette.paper, in: RoundedRectangle(cornerRadius: 24))
    }

    private func milestoneCard(_ milestone: MilestoneChallenge) -> some View {
        let value = milestone.progress(in: store.progress)
        let claimed = store.progress.claimedMilestoneIDs.contains(milestone.id)
        return HStack(spacing: 13) {
            Image(systemName: milestone.icon).font(.system(size: 23)).foregroundStyle(Palette.gold).frame(width: 32)
            VStack(alignment: .leading, spacing: 7) {
                Text(milestone.title).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(milestone.subtitle).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                ProgressView(value: Double(value), total: Double(milestone.target)).tint(Palette.violet)
                Text("\(value) / \(milestone.target)").font(.system(size: 9, weight: .semibold)).foregroundStyle(Palette.secondary)
            }
            Button { store.claimMilestone(milestone.id) } label: {
                VStack(spacing: 5) {
                    Image(systemName: claimed ? "checkmark.circle.fill" : "circle.inset.filled")
                    Text(claimed ? "Claimed" : "\(milestone.reward)")
                }.font(.system(size: 11, weight: .bold)).foregroundStyle(claimed ? Palette.cyan : Palette.gold)
            }.disabled(claimed || !milestone.isComplete(in: store.progress))
                .accessibilityLabel(claimed ? "\(milestone.title), claimed" : "Claim \(milestone.reward) coins for \(milestone.title)")
        }.padding(18).background(Palette.paper, in: RoundedRectangle(cornerRadius: 21))
    }
}
