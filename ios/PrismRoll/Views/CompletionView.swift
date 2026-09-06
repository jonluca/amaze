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
                Text(title).font(.system(size: 27, weight: .bold, design: .rounded)).accessibilityIdentifier("completionTitle")
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
            }
            if store.isDuel {
                Text(duel.didWin == nil ? "Waiting for the match result…" : duel.didWin == true ? "You painted the maze first." : "A new opponent. A fresh chance.")
                    .font(.system(size: 13)).foregroundStyle(Palette.cyan)
                primary("Back to play") { duel.cancel(); store.endSpecialSession() }
            } else if store.run.isComplete {
                if store.earnedPoints > 0 {
                    CoinBadge(amount: store.earnedPoints * (store.bonusClaimed && !store.isDaily ? 2 : 1))
                } else {
                    Text(store.bonusClaimed && !store.isDaily ? "Completion and bonus coins already collected" : "Completion coins already collected")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
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
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.gold)
                    }.disabled(ads.isPresenting)
                }
            } else {
                RewardButton(kind: store.timeExpired ? .extraTime : .extraMoves,
                             title: store.timeExpired ? "Continue with +30 seconds" : "Continue with +3 moves",
                             icon: store.timeExpired ? "timer" : "scope")
                primary("Try again", action: store.replay).accessibilityIdentifier("retryLevel")
                Text("Retrying is always free.").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
        .padding(26)
        .background(LinearGradient(colors: [Color(hex: "202C48"), Palette.paper], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 29))
        .overlay(RoundedRectangle(cornerRadius: 29).stroke(LinearGradient(colors: [Palette.violet.opacity(0.55), Palette.line], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 35, y: 14).frame(maxWidth: 350)
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
            HStack { Text(title); Spacer(); Image(systemName: "arrow.right") }
                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                .padding(17).background(Palette.button, in: RoundedRectangle(cornerRadius: 17))
        }.disabled(ads.isPresenting)
    }
}
