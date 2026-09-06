import GoogleMobileAds

enum AdPresentation {
    case rewarded(RewardedAd, reward: (() -> Void)?, dismiss: () -> Void)
    case interstitial(InterstitialAd, dismiss: () -> Void)

    var ad: any FullScreenPresentingAd {
        switch self {
        case .rewarded(let ad, _, _): ad
        case .interstitial(let ad, _): ad
        }
    }
}
