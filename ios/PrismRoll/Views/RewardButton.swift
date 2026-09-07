import SwiftUI

struct RewardButton: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    let kind: GameplayReward
    let title: String
    let icon: String
    var body: some View {
        Button(action: watch) {
            VStack(spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Label("Watch ad", systemImage: "play.rectangle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(ads.isPresenting || store.isRewardPending)
            .accessibilityLabel(kind == .hint ? "Show hint" : kind.title)
            .accessibilityIdentifier("reward_\(kind.rawValue)")
    }
    private func watch() {
#if DEBUG
        if (ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--ui-hints")), kind == .hint { store.showHint(); return }
#endif
        guard let request = store.rewardRequest(kind) else { return }
        guard ads.canShowRewarded else {
            ads.prepare()
            store.notice = "No video is available right now. Please try again shortly."
            return
        }
        store.beginReward()
        ads.presentRewarded(onReward: { store.applyReward(request) }, onDismiss: { store.finishReward() })
    }
}
