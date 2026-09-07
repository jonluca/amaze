import Foundation

struct InterstitialFrequencyPolicy {
    private var completionsSinceAd = 0
    private var lastAdDismissal: Date?

    /// Ninety seconds is this app's UX choice, in addition to four completed levels.
    /// Rewarded videos also start a quiet period before another automatic ad.
    mutating func completedLevel(at date: Date) -> Bool {
        completionsSinceAd = min(completionsSinceAd + 1, 4)
        guard completionsSinceAd >= 4 else { return false }
        guard let lastAdDismissal else { return true }
        return date.timeIntervalSince(lastAdDismissal) >= 90
    }

    mutating func presentedAd() { completionsSinceAd = 0 }

    mutating func dismissedAd(at date: Date) {
        lastAdDismissal = date
        completionsSinceAd = 0
    }
}
