import SwiftUI

struct RewardButton: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var ads: AdService
    let kind: GameplayReward
    let title: String
    let icon: String
    var body: some View {
        if isAvailable {
            Button(action: watch) {
                VStack(spacing: 4) {
                    Label(isIntroductoryHint ? "Free hint" : title, systemImage: icon)
                        .font(.subheadline.weight(.semibold))
                    Text(isIntroductoryHint ? "First maze" : "Watch ad")
                        .font(.caption).foregroundStyle(Palette.ink.opacity(0.8))
                }
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(ads.isPresenting || ads.isPrivacyFormPresenting || store.isRewardPending)
            .accessibilityLabel(isIntroductoryHint ? "Free hint, first maze" : "\(kind == .hint ? "Show hint" : kind.title), Watch ad")
            .accessibilityHint(isIntroductoryHint ? "Shows the next direction." : "Watch a video ad to receive this reward.")
            .accessibilityIdentifier("reward_\(kind.rawValue)")
        }
    }

    private var isIntroductoryHint: Bool { kind == .hint && store.offersIntroductoryHints }

    private var isAvailable: Bool {
        if isIntroductoryHint { return true }
#if DEBUG
        if isTestHint { return true }
#endif
        return ads.canShowRewarded
    }

#if DEBUG
    private var isTestHint: Bool {
        kind == .hint && (ProcessInfo.processInfo.arguments.contains("--uitesting")
            || ProcessInfo.processInfo.arguments.contains("--ui-hints"))
    }
#endif

    private func watch() {
        if isIntroductoryHint { store.showHint(); return }
#if DEBUG
        if isTestHint { store.showHint(); return }
#endif
        guard ads.canShowRewarded else {
            ads.prepare()
            return
        }
        guard let request = store.rewardRequest(kind) else { return }
        store.beginReward()
        ads.presentRewarded(onReward: { store.applyReward(request) }, onDismiss: { store.finishReward() })
    }
}
