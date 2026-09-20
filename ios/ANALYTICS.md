# Prism Roll analytics

Prism Roll uses Google Analytics for Firebase on the free Firebase **Spark** plan. The integration measures opted-in players' sessions, gameplay, feature use, ads, and purchase attempts. The released 1.1.0 build 15 includes gameplay analytics. The September 20 attribution and StoreKit 2 revenue changes require a subsequent app binary.

| Resource | Value |
| --- | --- |
| Firebase project | `prism-roll` |
| Firebase dashboard | https://console.firebase.google.com/project/prism-roll/analytics |
| Google Analytics property | `554682731` |
| Google Analytics account | `90475221` |
| Analytics dashboard | https://analytics.google.com/analytics/web/#/p554682731 |
| iOS bundle | `com.jonluca.prismroll` |
| Firebase iOS app | `1:493066177072:ios:7e02a520b1df6667b5fbf5` |
| SDK | Firebase `12.19.2`, SPM product `FirebaseAnalyticsCore` |
| Website stream | `15812996264`, measurement ID `G-SKBTB9C5PL` |
| iOS stream | `15792271279` |
| BigQuery project | `prism-roll`, US sandbox, daily event export |

`PrismRoll/Resources/GoogleService-Info.plist` contains public client configuration, including the app identifier and client API key. It is embedded in the app and is not an administrator authentication secret. Never embed service-account private keys, OAuth tokens, or other administrative credentials.

## Questions and reports

| Question | How to examine it |
| --- | --- |
| How many people play and return? | Use Analytics' active-user, session, engagement, and retention reports. These cover players who opted in, not the entire installed audience. |
| Which features and modes are popular? | Inspect `screen_view`, `mode_selected`, and `daily_opened`; break gameplay events down by `game_mode` and `play_context`. |
| Where do players struggle? | In an Exploration, filter gameplay events by mode and level, then compare `level_start`, `level_resumed`, `level_end`, `level_failed`, `level_restarted`, `level_skipped`, and `hint_used`. Use `reason` for timeout versus move-limit failures. |
| How far do Time Rush rounds progress? | Compare `time_rush_maze_started` and `time_rush_maze_completed` by `level` and `stage_index`. Round wins are `level_end` with `game_mode=timed`. |
| Are rewards and the collection useful? | Inspect `earn_virtual_currency` by `source`, `spend_virtual_currency` by `item_id`, and `skin_unlocked`/`skin_equipped` by `rarity`. |
| Where do purchases or videos fall through? | Compare `purchase_started` with `purchase_result`, grouped by `product_id` and `result`; compare `ad_requested`, `ad_shown`, `ad_failed`, `ad_dismissed`, and `ad_reward_earned` by `placement`. |

The property has these **event-scoped custom dimensions**: `game_mode`, `play_context`, `level`, `stage_index`, `source`, `reward_type`, `result`, `product_id`, `placement`, `reason`, `item_id`, `rarity`, `button_placement`, and `apple_ct`. **Moves** is a custom metric backed by `moves`. Add the relevant dimensions, Event name, Event count, Total users, and Moves to a free-form Exploration. Standard reports and new custom definitions take time to populate; use DebugView for immediate development validation.

An event-count ratio is not automatically a player completion rate. Players can resume existing runs, repeat attempts, decline analytics, or enable it during a run. Use consistent mode/level filters and time windows; use user-based funnels when analyzing conversion.

## Event semantics

