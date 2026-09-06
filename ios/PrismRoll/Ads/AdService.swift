import Combine
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

@MainActor
final class AdService: NSObject, ObservableObject {
    @Published private(set) var canShowRewarded = false
    @Published private(set) var isPresenting = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var statusMessage = "Preparing optional ads…"
    @Published private(set) var isPrivacyFormPresenting = false
    @Published var interstitialsDisabled = false {
        didSet {
            if interstitialsDisabled {
                interstitialAd = nil
                interstitialTask?.cancel()
            }
        }
    }

    private let configuration = AdConfiguration.current
    private var consentTask: Task<Void, Never>?
    private var rewardedTask: Task<Void, Never>?
    private var interstitialTask: Task<Void, Never>?
    private var didUpdateConsent = false
    private var didStartSDK = false
    private var consentRevision = 0
    private var lastConsentAttempt: Date?
    private var lastRewardedAttempt: Date?
    private var lastInterstitialAttempt: Date?
    private var rewardedAd: LoadedAd<RewardedAd>?
    private var interstitialAd: LoadedAd<InterstitialAd>?
    private var activePresentation: AdPresentation?
    private var completionsSinceAd = 0

    /// Call after the root view is visible, on foreground, and after level transitions.
    /// UMP is refreshed once per launch; failed requests can retry on a later call.
    func prepare() {
        guard configuration != nil else {
            statusMessage = "Ads are not configured. Enjoy uninterrupted play."
            return
        }
        guard !isPrivacyFormPresenting, !isPresenting else { return }
        discardExpiredAds()
        if didUpdateConsent {
            startAdsIfAllowed()
            return
        }
        guard consentTask == nil, retryIsDue(lastConsentAttempt) else { return }
        lastConsentAttempt = Date()
        consentTask = Task { [weak self] in
            guard let self else { return }
            defer { consentTask = nil }
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
                privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                // UMP presents only when required, and resolves after the form closes.
                isPrivacyFormPresenting = true
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
                isPrivacyFormPresenting = false
                didUpdateConsent = true
                startAdsIfAllowed()
            } catch {
                isPrivacyFormPresenting = false
                privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                statusMessage = "Ads are unavailable right now. You can keep playing."
                // UMP may retain a valid prior choice after a transient network error.
                startAdsIfAllowed()
            }
        }
    }

    /// The callback runs only when Google's SDK reports the reward as earned.
    func presentRewarded(onReward: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) {
        discardExpiredAds()
        guard !isPresenting, !isPrivacyFormPresenting,
              ConsentInformation.shared.canRequestAds,
              let loaded = rewardedAd else {
            statusMessage = "No video is available right now. You can keep playing."
            onDismiss()
            prepare()
            return
        }
        do {
            try loaded.ad.canPresent(from: nil)
        } catch {
            rewardedAd = nil
            canShowRewarded = false
            statusMessage = "The video could not open. You can keep playing."
            onDismiss()
            prepare()
            return
        }
        rewardedAd = nil
        canShowRewarded = false
        activePresentation = .rewarded(loaded.ad, reward: onReward, dismiss: onDismiss)
        isPresenting = true
        completionsSinceAd = 0
        loaded.ad.present(from: nil) { [weak self, weak ad = loaded.ad] in
            guard let ad else { return }
            self?.grantEarnedReward(for: ad)
        }
    }

    /// Invoke exactly once from each completed level's Continue action.
    /// Every fourth completion is eligible; unavailable ads never delay the next level.
    func presentInterstitial(onDismiss: @escaping () -> Void) {
        guard configuration != nil, !interstitialsDisabled else {
            onDismiss()
            return
        }
        guard !isPresenting else { return }
        completionsSinceAd += 1
        discardExpiredAds()
        guard completionsSinceAd >= 4, !isPrivacyFormPresenting,
              ConsentInformation.shared.canRequestAds,
              let loaded = interstitialAd else {
            onDismiss()
            prepare()
            return
        }
        do {
            try loaded.ad.canPresent(from: nil)
        } catch {
            interstitialAd = nil
            onDismiss()
            prepare()
            return
        }
        interstitialAd = nil
        activePresentation = .interstitial(loaded.ad, dismiss: onDismiss)
        completionsSinceAd = 0
        isPresenting = true
        canShowRewarded = false
        loaded.ad.present(from: nil)
    }

    func presentPrivacyOptions() {
        guard privacyOptionsRequired, !isPresenting, !isPrivacyFormPresenting,
              consentTask == nil else { return }
        isPrivacyFormPresenting = true
        invalidateLoadedAds()
        consentTask = Task { [weak self] in
            guard let self else { return }
            defer { consentTask = nil }
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            } catch {
                statusMessage = "Privacy options could not open. Please try again later."
            }
            isPrivacyFormPresenting = false
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            startAdsIfAllowed()
        }
    }

    func finishPresentation(_ ad: any FullScreenPresentingAd, failed: Bool) {
        guard let presentation = activePresentation, presentation.ad === ad else { return }
        activePresentation = nil
        isPresenting = false
        statusMessage = failed ? "The ad could not open. You can keep playing." : "Optional bonus ads"
        switch presentation {
        case .interstitial(_, let dismiss), .rewarded(_, _, let dismiss): dismiss()
        }
        prepare()
    }

    private func grantEarnedReward(for rewarded: RewardedAd) {
        guard case .rewarded(let ad, let reward, let dismiss) = activePresentation,
              ad === rewarded, let reward else { return }
        // Consume the callback before invoking client code, so a repeated SDK event is harmless.
        activePresentation = .rewarded(ad, reward: nil, dismiss: dismiss)
        reward()
    }

    private func startAdsIfAllowed() {
        guard ConsentInformation.shared.canRequestAds, !isPrivacyFormPresenting else {
            invalidateLoadedAds()
            statusMessage = "Ads are off. You can keep playing."
            return
        }
        if !didStartSDK {
            AdConfiguration.configurePrivacy()
            didStartSDK = true
            MobileAds.shared.start()
        }
        loadRewarded()
        loadInterstitial()
    }

    private func loadRewarded() {
        guard let configuration, rewardedAd == nil, rewardedTask == nil,
              retryIsDue(lastRewardedAttempt), ConsentInformation.shared.canRequestAds else { return }
        let revision = consentRevision
        lastRewardedAttempt = Date()
        rewardedTask = Task { [weak self] in
            guard let self else { return }
            defer { rewardedTask = nil }
            do {
                let ad = try await RewardedAd.load(with: configuration.rewardedUnitID, request: AdConfiguration.makeRequest())
                guard !Task.isCancelled, revision == consentRevision,
                      ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self
                rewardedAd = LoadedAd(ad: ad)
                canShowRewarded = !isPresenting && !isPrivacyFormPresenting
                statusMessage = "Optional reward videos are ready."
            } catch {
                guard revision == consentRevision else { return }
                canShowRewarded = false
                statusMessage = "No bonus ad is available right now. Keep playing."
            }
        }
    }

    private func loadInterstitial() {
        guard !interstitialsDisabled, let configuration, interstitialAd == nil, interstitialTask == nil,
              retryIsDue(lastInterstitialAttempt), ConsentInformation.shared.canRequestAds else { return }
        let revision = consentRevision
        lastInterstitialAttempt = Date()
        interstitialTask = Task { [weak self] in
            guard let self else { return }
            defer { interstitialTask = nil }
            do {
                let ad = try await InterstitialAd.load(with: configuration.interstitialUnitID, request: AdConfiguration.makeRequest())
                guard !Task.isCancelled, !interstitialsDisabled, revision == consentRevision,
                      ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self
                interstitialAd = LoadedAd(ad: ad)
            } catch {
                // An unavailable interstitial never changes the level flow.
            }
        }
    }

    private func discardExpiredAds() {
        if rewardedAd?.isFresh == false { rewardedAd = nil }
        if interstitialAd?.isFresh == false { interstitialAd = nil }
        canShowRewarded = rewardedAd != nil && !isPresenting && !isPrivacyFormPresenting
            && ConsentInformation.shared.canRequestAds
    }

    private func invalidateLoadedAds() {
        consentRevision += 1
        rewardedAd = nil
        interstitialAd = nil
        canShowRewarded = false
        rewardedTask?.cancel()
        interstitialTask?.cancel()
        // Tasks clear their own handles on completion; their results are revision-checked.
    }

    private func retryIsDue(_ previousAttempt: Date?) -> Bool {
        guard let previousAttempt else { return true }
        return Date().timeIntervalSince(previousAttempt) >= 30
    }
}
