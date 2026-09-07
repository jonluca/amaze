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
            } else {
                RewardButton(kind: store.timeExpired ? .extraTime : .extraMoves,
                             title: store.timeExpired ? "Continue with +30 seconds" : "Continue with +3 moves",
                             icon: store.timeExpired ? "timer" : "scope")
                primary(store.isTimeRush ? "Restart round" : "Try again", action: store.replay).accessibilityIdentifier("retryLevel")
                Text(store.isTimeRush ? "Restart all \(store.timeRushMazeCount) mazes with a fresh clock, free." : "Retrying is always free.")
                    .font(.footnote).foregroundStyle(Palette.secondary).multilineTextAlignment(.center)
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
        if store.isTimeRush {
            let progress = "\(store.timeRushMazesCompleted) of \(store.timeRushMazeCount) mazes painted."
            return ads.canShowRewarded ? "\(progress) Add time to keep your place in the round." : progress
        }
        if store.run.isComplete { return "Every path painted. On to the next." }
        return ads.canShowRewarded ? "Keep your painted paths with a bonus video." : "A different route could be the one."
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
