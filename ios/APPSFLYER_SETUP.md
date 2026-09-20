# AppsFlyer free setup

Status on September 20, 2026: the free signup form is open, but account creation still requires the owner's contact details, password creation and acceptance of AppsFlyer's terms. No payment details, paid upgrade or advertising campaign have been entered. No AppsFlyer account, app record, developer key, real session receipt or production release is claimed yet.

## Free plan boundary

New accounts receive the Welcome package: up to 12,000 measured conversions or one year, whichever comes first, plus 30 days of selected premium add-ons. Without adding billing or upgrading, the account transitions to Zero. Zero remains free but measures clicks and impressions rather than install attribution. Record the actual start date, expiry and remaining allowance from the account dashboard after signup; do not infer an expiry from this preparation date. Do not build a permanent dependency on the temporary raw-data API trial.

Sources: [plan and billing details](https://support.appsflyer.com/hc/en-us/articles/115000136303-Account-management-plans-payments-and-billing), [pricing](https://www.appsflyer.com/pricing/).

## Account activation

1. Complete [free signup](https://www.appsflyer.com/start/zero/) without a payment method. The owner must create the password and accept the terms.
2. Verify the account shows Welcome/free and no billing method or paid add-ons.
3. Register the published iOS app **Prism Roll**, Apple ID **6809253424**, bundle **com.jonluca.prismroll**. Use its actual App Store listing and verify the resulting app record.
4. Obtain the account's SDK developer key. It is distinct from an administrative API token; basic SDK initialization does not require generating an API token or granting a new integration account.
5. Supply the real developer key as the `APPSFLYER_DEV_KEY` Xcode build setting. Confirm the resulting built app's `PrismAppsFlyerDevKey` is populated without printing it into logs. Do not use a placeholder key or claim a keyless build is connected.
6. Confirm the prepared privacy policy and App Store disclosures match the final native configuration before distributing an enabled binary.
7. On a designated test installation, verify the opt-in and opt-out UI, real session receipt in the correct AppsFlyer app, lifecycle behavior and no new requests after withdrawal. Separate QA traffic from acquisition reports. SDK compilation and mocked-transport tests cannot prove provider receipt.

## Integration boundary

The implementation uses AppsFlyer's Strict iOS SDK to omit advertising-identifier code. It additionally disables vendor-identifier collection, SKAdNetwork activity, TCF collection and downstream partner sharing. It does not forward customer identifiers, contact details, Game Center identities, shared-maze URLs, purchase transactions or ad revenue. Google Analytics remains responsible for the existing gameplay and revenue reporting.

AppsFlyer still processes an installation identifier and app/device/network/session information after affirmative consent. This is not anonymous aggregate-only collection. Existing consent that named only Google must not silently authorize AppsFlyer. Existing users need a new attribution choice; a configured new installation can disclose both providers in its initial choice. The attribution choice also requires usage analytics to be enabled. Ordinary Debug, XCTest and UI-test runs remain unable to transmit. Missing configuration leaves AppsFlyer inactive without disabling Google Analytics.

Withdrawal prevents the app from starting further AppsFlyer sessions and uses the SDK stop control. It does not delete prior provider reports or reset the AppsFlyer installation identifier. Firebase's existing identifier-reset behavior remains separate. Re-enabling attribution must not issue duplicate starts within the same foreground cycle. Verify stop/resume network behavior against the exact pinned SDK: the generic online documentation and version-specific header describe parts of that behavior differently.

The default source configuration is intentionally inert until the actual account key is supplied. Registering an account or adding the SDK does not alter the currently released App Store binary; enabling the integration for customers requires a new release.

## Disclosure review before release

The existing app manifest covers Product Interaction, Purchase History, Advertising Data, Device ID, Coarse Location and Crash Data. The saved App Store disclosure also includes performance information. AppsFlyer's nutrition-label guidance additionally puts some technical/network information and its installation identifier under **Other Data Types**, which is absent from the current disclosure snapshot. Reconcile the exact enabled SDK's data and purposes with Apple's categories before release; do not assume the SDK's small embedded privacy manifest is a complete disclosure. No App Store privacy publication was changed during this preparation.

The public policy update is prepared at `release/analytics/appsflyer-2026-09-20/prism-appsflyer-public-policy.patch` and must be applied with the completed integration. It names AppsFlyer, the new consent control, the data boundary and withdrawal limitations. Existing Google Analytics, Crashlytics, advertising and Game Center explanations remain intact. The website policy has not been changed or deployed for AppsFlyer yet.

## Local validation

The keyless app and tests compiled with Strict SDK **7.0.2**. All **22 focused tests** passed: 10 attribution consent/readiness cases, 7 existing analytics cases, and 5 purchase-revenue policy cases. They cover old consent migration, both required choices, withdrawal, saved preferences, ordinary Debug/test suppression, absent/template configuration, independent Firebase behavior, and stale readiness after withdrawal/re-enable. Test configuration values only reach injected recorders; they are never used with the real SDK. Swift formatting and lint checks passed.

These tests used the existing unrelated working-tree Google Mobile Ads **13.10.0** upgrade, which is not part of the AppsFlyer change. No real AppsFlyer initialization or network test was attempted without an issued account key. No release archive, production upload, installation attribution or dashboard receipt is claimed. Local log: `/tmp/PrismRollAppsFlyerConsent.log`; result bundle: `/tmp/PrismRollAppsFlyerConsent.xcresult`.

Implementation references: [Strict SDK installation](https://dev.appsflyer.com/hc/docs/install-ios-sdk-7), [initialization and session lifecycle](https://dev.appsflyer.com/hc/docs/integrate-ios-sdk-7), [privacy controls](https://dev.appsflyer.com/hc/docs/preserve-user-privacy-ios-7), [AppsFlyer services privacy policy](https://www.appsflyer.com/legal/services-privacy-policy/).
