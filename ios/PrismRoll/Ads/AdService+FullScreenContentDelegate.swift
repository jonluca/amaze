import GoogleMobileAds

extension AdService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        finishPresentation(ad, failed: false)
    }

    func ad(
        _ ad: any FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        finishPresentation(ad, failed: true)
    }
}
