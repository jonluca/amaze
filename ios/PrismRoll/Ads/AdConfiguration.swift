import Foundation
import GoogleMobileAds

struct AdConfiguration {
    let rewardedUnitID: String
    let interstitialUnitID: String

    /// Apply before SDK initialization. UMP continues to own the user's TCF/GPP choices.
    @MainActor
    static func configurePrivacy() {
        let requestConfiguration = MobileAds.shared.requestConfiguration
        requestConfiguration.setPublisherFirstPartyIDEnabled(false)
        requestConfiguration.publisherPrivacyPersonalizationState = .disabled
        requestConfiguration.maxAdContentRating = .general
        // Google's documented iOS RDP signal restricts all subsequent ad requests.
        UserDefaults.standard.set(true, forKey: "gad_rdp")
    }

    @MainActor
    static func makeRequest() -> Request {
        let request = Request()
        let extras = Extras()
        // Keep NPA explicit on each format as well as the global privacy treatment.
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    static var current: AdConfiguration? {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard !arguments.contains("--uitesting"), !arguments.contains("--no-ads") else { return nil }
        return AdConfiguration(
            rewardedUnitID: "ca-app-pub-3940256099942544/1712485313",
            interstitialUnitID: "ca-app-pub-3940256099942544/4411468910"
        )
#else
        guard
            let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String,
            let rewarded = Bundle.main.object(forInfoDictionaryKey: "PrismRewardedAdUnitID") as? String,
            let interstitial = Bundle.main.object(forInfoDictionaryKey: "PrismInterstitialAdUnitID") as? String,
            appID.hasPrefix("ca-app-pub-"), appID.contains("~"),
            rewarded.hasPrefix("ca-app-pub-"), rewarded.contains("/"),
            interstitial.hasPrefix("ca-app-pub-"), interstitial.contains("/"),
            ![appID, rewarded, interstitial].contains(where: { $0.contains("3940256099942544") })
        else { return nil }
        return AdConfiguration(rewardedUnitID: rewarded, interstitialUnitID: interstitial)
#endif
    }
}
