# Prism Roll analytics

Prism Roll uses Google Analytics for Firebase on the free Firebase **Spark** plan. The integration measures opted-in players' sessions, gameplay, feature use, ads, and purchase attempts. Existing installed versions need a new app binary before they can send these events.

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

The property has these **event-scoped custom dimensions**: `game_mode`, `play_context`, `level`, `stage_index`, `source`, `reward_type`, `result`, `product_id`, `placement`, `reason`, `item_id`, and `rarity`. **Moves** is a custom metric backed by `moves`. Add the relevant dimensions, Event name, Event count, Total users, and Moves to a free-form Exploration. Standard reports and new custom definitions take time to populate; use DebugView for immediate development validation.

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
- Purchase events describe explicit attempts and their outcomes, including cancellation, pending approval, unavailability, verification failure, or delivery pending. Restore and transaction recovery do not create another purchase-attempt funnel. They are not revenue totals; Firebase handles its automatic purchase measurement separately. Custom events never include transaction identifiers or payment details.
- Ad requests describe a request to present a video/interstitial, not every background SDK load. Frequency suppression and No Ads do not count as failed interstitial requests. Placements are `gameplay`, `completion_bonus`, `coin_shop`, and `level_transition`. Reward events require the SDK's earned-reward callback.

## Consent and development

First launch offers **Share usage data** or **Not now**. Settings → **Share usage analytics** changes the choice. Consent is persisted separately from game progress under `prismroll.analytics.enabled`; clearing game saves does not change it. Firebase is initialized only after an explicit opt-in to analytics or the separate saved-and-future crash report setting. Starting Firebase for diagnostics does not grant analytics consent; its transport clears any stale Analytics collection override before configuration when analytics is not permitted. Disabling stops collection and resets local analytics data/its installation identifier; it does not delete reports already received by Google.

Analytics sends no name, email, Game Center identity, transaction identifier, saved maze layout, IDFA, or IDFV. Firebase uses a random app-instance identifier, app/device information, and approximate location derived from network information. This is installation-based analytics, not anonymous aggregate-only collection.

The SDK product excludes IDFA support. Info.plist disables IDFV, collection by default, automatic screen reporting, and all default consent categories. Runtime consent grants only analytics storage; advertising storage, advertising user data, and ad personalization stay denied. `GOOGLE_ANALYTICS_TCF_DATA_ENABLED=false` keeps the separate ad-consent flow from supplying Analytics consent.

Ordinary Debug launches suppress Firebase initialization and events. The separate `--diagnostics-debug` flag permits consented Crashlytics smoke checks while leaving usage analytics disabled unless its own runtime flag and consent are also present. For a **manual** simulator/device smoke check, launch with:

```text
--analytics-debug -FIRDebugEnabled
```

Opt in, navigate tabs, play a level, and inspect the configured property's DebugView. Check event parameters and consent logs. Then turn sharing off, interact again, and confirm no further app events are collected. Relaunch to verify the choice persists. Remove the debug arguments afterward (Firebase's `-FIRDebugDisabled` disables its debug mode). XCTest and `--uitesting` always suppress analytics, even with the debug opt-in flag; automated tests use injected recorders and cannot prove server receipt.

## Validation and release status

As of September 16, 2026, the final focused simulator run passed **56 tests with zero failures** (7 consent/service, 9 gameplay analytics, 6 commerce analytics, 15 lifecycle, and 19 Time Rush tests). Evidence: `/tmp/prism-analytics-test-final.log` and `/tmp/PrismRollAnalyticsDerivedData/Logs/Test/Test-PrismRoll-2026.09.16_15-24-20--0700.xcresult`. Bundled Firebase config, consent flags, and all five analytics privacy declarations were verified in the built app. The separate release task subsequently reported **99 passing combined native tests**, including all three analytics suites. **Live server receipt is verified**: an isolated simulator launch with temporary consent enabled produced `first_open`, `session_start`, `user_engagement`, and `screen_view` in Firebase DebugView; the expanded screen event showed `firebase_screen=play` and `non_personalized_ads=1`. A second launch with temporary consent disabled produced no Firebase startup/collection-enabled logs and no additional observed events. These launch-configuration checks do not verify the actual consent buttons, Settings opt-out, or saved-choice persistence through the UI. Evidence: `release/analytics/live-sdk-verification.json` and adjacent SDK logs. The remaining manual interaction check is pending because Device Hub computer-control calls time out.

The updated [public privacy policy](https://thoughtahead.com/prism-roll/privacy.html) was deployed and verified byte-for-byte against `thoughtahead/public/prism-roll/privacy.html` on September 16, 2026 (Vercel deployment `dpl_2sajLgqUAEnwPBd4VryUSosExt7k`). This setup does not publish a new App Store or TestFlight build; the separate growth task is coordinating the combined app release. Before distributing it, finish the consent UI interaction check and reconcile App Store privacy disclosures with the in-app policy and `PrivacyInfo.xcprivacy`. The manifest includes analytics product interaction, purchase history, advertising data, installation identifiers, and coarse location; existing advertising and Game Center disclosures remain separate. Google signals is off. Property-level ads personalization was disabled for all 307 regions and the saved state verified. No advertising account links were added. The existing shared JonLuca Google Analytics account has Google products/services data sharing enabled; its account-wide preferences were left unchanged because they also apply to other properties.

On September 16, 2026, the analytics task published **Purchase History** in App Store Connect for Analytics, linked to the user and not used for tracking. The signed-in publication check recorded the published state and preservation of all nine existing data types. Evidence is `release/analytics/app-store-privacy-publication.json`. This resolves the earlier missing-purchase-history finding; it does not establish that the separate Crashlytics additions are ready for distribution. Follow `DIAGNOSTICS.md` before a release containing diagnostics.

References: [Firebase collection controls](https://firebase.google.com/docs/analytics/ios/configure-data-collection), [Firebase disclosure guidance](https://support.google.com/analytics/answer/10285841), [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/).
