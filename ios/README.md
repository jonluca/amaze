# Prism Roll for iOS

A native SwiftUI + SceneKit maze-painting game inspired by the swipe-to-paint mechanics of [AMAZE](https://apps.apple.com/us/app/amaze/id1452526406). Prism Roll has its own name, interface, procedural levels, materials, and artwork. The original solver elsewhere in this repository is preserved.

**TestFlight 1.0.0 (10)** expands the collection to **18 balls across six rarities**, with paid unlocks from **500 to 150,000 coins** and existing ownership preserved. Six new balls add increasingly elaborate textures and trails. The build also includes smoother rolling, ball compression at walls, gold coin completion effects, and stronger, deeper haptics. Verified **September 8, 2026 at 9:13 PM Pacific** as **VALID** and **IN_BETA_TESTING** in the existing private **Owner Testing** group. See [release verification](VALIDATION.md#build-10-testflight-release).

**App Review 1.0.0 (11)** includes the [Coin Shop, advancing milestones, and spacing fixes](COINS_MILESTONES.md), plus Classic minimum-move targets. Tap the wallet or **Get coins** in Collection for coin packs and optional 50-coin videos. Milestone claims advance, and the Duel entry is removed. The app, No Ads, and all three coin packs were verified **Waiting for Review on September 9, 2026 at 9:27 AM Pacific**. Release remains manual after approval. See [submission verification](VALIDATION.md#current-app-store-review--build-11).

**Build 8** introduced painted squares with slim gaps, rounded corners, satin gradients, and subtle beveled highlights; distinct animated trails for all 12 ball skins; and [stronger continuous rolling haptics](HAPTICS_TRANSITIONS.md), including firm feedback with Reduce Motion. The gameplay screen removes the separate paint progress bar and Pause button, keeps moves and coin counts below the title, and pauses through Settings. Rewarded-ad buttons appear only when a video is ready; first-maze hints remain free. See [release verification](VALIDATION.md).

## Play

The [missed-swipe fix](SWIPE_RELIABILITY.md) and [smoother rendering pass](SMOOTHNESS.md) are available in **TestFlight 1.0.0 (5)**, verified September 7, 2026. They resolve quick diagonal flicks and overlapping contacts, enable ProMotion up to 120 FPS, soften ball stops without extending slides, and reuse prepared paint effects.

Swipe up, down, left, or right anywhere in the gameplay area, including the heading and empty space around the board. The native touch recognizer starts once a stroke travels 8 points with a clear direction, before the finger lifts. Keep the finger down and drag to turn or reverse; small jitter does not create extra moves. Buttons, tabs, pickers, scrolling controls, and presented sheets keep their normal interactions. The ball rolls until a wall stops it, painting every tile it crosses. Paint all open tiles to advance automatically. Blocked swipes do not count as moves.

The current source uses [exact native optimization](OPTIMAL_SOLVER.md) for both the level's perfect move count and hints from the ball's current position and painted tiles. Hints wait for a proved shortest route, reuse its remaining directions after each correct swipe, and recalculate in the background after a deviation. Small remaining problems use compact breadth-first search; larger ones use the native integer optimizer without difficulty or search-time cutoffs. Cached proofs are shared across hints, targets, and completion checks.

Build 9 adds a gold **Perfect solve** medal with purple ribbons, laurels, and the move count over the finished maze before automatic progression. The medal pops in quickly and advances after 0.65 seconds (1.5 seconds with VoiceOver). Exact verification runs away from the UI thread; matching the stored hint route alone does not earn the award. That release used fixed search budgets; the current native solver continues until it proves the minimum, is cancelled, or reports a failure. The reveal supports Reduce Motion and VoiceOver, and resumes its full display interval after menus or backgrounding. Crowns and best move counts are retained in the Levels tab.

Build **1.0.0 (10)** is the latest private TestFlight build. The App Store version is attached to build 11 and waiting for review with No Ads and three coin packs; the submission is recorded in [VALIDATION.md](VALIDATION.md#current-app-store-review--build-11). The app uses native `TabView` navigation, `NavigationStack` toolbars, a segmented mode `Picker`, and `List`/`Form` screens. Accessibility text sizes keep the board visible while the controls scroll. The more top-down camera fits the complete freeform board, using approximately 84–86% of the available width when height permits. Texture generation runs away from the UI actor, the scene waits for prepared resources and its first rendered frame, and the launch screen uses the app's dark background. Ordered move events preserve rapid turns through display updates; old touches and callbacks cannot affect a reset run. The replacement [generated icon and its prompt](Design/README.md) are included.

- **Levels:** browse all numbered levels, including locked future levels, with pages and a direct number jump. A checkmark means solved; a gold crown means a minimum-move solve has been verified. Best move counts persist across replays and relaunches. See [the shared catalog and progress behavior](LEVEL_CATALOG.md).
- **Classic:** unlimited swipes and deterministic levels growing from 5×5 to 16×16. The first 1,000 boards have unique wall layouts and bundled exact perfect counts. Larger mazes require more independent path coverage, decisions, and backtracking. Boards and proof records use the current catalog directly, with exact-grid checks before cached results are reused.
- **Time Rush:** five mazes per round with one shared countdown scaled to their executable routes, starting on the first valid swipe. Mazes advance automatically; the completion reward arrives after all five. A free retry restarts the entire round. Background time, menus, and reward videos pause the clock. See [Time Rush](TIME_RUSH.md).
- **Limited Moves:** a harder separate progression with an achievable swipe budget and free retry. The allowance tightens from three spare moves to one beyond the verified route. Blocked swipes cost nothing.
- **Reward videos:** hints, +30 seconds, +3 moves, skipping a regular level, and optional 50-coin bonuses on completed Journey rows. Video buttons appear only when an ad is ready; first-maze hints remain free. Benefits require the SDK earned-reward callback; failed or dismissed ads grant nothing.
- **Coins:** 50 per new completion; three collectible coins on every fifth Classic board. Claim-once ledgers and per-level collectible allowances prevent replay farming across changed layouts. Coins unlock and equip 18 skins across Common, Uncommon, Rare, Epic, Legendary, and Mythic rarities. Coral is free; paid balls progress from 500 to 150,000 coins, and existing ownership is preserved.
- **Daily rewards:** consecutive daily claims earn 25–55 coins. A date-seeded daily maze awards 100 coins once. Three milestone tracks keep advancing after each claim: completed levels, Time Rush rounds, and coins collected inside mazes.
- **Worlds:** Aurora, Timber, Porcelain, and Midnight themes with freeform contour walls, transparent cutouts, visible path grids, spaced painted squares with satin gradients, reflective textured balls, distinct trails for all 18 skins, animated coins, and native 3D collection previews.
- **Coin Shop:** consumable 1,000-, 5,500-, and 15,000-coin packs show App Store prices. Optional videos grant 50 coins per completed video. The wallet and purchase receipt ledger are saved atomically; coins remain on this installation.
- **No Ads:** StoreKit 2 non-consumable purchase and restoration suppress between-level interstitials while retaining voluntary reward videos. The App Store product is created; local StoreKit purchase, restore, revocation, and Ask to Buy flows pass. App Store sandbox and production purchases remain unverified.
- Separate saved runs for all three modes, saved daily progress, theme/skin preferences, haptics, move sounds, Reduce Motion, and VoiceOver movement actions. Original saves migrate without losing currency or ownership.

The [reference audit](FEATURE_AUDIT.md) distinguishes official current features, user observations, historical features, and unknown balancing details. Exact current installed-app parity has not been established.

## Open and run

Open `PrismRoll.xcodeproj`, select the **PrismRoll** scheme and an iPhone/iPad simulator, then Run. Dependencies are pinned in `Package.resolved`: Google Mobile Ads 13.9.0 and User Messaging Platform 3.1.0. Deployment target is iOS 17.

For a physical device, choose your development team in Signing & Capabilities. The project contains the Prism Roll bundle and team identifiers; a separate publisher needs its own signing, App Store, and advertising configuration. Prism Roll's App Store record and No Ads product have been created. Version **1.0.0 (8)** has a verified production archive built on GitHub with Xcode **26.6 (17F113)** and the **iOS 26.5 SDK**, followed by local distribution signing and export. Apple processed it as **VALID** and **APP_STORE_ELIGIBLE**. Upload, processing, and review status are tracked in [VALIDATION.md](VALIDATION.md).

Build 8 is **In Beta Testing** in the private **Owner Testing** group, verified **September 7, 2026 at 2:57 PM Pacific**. The sole existing owner tester retains access, and automatic notifications are enabled. At **3:08 PM Pacific on September 7**, build 8 and the same No Ads purchase were verified **Waiting for Review**, replacing the withdrawn build 3 submission. Localization metadata was preserved and reviewer notes were updated for the current controls. The review submission is documented in [VALIDATION.md](VALIDATION.md). All twelve replacement screenshots and the native No Ads review image are complete with matching server checksums. Release remains manual after approval. Production AdMob identifiers and published privacy messages are configured; sample-ad requests and US opt-out were exercised, while production serving and European consent delivery remain unverified. The production archive contains the app and both Google SDK privacy manifests. The public [support](https://thoughtahead.com/prism-roll/support.html) and [privacy policy](https://thoughtahead.com/prism-roll/privacy.html) URLs are verified; see [VALIDATION.md](VALIDATION.md) for release evidence and service limits.

The project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Regenerate after adding source files:

```sh
cd ios
xcodegen generate
xcodebuild -project PrismRoll.xcodeproj -scheme PrismRoll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Production archive and local export

The manual [production archive workflow](../.github/workflows/ios-production-archive.yml) runs on GitHub's `macos-26` image with `DEVELOPER_DIR` scoped to `/Applications/Xcode_26.6.app/Contents/Developer`. It archives the shared **PrismRoll** scheme in Release for physical iOS devices with signing disabled. It checks the toolchain, version/build, production ad identifiers, arm64 executable, and privacy manifests, then uploads the archive, source entitlements, package lock, provenance, and checksum. No Apple signing identity, provisioning profile, or private key is sent to GitHub.

[Build 11's successful run](https://github.com/jonluca/amaze/actions/runs/34374961797) archived source commit `36b9f48f1a91127c6f3647919d3062d03e69e7d1`. The final IPA passed primary and independent signature, entitlement, ZIP integrity, privacy-manifest, and app/dSYM UUID checks; no test artifacts were packaged, and the production SDK metadata remained unchanged. Its verified SHA-256 is recorded in [VALIDATION.md](VALIDATION.md#current-app-store-review--build-11).

For another release, update the workflow's expected version/build and configuration checks before dispatching it for the intended source commit. Download its archive artifact and verify `SHA256SUMS` before extraction. Sign and export on the release Mac using its existing distribution identity and App Store provisioning profile.

**Preserve entitlements before export.** Exporting this unsigned archive directly omitted Game Center from the resulting signature. The successful route signed the archived app locally with entitlements derived from the project's requested capabilities and the matching provisioning profile, then ran `xcodebuild -exportArchive` with the local distribution configuration. Verify the final IPA's signature and embedded profile, including the correct application and team identifiers, `com.apple.developer.game-center = true`, `get-task-allow = false`, and `beta-reports-active = true`. Do not change SDK or Xcode metadata to make an archive appear to use a different toolchain.

## Test

The pure engine tests also run without a simulator:

```sh
swift test --package-path ios/EnginePackage
```

The package symlinks the app’s actual Core, pure swipe recognition, and test sources; there is no second engine implementation. Simulator tests include engine behavior, persistence/reward lifecycle, and UI flows for solving mazes, purchases, replay, relaunch, challenges, and settings:

```sh
cd ios
xcodebuild -project PrismRoll.xcodeproj -scheme PrismRoll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -derivedDataPath DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

Use iOS **26.1** for the shared scheme's local StoreKit tests; the same fixture encountered a StoreKit runtime failure on iOS 26.5. Use a destination UDID if several simulators match. The local fixture uses simulated pricing and does not exercise App Store Connect purchases.

Build 10's exact committed source passed **106 Release engine tests**, all four milestone reward audits, and the 51-level catalog audit across four independent processes. Collection checks passed 26 native tests and four UI flows, plus a separate large-text preview check. Motion and haptic checks passed 75 native tests and eight unique UI flows. Counts overlap; physical vibration strength and sustained device ProMotion performance remain unmeasured. See [the release checkpoint](VALIDATION.md#build-10-testflight-release) for source provenance and evidence.

Build 8's 160 Swift files matched the validated combined source snapshot. Its overlapping checks include 80 gameplay checks, 41 final haptic/renderer checks, 27 ball-trail checks, and 23 visited-tile checks. A clean export of the committed build 8 source separately passed 26 native tests and one UI smoke test.

A clean export of the exact build 7 source commit passed all 85 engine/input tests in Release configuration and six Python regressions, including its committed source symlinks. The release also passed 50 native state checks and three gameplay UI flows. The earlier build 5 swipe and smoothness checkpoint passed 178 native tests and five UI tests; see [SMOOTHNESS.md](SMOOTHNESS.md). These counts overlap.

The build 3 polish checkpoint passed 69 unit/state tests in `PolishTests-2`, then five renderer regressions and seven UI flows in `PolishTests-3`; these counts overlap. A final short-flick smoke test passed after the final edits. Coverage includes 600 synchronous moves, stale-snapshot rejection, reset/modal suppression, native controls, and accessibility text layout. See [VALIDATION.md](VALIDATION.md) for the exact runs, earlier UI-selector failures, and measured processing times.

`--uitesting` resets the app’s local save and disables ads in Debug. Combined with that reset, `--ui-test-coins <amount>` seeds a 0–150,000 coin wallet for collection purchase tests. `--no-ads` preserves the save while disabling ads in Debug. `--ui-hints` allows deterministic hints for UI tests without resetting a save, and `--short-timer` uses two-second fresh timers in Debug. These flags do not bypass production behavior in Release.

## Advertising setup

Debug uses Google's official test ad units. Release is configured with verified publisher-owned app, rewarded, and interstitial identifiers and rejects Google's sample identifiers. Every ad request asks for non-personalized ads; publisher first-party ID and personalization are disabled, and restricted data processing is enabled globally. Published regional messages select Google, but this does not imply Google-only worldwide demand. See [Ads/README.md](PrismRoll/Ads/README.md) for exact keys and configuration and [VALIDATION.md](VALIDATION.md) for US and European consent results.

As checked September 7, the public US App Store lookup for `6809253424` returns no listing. Full ad serving still requires a public supported-store listing, AdMob store linking, app-ads.txt verification, and Google readiness approval; these prerequisites do not establish the cause of every no-fill response. [Google app readiness](https://support.google.com/admob/answer/10564477?hl=en), [app verification](https://support.google.com/admob/answer/14538460?hl=en).

The hosted [app-ads.txt](https://thoughtahead.com/app-ads.txt) returns HTTP 200 with the correct publisher entry. The live App Store marketing URL is already `https://thoughtahead.com/prism-roll/support.html`, so its developer-website domain matches; Google uses that marketing URL to discover app-ads.txt. The saved September 6 account record (`release/admob-configuration.json`) said verification was pending. Current account approval is unverified because browser security policy blocked the authenticated AdMob refresh. After public release, complete store linking and app verification, then confirm Google reports the app ready. [Google developer-website setup](https://support.google.com/admob/answer/9363762?hl=en).

The app does not request tracking authorization. That release policy requires the live advertising configuration to avoid cross-company tracking; non-personalized ads still collect operational data and do not remove consent obligations. Coins are local gameplay currency; the separate No Ads purchase uses verified StoreKit entitlements. See [purchase setup](PrismRoll/Services/PURCHASES.md) and [Duel setup](PrismRoll/Services/Duel/README.md). The app uses published policy URLs and privacy disclosures matching the configured SDKs. No reference game assets are bundled.

## Source layout

| Folder | Responsibility |
| --- | --- |
| `PrismRoll/Core` | Seeded levels, slide solver, run state, reward ledger, skin catalog |
| `PrismRoll/App` | Observable state, save/resume, app lifecycle |
| `PrismRoll/Input` | Full gameplay swipe observer, touch filtering, ordered move events |
| `PrismRoll/Rendering` | 3D board, asynchronous textures, frame readiness, continuous roll/paint timeline |
| `PrismRoll/Views` | Native navigation, play, collection, journey, completion, and settings screens |
| `PrismRoll/Services` | StoreKit entitlements and Game Center Duel |
| `PrismRoll/Ads` | Consent, inventory, presentation, verified reward callbacks |
| `PrismRollTests` | Engine and state regression tests |
| `PrismRollUITests` | Real simulator interaction tests and screenshot attachments |

The replacement app icon and its generation prompt are documented in [Design/README.md](Design/README.md). The 1024-pixel opaque asset is in the AppIcon asset catalog.