- `game_mode` uses Swift enum raw values: `endless`, `challenge`, and `timed` (the UI calls `timed` **Time Rush**). `play_context` is `solo`, `daily`, or `duel`.
- `level_start` occurs on the first accepted move of a fresh board, not when opening a screen. Blocked and stale inputs do not count. An existing board with moves records `level_resumed` on its next accepted move after restoration or a mode switch.
- Time Rush records one round start on the first maze and one successful `level_end` after the final maze. Intermediate boards use the maze-specific events. `stage_index` starts at 1.
- `moves` is the current board's move count. On a Time Rush `level_end`, it describes only the final maze, not the total moves across the round. Filter to one event type before interpreting the Moves metric; summing it across starts, hints, failures, and completions double-counts progress.
- `level_end` has `success=1`. Failure is `level_failed` with `reason=time_expired` or `move_limit`; it is not a terminal round result because the player can revive. `level_revived` records an actual transition out of failure. Restoring a completed board does not emit another win.
- `daily_opened` measures opening or reopening the daily challenge. Its `resumed` parameter describes the existing board; it is not proof of accepted play.
- `hint_used` records a hint actually shown. `source` distinguishes `free` and `rewarded_video`. `gameplay_reward_earned` includes the reward type.
- Currency uses standard `earn_virtual_currency`/`spend_virtual_currency`, `virtual_currency_name=coins`, and `value` equal to the credited/spent amount. Earning sources include `maze_pickup`, `level_completion`, `daily_maze`, `daily_login`, `milestone`, `rewarded_video`, `completion_bonus`, and `purchase`. Collectible coins are included. Successful persistence and existing reward ledgers prevent repeated claims from creating duplicate currency events.
- Purchase events describe explicit attempts and their outcomes, including cancellation, pending approval, unavailability, verification failure, or delivery pending. Restore and transaction recovery do not create another purchase-attempt funnel. They are not revenue totals. The consent-gated StoreKit 2 bridge sends verified delivered purchases with Firebase’s `Analytics.logTransaction`; a prospective consent period and local transaction ledger prevent historical backfill and duplicate delivery. Custom attempt events omit transaction identifiers; the Firebase transaction API owns transaction-derived revenue fields. See [native attribution and revenue](ATTRIBUTION_REVENUE.md).
- Ad requests describe a request to present a video/interstitial, not every background SDK load. Frequency suppression and No Ads do not count as failed interstitial requests. Placements are `gameplay`, `completion_bonus`, `coin_shop`, and `level_transition`. Reward events require the SDK's earned-reward callback.

## Consent and development

First launch offers **Share usage data** or **Not now**. Settings → **Share usage analytics** changes the choice. Consent is persisted separately from game progress under `prismroll.analytics.enabled`; clearing game saves does not change it. Firebase is initialized only after an explicit opt-in to analytics or the separate saved-and-future crash report setting. Starting Firebase for diagnostics does not grant analytics consent; its transport clears any stale Analytics collection override before configuration when analytics is not permitted. Disabling stops collection and resets local analytics data/its installation identifier; it does not delete reports already received by Google.

Custom gameplay analytics sends no name, email, Game Center identity, transaction identifier, saved maze layout, IDFA, or IDFV. Firebase’s StoreKit 2 revenue API receives verified transaction information when analytics consent permits it; do not apply the custom-event exclusions to SDK transaction reporting. Firebase uses a random app-instance identifier, app/device information, and approximate location derived from network information. This is installation-based analytics, not anonymous aggregate-only collection.

The SDK product excludes IDFA support. Info.plist disables IDFV, collection by default, automatic screen reporting, and all default consent categories. Runtime consent grants only analytics storage; advertising storage, advertising user data, and ad personalization stay denied. `GOOGLE_ANALYTICS_TCF_DATA_ENABLED=false` keeps the separate ad-consent flow from supplying Analytics consent.

Ordinary Debug launches suppress Firebase initialization and events. The separate `--diagnostics-debug` flag permits consented Crashlytics smoke checks while leaving usage analytics disabled unless its own runtime flag and consent are also present. For a **manual** simulator/device smoke check, launch with:

```text
--analytics-debug -FIRDebugEnabled
```

