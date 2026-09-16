import Combine
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

@MainActor
final class AdService: NSObject, ObservableObject {
    enum RewardedPlacement: String {
        case gameplay
        case completionBonus = "completion_bonus"
        case coinShop = "coin_shop"
    }

    private enum AdFailure: String {
        case unavailable
        case presentationUnavailable = "presentation_unavailable"
        case presentationFailed = "presentation_failed"
    }

    @Published private(set) var rewardedAvailability: RewardedAdAvailability = .loading
    @Published private(set) var isPresenting = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var statusMessage = "Preparing optional ads…"
    @Published private(set) var isPrivacyFormPresenting = false
    /// Includes the consent-info request, before UMP knows whether a sheet is required.
    @Published private(set) var isUpdatingConsent = false
    @Published var interstitialsDisabled = false {
        didSet {
            if interstitialsDisabled {
                interstitialAd = nil
                interstitialTask?.cancel()
            }
        }
    }

    private let configuration: AdConfiguration?
    private let now: () -> Date
    private let analytics: any AnalyticsRecording
    private var consentTask: Task<Void, Never>?
    private var rewardedTask: Task<Void, Never>?
    private var interstitialTask: Task<Void, Never>?
    private var didUpdateConsent = false
    private var didStartSDK = false
    private var consentRevision = 0
    private var lastConsentAttempt: Date?
    private var rewardedRetry = AdLoadRetryPolicy()
    private var interstitialRetry = AdLoadRetryPolicy()
    private var rewardedAd: LoadedAd<RewardedAd>?
    private var interstitialAd: LoadedAd<InterstitialAd>?
    private var activePresentation: AdPresentation?
    private var activeRewardedPlacement: RewardedPlacement = .gameplay
    private var recordedPresentationShown = false
    private var frequency = InterstitialFrequencyPolicy()

    init(configuration: AdConfiguration? = .current, now: @escaping () -> Date = Date.init,
         analytics: (any AnalyticsRecording)? = nil) {
        self.configuration = configuration
        self.now = now
        self.analytics = analytics ?? AnalyticsService.shared
        super.init()
        if configuration == nil { rewardedAvailability = .unavailable }
    }

    var canShowRewarded: Bool { rewardedAvailability == .ready && rewardedAd?.isFresh == true }

    func setSoundEnabled(_ enabled: Bool) {
        MobileAds.shared.isApplicationMuted = !enabled
    }

