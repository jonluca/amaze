# Validation — September 6, 2026

## Current release preparation

The release configuration is build **2**. The production AdMob app, rewarded, and interstitial identifiers have been verified and configured; Debug retains Google's test units. Live publisher ad delivery and production consent behavior remain unverified. Requests use non-personalized ads and global restricted data processing, with publisher first-party ID and personalization disabled; Google-only demand is the intended first-release account configuration.

The App Store record and `com.jonluca.prismroll.removeads` non-consumable product have been created. A signed verification archive was produced with a beta SDK. No build has been uploaded or submitted; an App Store-eligible final archive is still required.

**Unsigned generic iOS Release build 2 passed in 11.6 seconds.** Output: `artifacts/ProductionConfigBuild2/Build/Products/Release-iphoneos/PrismRoll.app`; verification: `artifacts/ProductionConfigBuild2/verification.json`. The artifact is version **1.0.0 (2)**, **arm64**, built with SDK **iphoneos27.0**. All three exact production AdMob identifiers are present and accepted by the Release guard. The four Debug bypass strings and local StoreKit fixture are absent, and the configured support/privacy URLs are compiled in. These artifact checks do not establish live ad delivery, purchase operation, or URL reachability.

The configured public URLs are [support](https://thoughtahead.com/prism-roll/support.html) and [privacy policy](https://thoughtahead.com/prism-roll/privacy.html). Publication and reachability have not yet been verified in this checkpoint.

## Historical feature-expansion checkpoint

Built with Xcode 27.0 / Swift 6.4, targeting iOS 17. The reference evidence and unknowns are documented in [FEATURE_AUDIT.md](FEATURE_AUDIT.md). This audit used Apple's public listing, official screenshots/version history, and the user's direct feature observations; it was not an installed-app walkthrough.

- Debug simulator build passes.
- Release generic iOS build passed at this checkpoint; verified output is an **unsigned arm64** app in `artifacts/ParityDeviceBuild`. This predates the later signed verification archive and build 2 configuration.
- **31 pure Swift tests passed at this checkpoint.** The generator audit passed **9,000 regular boards across three modes plus 365 daily boards**, including 600 coin boards / 1,800 collectible tiles and duplicate reward protection. See [ENGINE.md](ENGINE.md). After the later geometry-test platform-guard correction, the current pure package compiles and discovers 31 tests; a full rerun has not been claimed.
- **Final iPhone 17 Pro / iOS 26.5: 57 tests passed, zero failures** (52 engine/state/migration + five UI tests). Result: `artifacts/FinalParityTests.xcresult`.
- **iPhone SE (3rd generation): two additional UI tests passed**, covering move-challenge completion/settings and Time Rush expiry/retry in a 375×667 viewport. Result: `artifacts/CompactParityTests.xcresult`.

State coverage includes first-swipe timer start, monotonic countdown, background/tab/modal/video pauses, expiry, earned +30-second continuation, duplicate and stale reward callbacks, extra moves, skip without completion coins, offline resume, old-save migration, daily claim/relaunch, midnight rollover, stale midnight swipe/hint rejection, and duel currency isolation.

UI coverage includes swipe-solving, coin earnings, unlocking/equipping a ball, relaunch and replay protection, limited-move completion/failure/retry, settings, daily reward claim, daily maze launch, theme selection, and Time Rush expiry/retry. UI tests use explicit Debug-only hint/ad controls for deterministic gameplay. A previous run's only UI failure was an assertion for a renamed Journey heading; the assertion now uses a stable accessibility identifier.

## Historical Google test-ad verification

Normal Debug launches used Google's official test units and the actual consent/SDK presentation path, with no UI hint bypass:

1. **Hint:** the SDK presented a video marked **Test mode** and then **Reward granted**. Closing it revealed **Swipe down** on the same run; the unstarted timer remained at two seconds (the explicit Debug short-timer setting).
2. **Extra time:** that run reached zero with 27% painted and one move. The continuation button presented another actual test ad. After **Reward granted** and dismissal, the game displayed **00:30**, with 27% paint and the same ball position/move count intact. Automated lifecycle tests independently verify countdown resumption after dismissal and no decrement while the ad is open.

Evidence: `artifacts/parity-hint-earned.png`, `parity-hint-result.png`, `parity-timeout-live.png`, `parity-time-ad-wait.png`, and `parity-time-reward.png`. Earlier first-build validation also demonstrated a real test ad adding the 50-coin completion bonus. Test inventory does not establish production account approval or availability.

## Visual checks and integration limits

The renderer now uses continuous recessed walls and paint, beveled corners, contact shadows, studio reflection lighting, procedural wood/ceramic materials, animated collectible coins, and real 3D skin previews. A first-frame loading indicator covers SceneKit initialization. Reviewed final Classic/Time Rush/daily boards, Timber wood materials, 3D Collection, daily reward ladder, Journey, and completion/retry cards. On iPhone SE the mode picker, timer, wallet, and success/failure cards fit without clipping. Screenshots are in `artifacts/final-parity-shots` and `artifacts/compact-parity-attachments`.

Game Center Duel uses actual two-player matchmaking and shared-level/progress/result messages. It is an unranked peer race with a host-decided result, not a server-validated competitive economy. Disconnect/background/invitation handling was reviewed and corrected, but an actual two-account match remains unverified. See [Duel setup](PrismRoll/Services/Duel/README.md).

StoreKit 2 uses verified entitlements for No Ads, product lookup, purchase, restoration, and revocation. **All three local StoreKit tests passed on iOS 26.1**, exercising the actual purchase service, purchase/restore/revocation, pending Ask to Buy approval, and the Settings purchase UI. The fixture uses simulated pricing; these results do not verify App Store sandbox or production purchases. The App Store Connect product now exists. The shared scheme's local StoreKit fixture encountered a runtime failure on iOS 26.5, so use iOS 26.1 for these tests. See [purchase setup](PrismRoll/Services/PURCHASES.md).

Distribution still requires an eligible final archive, live verification of Game Center and App Store purchases, production ad delivery and consent messages, published policy/support URLs, and matching privacy disclosures. Signing, the App Store identity/product, and publisher-owned AdMob identifiers have been configured, but those configuration steps do not establish end-to-end production operation. Release builds intentionally reject Google's sample identifiers. Exact AMAZE feature/economy parity remains unverified; historical music-mode availability and remote-config variants are unknown.
