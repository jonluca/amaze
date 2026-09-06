import SwiftUI

struct RewardButton: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    let kind: GameplayReward
    let title: String
    let icon: String
    var body: some View {
        Button(action: watch) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(kind == .hint ? Palette.gold : Palette.cyan)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .bold, design: .rounded))
                    Label("WATCH AD", systemImage: "play.rectangle.fill")
                        .font(.system(size: 8, weight: .bold)).tracking(0.8).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 15).padding(.vertical, 12)
                .frame(maxWidth: .infinity).background(Palette.paper, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.line, lineWidth: 1))
        }.disabled(ads.isPresenting || store.isRewardPending)
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
