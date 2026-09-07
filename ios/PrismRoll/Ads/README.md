# Ads integration

`AdService` uses Google Mobile Ads and Google's User Messaging Platform (UMP). It is owned by the app on the main actor. The app starts and levels remain playable when consent, ad inventory, or connectivity is unavailable. No local timer or fake ad grants a reward.

## Project dependencies

The implementation was checked against these official Swift packages:

| Repository | Version | Xcode package product | Swift module |
| --- | --- | --- | --- |
| `https://github.com/googleads/swift-package-manager-google-mobile-ads.git` | 13.9.0 | `GoogleMobileAds` | `GoogleMobileAds` |
| `https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git` | 3.1.0 | `GoogleUserMessagingPlatform` | `UserMessagingPlatform` |

Mobile Ads already depends on UMP; pinning the latter explicitly keeps the Swift API stable. Include `-ObjC` in the target's linker flags.

## App wiring

- Create one app-owned `@StateObject` instance of `AdService`.
- Call `prepare()` after the root view appears, on returning to the foreground, and at level transitions. Duplicate work is coalesced; failed ad loads retry only on later calls and at least 30 seconds after the failure. A successfully consumed ad can refill immediately. Changed-consent cancellation does not count as a load failure, and canceled work rechecks current consent before loading its replacement.
- Call `presentInterstitial(onDismiss:)` exactly once from each completed level's Continue action. Advance in `onDismiss`. The service becomes eligible after four completions and, after any full-screen ad, at least 90 seconds since dismissal. The 90-second minimum is this app's product choice, not a Google-mandated interval. Unavailable ads call the continuation immediately. Ads never appear from a delayed load callback, during gameplay, at launch, or after failure/retry.
- Offer voluntary hints, time extensions, move extensions, skips, or completion bonuses only when `canShowRewarded` is true. Capture the corresponding game reward request before presentation. Call `presentRewarded(onReward:onDismiss:)`; apply the captured request only in `onReward`, and release the gameplay pause in `onDismiss`. The dismissal callback runs exactly once for an accepted attempt, including unavailable inventory, immediate presentation failure, early close, and earned-reward close. Closing alone never grants a reward. Persist completion bonus claims separately.
- Disable Continue and the reward button while `isPresenting`; do not request a second presentation while one is active. A rewarded presentation resets the interstitial interval so Continue does not immediately show another ad.
- When `privacyOptionsRequired` is true, show an accessible Settings action labeled “Ad privacy choices” that calls `presentPrivacyOptions()`.
- Render `rewardedAvailability` beside each optional reward: loading disables the action with a progress indicator, ready offers “Watch ad”, and unavailable offers an explicit inline retry. Retry calls `prepare()` without pausing gameplay, promising a reward, or opening a failure alert. Keep `statusMessage` available in Settings for more detail.
- Pause active countdowns while `isPresenting`, `isPrivacyFormPresenting`, or a gameplay reward request is pending. Consent UI and early ad dismissal must not consume play time.
- Set `interstitialsDisabled` from the verified StoreKit No Ads entitlement. Disabled interstitials do not load or display and Continue runs immediately; voluntary rewarded videos are unchanged.

## Development

Debug builds use Google's published iOS test ad units:

- Rewarded: `ca-app-pub-3940256099942544/1712485313`
- Interstitial: `ca-app-pub-3940256099942544/4411468910`
- Sample `GADApplicationIdentifier`: `ca-app-pub-3940256099942544~1458002511`

Debug launch arguments `--uitesting` and `--no-ads` disable all ad and consent requests. Interstitial transitions continue immediately without advancing the ad frequency counter. Release builds ignore these flags.

The UMP check still runs in Debug. Google's shared sample app ID does not guarantee a configured publisher consent message; if UMP reports a configuration error and `canRequestAds` is false, no advertising SDK is started and no ad request is sent. For complete consent and test-ad validation, use your own registered AdMob app ID with published privacy messages while keeping the Debug test ad-unit IDs. Add physical devices as test devices in AdMob/SDK configuration before testing production units. Simulator traffic is automatically treated as test traffic by Google.

## Production configuration

Release builds stay ad-free unless all three Info.plist values contain publisher-owned IDs:

```xml
<key>GADApplicationIdentifier</key>
<string>YOUR_ADMOB_APP_ID</string>
<key>PrismRewardedAdUnitID</key>
<string>YOUR_REWARDED_AD_UNIT_ID</string>
<key>PrismInterstitialAdUnitID</key>
<string>YOUR_INTERSTITIAL_AD_UNIT_ID</string>
```

Set the app ID to the AdMob **app** identifier containing `~`; ad units contain `/`. The bundled sample IDs are explicitly rejected in Release. Add `SKAdNetworkItems` with Google's `cstr6suwn9.skadnetwork` and the current buyer identifiers listed in Google's setup guide.

Before enabling production ads:

1. Register the app and ad units in your AdMob account, connect the correct App Store listing, and publish the privacy messages applicable to the app and its audience in AdMob's Privacy & messaging section. No account-side setup is performed by this code.
2. Configure rewarded ad units consistently with the on-screen offer (hint, time, moves, skip, or coin bonus). Rewards are local gameplay benefits with no cash value; this implementation uses Google's client reward callback. Use server-side reward verification if rewards later become transferable or economically valuable.
3. Publish an app-specific privacy policy, complete the App Store privacy questionnaire based on the SDKs and account configuration actually shipped, and configure any child-directed or under-age treatment appropriate to the app's intended audience before SDK initialization.
4. This integration does not request ATT authorization or access IDFA directly. If a tracking flow is introduced, implement its ATT and disclosure requirements before enabling that behavior.
5. Validate consent-required, consent-not-required, revoked/changed consent, offline, no-fill, early dismissal, earned reward, presentation failure, background/foreground, and four-level interstitial cadence on device. Real ad serving still depends on Google's account approval, privacy configuration, network access, and inventory.

## Consent and reward safeguards

UMP updates at every app launch. The service checks UMP's live `canRequestAds` before initializing Google Mobile Ads, loading ads, and presenting ads. Consent failures can use UMP's valid prior-session choice; otherwise ads remain off. Privacy options invalidate cached ads and outstanding results before applying a changed choice. Cached ads are rejected after 55 minutes. A reward callback is tied to its active ad and consumed before application code runs. Closing, failing, or skipping an ad cannot invoke that callback.

## Official references

- [SDK setup, Info.plist, and SKAdNetwork identifiers](https://developers.google.com/admob/ios/quick-start)
- [UMP consent and privacy options](https://developers.google.com/admob/ios/privacy)
- [Rewarded ads and test ID](https://developers.google.com/admob/ios/rewarded)
- [Interstitial ads and test ID](https://developers.google.com/admob/ios/interstitial)
- [Rewarded prompt design and clear value exchange](https://admob.google.com/home/resources/rewarded-ads-playbook/)
- [Recommended interstitial placement and latency](https://support.google.com/admob/answer/6201350)
- [Apple advertising requirements, section 2.5.18](https://developer.apple.com/app-store/review/guidelines/#software-requirements)
- [Enable test ads](https://developers.google.com/admob/ios/test-ads)
