import SwiftUI

/// Completion bonuses remain optional in Journey, outside the next-level flow.
struct CompletionBonusButton: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    let number: Int
    let mode: GameMode

    var body: some View {
        if ads.canShowRewarded {
            Button {
                guard ads.canShowRewarded else { ads.prepare(); return }
                guard store.progress.canClaimAdBonus(number: number, mode: mode) else { return }
                let level = MazeLevel.generate(number: number, mode: mode)
                store.beginReward()
                ads.presentRewarded(onReward: { store.claimAdBonus(for: level) }, onDismiss: { store.finishReward() })
            } label: {
                Label("+50 bonus coins · Watch ad", systemImage: "play.rectangle")
                    .font(.subheadline)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
            .disabled(ads.isPresenting || ads.isPrivacyFormPresenting || store.isRewardPending)
            .accessibilityLabel("\(mode == .timed ? "Round" : "Level") \(number) bonus, 50 coins, Watch ad")
            .accessibilityHint("Watch a video ad to receive this reward.")
            .accessibilityIdentifier("completionBonus_\(mode.rawValue)_\(number)")
        }
    }
}
