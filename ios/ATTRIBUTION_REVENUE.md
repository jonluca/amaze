# Native attribution and purchase revenue

This source change requires a new iOS release. It does not configure or spend on Apple Ads or establish that a paid campaign has attributed a real installation. The [AppsFlyer integration](APPSFLYER_SETUP.md) now has a confirmed free Welcome account and a privately stored real developer key. Genuine-key QA session and fresh-install requests received HTTP 200; dashboard report receipt and an enabled App Store release remain outstanding.

## Apple Ads

The app links Apple's `AdServices.framework`. Firebase Analytics has built-in Apple Ads attribution support when that framework is linked, so the app does not request attribution tokens, call an attribution endpoint, or emit a second campaign event itself. It keeps `FirebaseAnalyticsCore`, disabled IDFV collection, and denied advertising-storage, advertising-user-data, and personalization consent. No IDFA/ATT capability is added.

The existing analytics consent and runtime controls still apply. Analytics collection starts only after usage-analytics opt-in; ordinary Debug, XCTest, and UI tests cannot enable it. A diagnostics-only Firebase initialization explicitly keeps Analytics disabled and its consent denied. The app does not weaken those controls to obtain attribution. Analytics opt-in can happen later than installation, and attribution may be unavailable under the current consent settings; absence is not proof of an organic install.

Firebase disables its Apple Search Ads reporter on the simulator. The required end-to-end check is a signed new build installed through a real Apple Ads campaign on a physical device, with usage analytics enabled, followed by GA4 acquisition readback. Framework linkage and tests demonstrate integration readiness only.

## StoreKit 2 revenue

StoreKit 2 purchases require `Analytics.logTransaction(transaction)`; custom `purchase_started` and `purchase_result` events are attempt/outcome diagnostics, not revenue. `PurchaseService` now forwards verified, active transactions through `PurchaseAnalyticsRecording` after No Ads entitlement validation or successful durable coin delivery. Firebase's transport calls the StoreKit-specific API rather than manually emitting `purchase` or `in_app_purchase`.

`AnalyticsService` checks the existing opt-in/runtime gate and retains a local transaction-ID ledger to suppress repeated delivery/update/recovery calls across launches. Transactions observed while opted out are also marked handled locally and never replayed when analytics is enabled. A persisted opt-in-period start excludes older purchases and fresh-install restores; an existing opt-in migrates prospectively on first launch of this version. Re-enabling analytics begins a new period. The ledger survives opt-out so resetting the Firebase identifier cannot duplicate prior purchases.

Cancelled, pending, unverified, revoked, and undelivered purchases do not report revenue. An approved pending purchase or recovered coin transaction can report after successful delivery, provided its purchase date falls within the current analytics participation period. No finished purchase history is enumerated for reporting. This is best-effort client telemetry, not an accounting ledger or a replacement for Apple's financial reports. The local deduplication mark precedes SDK enqueueing; a process interruption at that boundary can lose an event rather than double-count it. Device-clock discrepancies can also affect the prospective date check.

## Ad revenue

The console setup task verified the AdMob-to-GA4 link on September 20, 2026, targeting iOS stream `15792271279`, after attaching App Store ID `6809253424` to the AdMob app. App verification succeeded; AdMob review is still in progress. Google's supported AdMob integration measures `ad_impression` and ad revenue automatically. Do not add another `paidEventHandler` that emits the same Firebase event. The existing custom `ad_shown`/`ad_reward_earned` funnel remains separate from monetary revenue. Real monetized-impression receipt still needs verification after AdMob approves serving.

## Validation and privacy

`PurchaseRevenuePolicyTests` covers prospective consent periods, duplicate delivery, recreation, historical restores, and suppression across an SDK identifier reset without depending on StoreKit. `AnalyticsServiceTests` covers the existing SDK initialization and consent/runtime boundaries. Additional `PurchaseRevenueAnalyticsTests` exercises the service bridge with local StoreKit fixtures and an injected transport, including successful No Ads/coin purchases, durable-delivery recovery, and failed/pending/unverified attempts. These tests do not send events to Firebase or prove production revenue receipt. Before release, verify the built app links AdServices, retains all collection/advertising privacy flags, and verify a consenting StoreKit sandbox purchase appears once in Firebase without manually logging another revenue event. No sandbox purchase is production revenue.

The in-app source policy (`PrismRoll/Views/PrivacyPolicyView.swift`, updated September 20) now explicitly includes optional Apple Ads acquisition attribution, verified purchase product/value/currency and transaction-derived fields, and ad impression revenue. It retains the existing opt-in, advertising-identifier/vendor-identifier exclusions, denied advertising consent, and independent crash-sharing controls. Its purchase paragraph explains prospective reporting, older-restore exclusion, and the local deduplication record. Matching public policy wording was deployed and verified at both `playprismroll.com` and the legacy ThoughtAhead privacy URL on September 20.

The existing app privacy manifest already declares Purchase History and Advertising Data for Analytics, linked to the user, not tracking; these fields and all existing privacy flags remain unchanged. App Store privacy disclosures must remain consistent with the combined app and SDK collection. The SDK owns transaction reporting and attribution data; do not claim that Firebase's standard events exclude transaction-derived fields merely because custom gameplay events do. All Firebase reports still represent consenting installations, not every App Store download.

Local validation on September 20, 2026: the app and test targets compiled with Xcode 27.0, and all 12 selected consent/policy tests passed on iOS 26.5. Binary inspection confirmed AdServices linkage and all seven Analytics/IDFV/TCF/default-consent flags remain false. The seven new StoreKit integration cases compile but have not completed: the local StoreKitTest service failed in an unchanged commerce test (`SKInternalErrorDomain`, code 3); a matching iOS 27 attempt also could not establish a purchase UI anchor. No StoreKit integration pass or Firebase receipt is claimed. Evidence is retained in `release/tracking-2026-09-20/native/` (ignored local artifacts).

This local build used an existing, unrelated working-tree upgrade to Google Mobile Ads **13.10.0**. The scoped tracking commit preserves the repository's committed **13.9.0** dependency and leaves the upgrade unstaged. Validate the exact selected dependency state again when preparing the next production release.

Official references checked September 20, 2026:

- [Firebase release notes: AdServices support in 10.6.0](https://firebase.google.com/support/release-notes/ios#version_1060_-_february_28_2023)
- [Firebase StoreKit 2 purchase measurement](https://firebase.google.com/docs/analytics/ios/measure-in-app-purchases)
- [Firebase automatic AdMob revenue measurement](https://firebase.google.com/docs/analytics/measure-ad-revenue)
- [Firebase collection and consent controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection)