    /// Call after the root view is visible, on foreground, and after level transitions.
    /// UMP is refreshed once per launch; failed requests can retry on a later call.
    func prepare() {
        guard configuration != nil else {
            statusMessage = "Ads are not configured. Enjoy uninterrupted play."
            rewardedAvailability = .unavailable
            return
        }
        guard !isPrivacyFormPresenting, !isPresenting else { return }
        discardExpiredAds()
        if didUpdateConsent {
            startAdsIfAllowed()
            return
        }
        guard consentTask == nil, retryIsDue(lastConsentAttempt) else { return }
        lastConsentAttempt = now()
        isUpdatingConsent = true
        consentTask = Task { [weak self] in
            guard let self else { return }
            defer {
                consentTask = nil
                isUpdatingConsent = false
                updateRewardedAvailability()
            }
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
        updateRewardedAvailability()
    }

    /// The callback runs only when Google's SDK reports the reward as earned.
    func presentRewarded(placement: RewardedPlacement = .gameplay,
                         onReward: @escaping () -> Void, onDismiss: @escaping () -> Void = {}) {
        recordAdEvent("ad_requested", rewarded: true, placement: placement)
        discardExpiredAds()
        guard configuration != nil, !isPresenting, !isPrivacyFormPresenting,
              ConsentInformation.shared.canRequestAds,
              let loaded = rewardedAd else {
            statusMessage = "No video is available right now. You can keep playing."
            recordAdEvent("ad_failed", rewarded: true, placement: placement, failure: .unavailable)
            onDismiss()
            prepare()
            return
        }
        do {
            try loaded.ad.canPresent(from: nil)
        } catch {
            rewardedAd = nil
            updateRewardedAvailability()
            statusMessage = "The video could not open. You can keep playing."
            recordAdEvent("ad_failed", rewarded: true, placement: placement, failure: .presentationUnavailable)
            onDismiss()
            prepare()
            return
        }
        rewardedAd = nil
        activePresentation = .rewarded(loaded.ad, reward: onReward, dismiss: onDismiss)
        activeRewardedPlacement = placement
        recordedPresentationShown = false
        isPresenting = true
        updateRewardedAvailability()
        frequency.presentedAd()
        loaded.ad.present(from: nil) { [weak self, weak ad = loaded.ad] in
            guard let ad else { return }
            self?.grantEarnedReward(for: ad)
        }
    }

    /// Invoke exactly once when a completed level advances automatically.
    /// Session grace comes first, then four completions and 90 seconds after an ad.
    /// Unavailable ads never delay the next level or appear when loading finishes later.
    func presentInterstitial(onDismiss: @escaping () -> Void) {
        guard configuration != nil, !interstitialsDisabled else {
            onDismiss()
            return
        }
        guard !isPresenting else { return }
        let isEligible = frequency.completedLevel(at: now())
        discardExpiredAds()
        // Frequency suppression and No Ads are not failed ad requests.
        if isEligible { recordAdEvent("ad_requested", rewarded: false) }
        guard isEligible, !isPrivacyFormPresenting,
              ConsentInformation.shared.canRequestAds,
              let loaded = interstitialAd else {
            if isEligible { recordAdEvent("ad_failed", rewarded: false, failure: .unavailable) }
            onDismiss()
            prepare()
            return
        }
        do {
            try loaded.ad.canPresent(from: nil)
        } catch {
            interstitialAd = nil
            recordAdEvent("ad_failed", rewarded: false, failure: .presentationUnavailable)
            onDismiss()
            prepare()
            return
        }
        interstitialAd = nil
        activePresentation = .interstitial(loaded.ad, dismiss: onDismiss)
        recordedPresentationShown = false
        frequency.presentedAd()
        isPresenting = true
        updateRewardedAvailability()
        loaded.ad.present(from: nil)
    }

    func presentPrivacyOptions() {
        guard privacyOptionsRequired, !isPresenting, !isPrivacyFormPresenting,
              consentTask == nil else { return }
        isPrivacyFormPresenting = true
        invalidateLoadedAds()
        consentTask = Task { [weak self] in
            guard let self else { return }
            defer { consentTask = nil; updateRewardedAvailability() }
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

    func recordPresentationShown(_ ad: any FullScreenPresentingAd) {
        guard let presentation = activePresentation, presentation.ad === ad,
              !recordedPresentationShown else { return }
        recordedPresentationShown = true
        recordPresentationEvent("ad_shown", presentation: presentation)
    }

    func finishPresentation(_ ad: any FullScreenPresentingAd, failed: Bool) {
        guard let presentation = activePresentation, presentation.ad === ad else { return }
        activePresentation = nil
        isPresenting = false
        recordPresentationEvent(failed ? "ad_failed" : "ad_dismissed", presentation: presentation,
                                failure: failed ? .presentationFailed : nil)
        if !failed { frequency.dismissedAd(at: now()) }
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
        recordAdEvent("ad_reward_earned", rewarded: true, placement: activeRewardedPlacement)
        reward()
    }

    private func recordPresentationEvent(_ name: String, presentation: AdPresentation, failure: AdFailure? = nil) {
        switch presentation {
        case .rewarded:
            recordAdEvent(name, rewarded: true, placement: activeRewardedPlacement, failure: failure)
        case .interstitial:
            recordAdEvent(name, rewarded: false, failure: failure)
        }
    }

    private func recordAdEvent(_ name: String, rewarded: Bool, placement: RewardedPlacement = .gameplay,
                               failure: AdFailure? = nil) {
        var parameters: [String: Any] = [
            "ad_format": rewarded ? "rewarded" : "interstitial",
            "placement": rewarded ? placement.rawValue : "level_transition"
        ]
        if let failure { parameters["reason"] = failure.rawValue }
        analytics.record(name, parameters: parameters)
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
              rewardedRetry.canAttempt(at: now()), ConsentInformation.shared.canRequestAds else { return }
        let revision = consentRevision
        rewardedTask = Task { [weak self] in
            guard let self else { return }
            defer {
                rewardedTask = nil
                if revision != consentRevision, !isPrivacyFormPresenting, ConsentInformation.shared.canRequestAds {
                    loadRewarded()
                }
                updateRewardedAvailability()
            }
            do {
                let ad = try await RewardedAd.load(with: configuration.rewardedUnitID, request: AdConfiguration.makeRequest())
                guard !Task.isCancelled, revision == consentRevision,
                      ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self
                rewardedAd = LoadedAd(ad: ad)
                rewardedRetry.succeeded()
                statusMessage = "Optional reward videos are ready."
            } catch {
                guard !Task.isCancelled, revision == consentRevision else { return }
                rewardedRetry.failed(at: now())
                statusMessage = "No bonus ad is available right now. Keep playing."
            }
        }
        updateRewardedAvailability()
    }

    private func loadInterstitial() {
        guard !interstitialsDisabled, let configuration, interstitialAd == nil, interstitialTask == nil,
              interstitialRetry.canAttempt(at: now()), ConsentInformation.shared.canRequestAds else { return }
        let revision = consentRevision
        interstitialTask = Task { [weak self] in
            guard let self else { return }
            defer {
                interstitialTask = nil
                if revision != consentRevision, !isPrivacyFormPresenting, ConsentInformation.shared.canRequestAds {
                    loadInterstitial()
                }
            }
            do {
                let ad = try await InterstitialAd.load(with: configuration.interstitialUnitID, request: AdConfiguration.makeRequest())
                guard !Task.isCancelled, !interstitialsDisabled, revision == consentRevision,
                      ConsentInformation.shared.canRequestAds else { return }
                ad.fullScreenContentDelegate = self
                interstitialAd = LoadedAd(ad: ad)
                interstitialRetry.succeeded()
            } catch {
                guard !Task.isCancelled, revision == consentRevision else { return }
                interstitialRetry.failed(at: now())
            }
        }
    }

    private func discardExpiredAds() {
        if rewardedAd?.isFresh == false { rewardedAd = nil }
        if interstitialAd?.isFresh == false { interstitialAd = nil }
        updateRewardedAvailability()
    }

    private func invalidateLoadedAds() {
        consentRevision += 1
        rewardedAd = nil
        interstitialAd = nil
        updateRewardedAvailability()
        rewardedTask?.cancel()
        interstitialTask?.cancel()
        // Tasks clear their own handles on completion; their results are revision-checked.
    }

    private func retryIsDue(_ previousAttempt: Date?) -> Bool {
        guard let previousAttempt else { return true }
        return now().timeIntervalSince(previousAttempt) >= 30
    }

    private func updateRewardedAvailability() {
        let availability: RewardedAdAvailability
        if configuration == nil || isPresenting || isPrivacyFormPresenting {
            availability = .unavailable
        } else if rewardedAd?.isFresh == true && ConsentInformation.shared.canRequestAds {
            availability = .ready
        } else if rewardedTask != nil || consentTask != nil {
            availability = .loading
        } else {
            availability = .unavailable
        }
        if rewardedAvailability != availability { rewardedAvailability = availability }
    }
}