Opt in, navigate tabs, play a level, and inspect the configured property's DebugView. Check event parameters and consent logs. Then turn sharing off, interact again, and confirm no further app events are collected. Relaunch to verify the choice persists. Remove the debug arguments afterward (Firebase's `-FIRDebugDisabled` disables its debug mode). XCTest and `--uitesting` always suppress analytics, even with the debug opt-in flag; automated tests use injected recorders and cannot prove server receipt.

## Validation and release status

As of September 16, 2026, the final focused simulator run passed **56 tests with zero failures** (7 consent/service, 9 gameplay analytics, 6 commerce analytics, 15 lifecycle, and 19 Time Rush tests). Evidence: `/tmp/prism-analytics-test-final.log` and `/tmp/PrismRollAnalyticsDerivedData/Logs/Test/Test-PrismRoll-2026.09.16_15-24-20--0700.xcresult`. Bundled Firebase config, consent flags, and all five analytics privacy declarations were verified in the built app. The separate release task subsequently reported **99 passing combined native tests**, including all three analytics suites. **Live server receipt is verified**: an isolated simulator launch with temporary consent enabled produced `first_open`, `session_start`, `user_engagement`, and `screen_view` in Firebase DebugView; the expanded screen event showed `firebase_screen=play` and `non_personalized_ads=1`. A second launch with temporary consent disabled produced no Firebase startup/collection-enabled logs and no additional observed events. These launch-configuration checks do not verify the actual consent buttons, Settings opt-out, or saved-choice persistence through the UI. Evidence: `release/analytics/live-sdk-verification.json` and adjacent SDK logs. The remaining manual interaction check is pending because Device Hub computer-control calls time out.

