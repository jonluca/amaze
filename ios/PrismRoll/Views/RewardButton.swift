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
                Label(isIntroductoryHint ? "Free hint" : title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 4) {
                    if availability == .loading { ProgressView().controlSize(.mini) }
                    Text(isIntroductoryHint ? "First maze · no ad" : availability.caption)
                }
                .font(.caption).foregroundStyle(Palette.ink.opacity(0.8))
            }
            .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(ads.isPresenting || ads.isPrivacyFormPresenting || store.isRewardPending || availability == .loading)
            .accessibilityLabel(isIntroductoryHint ? "Free hint, first maze, no ad" : "\(kind == .hint ? "Show hint" : kind.title), \(availability.caption)")
            .accessibilityHint(isIntroductoryHint ? "Shows the next direction. No ad is required." : availability.accessibilityHint)
            .accessibilityIdentifier("reward_\(kind.rawValue)")
    }

    private var isIntroductoryHint: Bool { kind == .hint && store.offersIntroductoryHints }

    private var availability: RewardedAdAvailability {
        if isIntroductoryHint { return .ready }
#if DEBUG
        if isTestHint { return .ready }
#endif
        return ads.rewardedAvailability
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
