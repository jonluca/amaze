# StoreKit purchases

`PurchaseService` uses StoreKit 2 for No Ads and consumable coin packs.

## No Ads

Configure the non-consumable `PrismRemoveAdsProductID` in Info.plist; the default is `com.jonluca.prismroll.removeads`. Create that exact product for the app in App Store Connect, complete agreements/pricing/localization, and attach it to a submitted app version as required by Apple. The code does not create the App Store product.

Call `await load()` on launch or storefront refresh. Display only the returned `product.displayPrice` and disable purchase while `product` is absent or `isBusy` is true. A missing product is an unavailable store state, not a synthetic offer. The Settings purchase and Restore actions call `await purchase()` and `await restore()` respectively.

Set `ads.interstitialsDisabled = purchases.removesAds` on initial load and whenever the entitlement changes. The verified entitlement removes between-level interstitials only. Voluntary reward videos remain available and this must be stated alongside the purchase offer.

Only verified StoreKit transactions/current entitlements enable No Ads. The updates listener refreshes revoked/refunded entitlement state, and transactions are finished after processing. There is no UserDefaults unlock, fabricated price, or test-mode entitlement grant.

Validate with StoreKit sandbox or a dedicated Xcode StoreKit configuration: purchase success, cancellation, pending approval, restore on another installation, refund/revocation, offline launch with an existing verified entitlement, unavailable product, and No Ads retaining voluntary reward videos. Production purchase/restore cannot be claimed verified until the real product and signed app are provisioned and tested.

## Consumable coins

`CoinPack.catalog` maps three consumable product IDs to fixed currency amounts:

| Product ID | Coins |
| --- | ---: |
| `com.jonluca.prismroll.coins.1000` | 1,000 |
| `com.jonluca.prismroll.coins.5500` | 5,500 |
| `com.jonluca.prismroll.coins.15000` | 15,000 |

The local StoreKit fixture simulates USD 0.99, 4.99, and 9.99 solely for testing. Production prices and availability come from `Product.products(for:)`; display `Product.displayPrice`, and offer only the returned consumable products. Missing products must stay unavailable. The catalog and code cannot enable a product in App Store Connect.

Before loading the shop, configure `PurchaseService.configureCoinDelivery` with the wallet's throwing delivery method. The method receives a `CoinPurchase` containing the verified transaction ID, product ID, and quantity. `CoinPurchase.coins` validates the catalog and checks multiplication overflow. The wallet must atomically persist the resulting balance and transaction ID before returning `.credited(amount)`; an ID already in the persisted ledger returns `.alreadyDelivered`. Persistence failure must throw without changing the visible balance.

The service handles the immediate purchase result, `Transaction.updates`, and `Transaction.unfinished` during launch, shop refresh, and Restore. It calls `finish()` only after delivery succeeds, or after processing a verified revoked/expired transaction without granting currency. An absent wallet or failed save leaves the transaction unfinished for recovery. Cancelled, pending, unverified, wrong-product, and revoked purchases grant no coins. Repeated purchases of the same pack have different transaction IDs and are valid; repeated delivery of one transaction is not a second purchase.

Coins and the delivery ledger belong to this installation's saved game. Finished consumables are not replayed from transaction history or restored as an unused balance: that would recreate coins already spent. App deletion, loss of the local save, and playing on another device do not restore or synchronize that balance. No server or account-linked currency ledger exists. A refunded transaction never adds coins, but this local implementation does not claw back currency already delivered and spent before a refund. No Ads remains a separate non-consumable entitlement and Restore continues to refresh it.

`StoreKitCoinPurchaseTests` covers repeat purchases, product-provided prices, pending approval, cancellation, network failure, verification failure, failure-before-finish and cold-start recovery, missing-wallet recovery, revocation without another credit, multi-quantity transaction updates, and retaining No Ads. The local configuration is a test resource only and must never be shipped in the production app bundle. See Apple's [unfinished transaction sequence](https://developer.apple.com/documentation/storekit/transaction/unfinished) and [transaction finishing guidance](https://developer.apple.com/documentation/storekit/finishing-a-transaction).
