# No Ads purchase

`PurchaseService` uses StoreKit 2 with a non-consumable product. Configure `PrismRemoveAdsProductID` in Info.plist; the default is `com.jonluca.prismroll.removeads`. Create that exact product for the app in App Store Connect, complete agreements/pricing/localization, and attach it to a submitted app version as required by Apple. The code does not create the App Store product.

Call `await load()` on launch or storefront refresh. Display only the returned `product.displayPrice` and disable purchase while `product` is absent or `isBusy` is true. A missing product is an unavailable store state, not a synthetic offer. The Settings purchase and Restore actions call `await purchase()` and `await restore()` respectively.

Set `ads.interstitialsDisabled = purchases.removesAds` on initial load and whenever the entitlement changes. The verified entitlement removes between-level interstitials only. Voluntary reward videos remain available and this must be stated alongside the purchase offer.

Only verified StoreKit transactions/current entitlements enable No Ads. The updates listener refreshes revoked/refunded entitlement state, and transactions are finished after processing. There is no UserDefaults unlock, fabricated price, or test-mode entitlement grant.

Validate with StoreKit sandbox or a dedicated Xcode StoreKit configuration: purchase success, cancellation, pending approval, restore on another installation, refund/revocation, offline launch with an existing verified entitlement, unavailable product, and No Ads retaining voluntary reward videos. Production purchase/restore cannot be claimed verified until the real product and signed app are provisioned and tested.