The updated [public privacy policy](https://thoughtahead.com/prism-roll/privacy.html) was deployed and verified byte-for-byte against `thoughtahead/public/prism-roll/privacy.html` on September 16, 2026 (Vercel deployment `dpl_2sajLgqUAEnwPBd4VryUSosExt7k`). This setup does not publish a new App Store or TestFlight build; the separate growth task is coordinating the combined app release. Before distributing it, finish the consent UI interaction check and reconcile App Store privacy disclosures with the in-app policy and `PrivacyInfo.xcprivacy`. The manifest includes analytics product interaction, purchase history, advertising data, installation identifiers, and coarse location; existing advertising and Game Center disclosures remain separate. Google signals is off. Property-level ads personalization was disabled for all 307 regions and the saved state verified. No advertising account links were added in that September 16 setup; the September 20 AdMob link is recorded below. The existing shared JonLuca Google Analytics account has Google products/services data sharing enabled; its account-wide preferences were left unchanged because they also apply to other properties.

On September 16, 2026, the analytics task published **Purchase History** in App Store Connect for Analytics, linked to the user and not used for tracking. The signed-in publication check recorded the published state and preservation of all nine existing data types. Evidence is `release/analytics/app-store-privacy-publication.json`. This resolves the earlier missing-purchase-history finding; it does not establish that the separate Crashlytics additions are ready for distribution. Follow `DIAGNOSTICS.md` before a release containing diagnostics.

References: [Firebase collection controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection), [Firebase disclosure guidance](https://support.google.com/analytics/answer/10285841), [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/).

## Conversion setup — September 20, 2026

The existing GA4 property now contains a **Prism Roll website** stream for `https://playprismroll.com`. Enhanced Measurement is off. The website implementation was deployed to `playprismroll.com` (Vercel `dpl_FtFxstpDKj1Jw6gjakSDCNpLcbt5`). A clean browser UI smoke test received Google HTTP 204 for one untagged `page_view` and one hero `app_store_click`; withdrawal removed its two cookies and tag and produced no additional Google requests. These two QA events are test activity, not customer acquisition. Initial GA4 Realtime readback showed no events, so actual reporting receipt remains pending despite successful transport. The implementation loads Google only after an explicit website analytics choice, sends a fixed query-free page address, suppresses referrer/cross-domain identity sharing, and measures `page_view` plus `app_store_click` by `button_placement` and allowlisted `apple_ct`. Website consent is separate from app consent. App Store clicks are outbound intent, not installs. `app_store_click` is a saved key event counted once per session, without a default monetary value.

AdMob app `ca-app-pub-8314265628354618~3970821518` was associated with public App Store ID `6809253424`, successfully verified, and linked to iOS stream `15792271279`. AdMob displayed **Getting ready / Review in progress / Limited ad serving**. Its review is external and not complete. Firebase’s missing App Store ID was filled with `6809253424`; AdMob’s Firebase linked-service state then read **Linked**. The account’s impression-level ad revenue switch was enabled, saved, and read back as **On**. The Firebase integration can automatically measure `ad_impression` revenue; a real monetized impression has not yet been verified. Do not duplicate this event using a separate paid-event handler.

BigQuery linking succeeded for project `prism-roll`, US location, with both current data streams selected and no events excluded. Daily event export is on; streaming, advertising identifiers, and separate user-data export are off. The project remains Spark/no-cost. At setup the dataset had not yet been created: first export is pending, so no warehouse query or populated dashboard is claimed. The sandbox UI states **60-day data expiry, 1 TiB queries per month, and a 10 GiB lifetime storage limit**; deleting or expiring data does not restore its lifetime export quota. This is not a permanent archive.

The read-only [Apple acquisition collector](scripts/acquisition/README.md) follows the existing ongoing request, keeps hashes and whole-Date corrections, and writes a local report, HTML dashboard, CSV and BigQuery-shaped JSONL under ignored `release/acquisition/`. Apple acquisition, web clicks and opted-in app behavior remain separately labeled populations. There is no shared user identity or defensible automatic click-to-install conversion rate. See the collector’s SQL templates for activation, progression, calendar-day retention and aggregate comparison definitions.

The saved [Prism Roll — opted-in activation & retention exploration](https://analytics.google.com/analytics/web/?authuser=0&hl=en-US#/analysis/a90475221p554682731/edit/yr8C1U_GT0SbkN9kbcK8Rw) was reloaded and verified. **Ordered Classic progression** is a closed funnel from `first_open` through the first move on Classic solo level 1, then level 1/3/5 completion, restricted to iOS stream `15792271279`. The UI funnel has no overall 24-hour constraint; use the SQL template for that definition. **D1/D7 — active session return** uses a daily Standard cohort, `first_open` inclusion, `session_start` return, Active users, and the iOS-stream segment. It is narrower than the SQL's foreground-return definition, and both measure opted-in installations rather than all downloads. New definitions, report processing, and sparse data can leave these views unpopulated.

The existing **Prism Roll acquisition tracking** task automation runs daily at **09:00 America/Los_Angeles**, checking Apple report changes, initial website reporting receipt, BigQuery export readiness, AdMob review, and AppsFlyer receipt/quota/expiry. It stays quiet for unchanged or non-actionable state. It does not enable billing, launch campaigns, or submit app releases.

The owner subsequently requested the free AppsFlyer plan. The account email is confirmed, Prism Roll is registered, and its issued developer key is stored privately. Its Strict SDK integration uses separate attribution consent and remains keyless in clean CI; a real QA session and fresh-install conversion received HTTP 200. The refreshed Marketing Overview for Prism Roll, filtered to September 20 UTC, subsequently showed **1 Organic install** in its metric and chart. This verifies internal QA install-report receipt, not customer acquisition, session reporting, or paid/link attribution; active users and revenue still showed **No data found**. No enabled App Store binary has been released by this setup. Existing Google-only consent does not enable the new provider. See [AppsFlyer setup](APPSFLYER_SETUP.md) for the account, validation and disclosure boundary. Its welcome install-attribution allowance expires after one year or 12,000 conversions; the ongoing free Zero tier covers clicks and impressions, not install attribution. No advertising spend or billing was enabled.
