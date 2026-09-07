# Validation — September 6, 2026

## First App Store submission

Version **1.0.0 (2)** and the **No Ads** non-consumable are both **Waiting for Review**, verified in App Store Connect's API and browser on September 6, 2026 at 5:19 PM Pacific. The app is free, initially available in the USA, with No Ads priced at **$2.99 USD**. Release is manual after approval. Submission validation had no blocking issues before submission; rerunning its editable-state check afterward correctly rejects the already-submitted version.

The same build is **In Beta Testing** in the private internal **Owner Testing** group. The verified account-holder email was invited; App Store Connect shows one tester, one build, and tester status **Invited**. These states establish distribution and invitation, not inbox delivery, acceptance, or installation. Build-specific testing notes are configured.

The [production archive workflow](https://github.com/jonluca/amaze/actions/runs/34068850920) succeeded with Xcode **26.6 (17F113)** and SDK **iphoneos26.5 (23F81a)**, compiling source commit `611143747ec64c7bf3332f810167637533cb4882`. The arm64 archive was signed and exported locally using the existing distribution identity and provisioning profile. Strict signature verification, the Game Center and distribution entitlements, all three privacy manifests, absence of Debug bypasses and the StoreKit fixture, and matching app/dSYM UUID passed. Apple processed the upload as **VALID** and **APP_STORE_ELIGIBLE**, and the exact build is attached to the submitted version. The earlier beta-SDK verification archive was not uploaded.

Final IPA SHA-256: `d41c0fc5e52a73c929bc0b8633450e9f6a42c6e390f7d4a1da3beed740701c69`. Private artifacts and verification records are in `artifacts/ProductionBuild2` and `release`; signing credentials are not committed or sent to GitHub.

English metadata, six iPhone and six iPad screenshots, review contact/instructions, age rating, content rights, Game Center compatibility, free app pricing, IAP localization/pricing/review screenshot, and published App Privacy are configured. Screenshot upload state and server checksums were verified. Existing agreements, banking, and tax statuses were active.

The public [support page](https://thoughtahead.com/prism-roll/support.html), [privacy policy](https://thoughtahead.com/prism-roll/privacy.html), stylesheet, and publisher `app-ads.txt` were deployed on the existing website. All four public responses returned HTTP 200 and matched their source bytes; desktop and mobile layouts were reviewed. Store metadata and native Settings use these URLs.

## Production advertising and privacy

Build 2 contains the verified production AdMob app, rewarded, and interstitial identifiers; Debug uses Google's official test units. European and US privacy messages are published. Regional partner selections contain Google; this does not establish Google-only worldwide advertising demand. Requests use non-personalized ads and global restricted data processing, with publisher first-party ID and personalization disabled. App Privacy is published with nine data categories and no tracking, based on the SDK data disclosures, these client controls, and documented buyer restrictions.

Actual SDK sample-ad requests exposed `npa=1`, `rdp=1`, `ppt=1`, disabled first-party ID, and no advertising identifier; the platform IDFA was zero and ATT remained undetermined. Both ad formats loaded Google test inventory. The US privacy options form displayed and saving an opt-out changed GPP while preserving restricted processing. These are test-inventory and US-consent observations, not proof that production units can serve.

AdMob account verification is pending. The app must have a public App Store listing before store linking, publisher-file verification, and app readiness review can finish. European message delivery remains unverified: a fresh simulator/process forced EEA on its first consent request, with no prior TCF value, but UMP returned Not Required/unavailable without an error. Refusal and withdrawal could not be exercised. Investigate that server/configuration result before claiming European consent readiness; USA distribution does not geofence travelers. Gameplay remains available when ads are unavailable.

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

The submitted build, listing, policies, and disclosures are configured. Live production ad delivery, European consent delivery, two-account Game Center matchmaking, and App Store sandbox purchase/restore remain separate integration checks; local fixtures do not establish their outcomes. Release builds intentionally reject Google's sample identifiers. Exact AMAZE feature/economy parity remains unverified; historical music-mode availability and remote-config variants are unknown.
