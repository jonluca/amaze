import Foundation

struct InterstitialFrequencyPolicy {
    private var completionsSinceAd = 0
    private var sessionCompletions = 0
    private var firstCompletionAt: Date?
    private var lastAdDismissal: Date?

    /// Every launch starts with eight completed levels and at least three minutes
    /// after the first completion before a forced ad is eligible. Optional videos
    /// never shorten that grace period. Later ads need four more completions and
    /// ninety seconds since the most recent video was dismissed.
    mutating func completedLevel(at date: Date) -> Bool {
        if firstCompletionAt == nil { firstCompletionAt = date }
        sessionCompletions = min(sessionCompletions + 1, 8)
        completionsSinceAd = min(completionsSinceAd + 1, 4)
        guard sessionCompletions >= 8, let firstCompletionAt,
              date.timeIntervalSince(firstCompletionAt) >= 180,
              completionsSinceAd >= 4 else { return false }
        guard let lastAdDismissal else { return true }
        return date.timeIntervalSince(lastAdDismissal) >= 90
    }

    mutating func presentedAd() { completionsSinceAd = 0 }

    mutating func dismissedAd(at date: Date) {
        lastAdDismissal = date
        completionsSinceAd = 0
    }
}
