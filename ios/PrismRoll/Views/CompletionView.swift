import SwiftUI

struct CompletionView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    @EnvironmentObject private var duel: DuelService

    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle().fill((store.run.isComplete ? Palette.gold : Palette.accent).opacity(0.10)).frame(width: 70, height: 70)
                Image(systemName: store.isDuel ? "flag.checkered" : store.run.isComplete ? "trophy.fill" : store.timeExpired ? "timer" : "scope")
                    .font(.system(size: 33, weight: .medium)).foregroundStyle(store.run.isComplete ? Palette.gold : Palette.accent)
                    .shadow(color: Palette.gold.opacity(0.20), radius: 15)
            }
            VStack(spacing: 7) {
                Text(title).font(.title2.bold()).accessibilityIdentifier("completionTitle")
                Text(subtitle).font(.subheadline).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            }
            if store.isDuel {
                Text(duel.didWin == nil ? "Waiting for the match result…" : duel.didWin == true ? "You painted the maze first." : "A new opponent. A fresh chance.")
                    .font(.subheadline).foregroundStyle(Palette.cyan)
                primary("Back to play") { duel.cancel(); store.endSpecialSession() }
            } else if store.run.isComplete {
                if store.earnedPoints > 0 {
                    CoinBadge(amount: store.earnedPoints * (store.bonusClaimed && !store.isDaily ? 2 : 1))
                } else {
                    Text(store.bonusClaimed && !store.isDaily ? "Completion and bonus coins already collected" : "Completion coins already collected")
                        .font(.footnote).foregroundStyle(Palette.secondary)
                }
                primary(store.isDaily ? "Back to play" : "Keep rolling") {
                    if store.isDaily { store.nextLevel() }
                    else { ads.presentInterstitial { store.nextLevel() } }
                }.accessibilityIdentifier("nextLevel")
                if store.canClaimAdBonus {
                    Button {
                        guard ads.canShowRewarded else { ads.prepare(); store.notice = "No bonus video is available right now."; return }
                        let level = store.run.level
                        store.beginReward()
                        ads.presentRewarded(onReward: { store.claimAdBonus(for: level) }, onDismiss: { store.finishReward() })
                    } label: {
                        Label("Double coins · watch ad", systemImage: "play.rectangle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.gold)
                    }.buttonStyle(.bordered).disabled(ads.isPresenting || store.isRewardPending)
                }
            } else {
                RewardButton(kind: store.timeExpired ? .extraTime : .extraMoves,
                             title: store.timeExpired ? "Continue with +30 seconds" : "Continue with +3 moves",
                             icon: store.timeExpired ? "timer" : "scope")
                primary("Try again", action: store.replay).accessibilityIdentifier("retryLevel")
                Text("Retrying is always free.").font(.footnote).foregroundStyle(Palette.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))

    }
    private var title: String {
        if store.isDuel { return duel.didWin == nil ? "Maze painted!" : duel.didWin == true ? "You won!" : "Good race." }
        return store.run.isComplete ? "Beautifully done." : store.timeExpired ? "Out of time." : "Out of moves."
    }
    private var subtitle: String {
        if store.isDuel { return "HEAD TO HEAD" }
        if store.isDaily { return store.run.isComplete ? "Today’s challenge is in the books." : "A different route could be the one." }
        return store.run.isComplete ? "Every path painted. On to the next." : "Keep your painted paths with a bonus video."
    }
    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(ads.isPresenting || store.isRewardPending)
    }
}
