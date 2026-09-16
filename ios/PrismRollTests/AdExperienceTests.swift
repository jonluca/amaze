#if canImport(UIKit)
import XCTest
@testable import PrismRoll

@MainActor
final class AdExperienceTests: XCTestCase {
    func testUnavailableRewardAttemptsNeverGrantRewardsOrHoldGameplay() {
        let ads = AdService(configuration: nil)
        var earned = 0
        var dismissed = 0
        XCTAssertEqual(ads.rewardedAvailability, .unavailable)
        for _ in 0..<20 {
            ads.prepare()
            ads.presentRewarded(onReward: { earned += 1 }, onDismiss: { dismissed += 1 })
        }
        XCTAssertEqual(earned, 0)
        XCTAssertEqual(dismissed, 20, "Each unavailable attempt releases its caller's presentation pause exactly once")
        XCTAssertFalse(ads.canShowRewarded)
        XCTAssertFalse(ads.isPresenting)
        XCTAssertEqual(ads.rewardedAvailability, .unavailable)
    }

    func testUnavailableInterstitialsAlwaysContinueImmediately() {
        let ads = AdService(configuration: nil)
        var continued = 0
        for _ in 0..<20 { ads.presentInterstitial { continued += 1 } }
        XCTAssertEqual(continued, 20)
        XCTAssertFalse(ads.isPresenting)
    }

    func testRetryBackoffAppliesOnlyToFailureAndSuccessfulAdsCanRefillImmediately() {
        let date = Date(timeIntervalSince1970: 1_000)
        var retry = AdLoadRetryPolicy()
        XCTAssertTrue(retry.canAttempt(at: date))
        retry.succeeded()
        XCTAssertTrue(retry.canAttempt(at: date), "Consuming a successfully loaded ad must not impose a failure cooldown")
        retry.failed(at: date)
        for second in 0..<30 {
            XCTAssertFalse(retry.canAttempt(at: date.addingTimeInterval(Double(second))))
        }
        XCTAssertTrue(retry.canAttempt(at: date.addingTimeInterval(30)))
        retry.succeeded()
        XCTAssertTrue(retry.canAttempt(at: date.addingTimeInterval(30)))
        retry.failed(at: date.addingTimeInterval(40))
        XCTAssertFalse(retry.canAttempt(at: date.addingTimeInterval(60)))
        XCTAssertTrue(retry.canAttempt(at: date.addingTimeInterval(70)))
    }

    func testFirstInterstitialRequiresBothEightCompletionsAndThreeMinuteGrace() {
        let date = Date(timeIntervalSince1970: 1_000)
        var frequency = InterstitialFrequencyPolicy()
        for _ in 0..<8 { XCTAssertFalse(frequency.completedLevel(at: date)) }
        XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(179)))
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(180)))

        var slowPlayer = InterstitialFrequencyPolicy()
        XCTAssertFalse(slowPlayer.completedLevel(at: date))
        for _ in 0..<6 { XCTAssertFalse(slowPlayer.completedLevel(at: date.addingTimeInterval(600))) }
        XCTAssertTrue(slowPlayer.completedLevel(at: date.addingTimeInterval(600)))
    }

    func testLaterInterstitialsNeedFourCompletionsAndQuietPeriodAfterDismissal() {
        let date = Date(timeIntervalSince1970: 1_000)
        var frequency = InterstitialFrequencyPolicy()
        for _ in 0..<7 { XCTAssertFalse(frequency.completedLevel(at: date)) }
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(180)))
        frequency.presentedAd()
        frequency.dismissedAd(at: date.addingTimeInterval(210))
        // Fast maze completions never bypass the interval measured from dismissal.
        for second in 211..<300 {
            XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(Double(second))))
        }
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(300)))
        frequency.presentedAd()
        frequency.dismissedAd(at: date.addingTimeInterval(330))
        for _ in 0..<3 { XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(420))) }
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(420)))
    }

    func testVoluntaryRewardAdAlsoResetsAutomaticAdFrequency() {
        let date = Date(timeIntervalSince1970: 1_000)
        var frequency = InterstitialFrequencyPolicy()
        for _ in 0..<8 { _ = frequency.completedLevel(at: date) }
        // Both ad formats use these callbacks, so a bonus video buys the same quiet period.
        frequency.presentedAd()
        frequency.dismissedAd(at: date)
        for _ in 0..<4 { XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(89))) }
        XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(90)), "An optional video must not end first-session grace early")
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(180)))
        frequency.presentedAd()
        frequency.dismissedAd(at: date.addingTimeInterval(200))
        for _ in 0..<4 { XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(289))) }
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(290)))
    }

    func testUnavailableInterstitialOpportunityDoesNotWaitForInventory() {
        let date = Date(timeIntervalSince1970: 1_000)
        var frequency = InterstitialFrequencyPolicy()
        for _ in 0..<8 { _ = frequency.completedLevel(at: date) }
        // No presentation is recorded when inventory is absent. Eligibility is only
        // evaluated again at a future completed level, never by an ad-load callback.
        XCTAssertTrue(frequency.completedLevel(at: date.addingTimeInterval(180)))
        frequency.presentedAd()
        frequency.dismissedAd(at: date.addingTimeInterval(190))
        XCTAssertFalse(frequency.completedLevel(at: date.addingTimeInterval(191)))
    }
}
#endif
