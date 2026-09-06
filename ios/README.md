# Prism Roll for iOS

A native SwiftUI + SceneKit maze-painting game inspired by the swipe-to-paint mechanics of [AMAZE](https://apps.apple.com/us/app/amaze/id1452526406). Prism Roll has its own name, interface, procedural levels, materials, and artwork. The original solver elsewhere in this repository is preserved.

## Play

Swipe up, down, left, or right anywhere on the board. The ball rolls until a wall stops it, painting every tile it crosses. Paint all open tiles to finish. Blocked swipes do not count as moves.

- **Classic:** unlimited swipes and deterministic levels growing from 4×4 to 9×9, with validated covering solutions.
- **Time Rush:** independent progression, a visible countdown that begins on the first valid swipe, timeout and free retry. Background time, menus, and reward videos pause the clock.
- **Limited Moves:** a separate progression with an achievable swipe budget and free retry. Blocked swipes cost nothing.
- **Reward videos:** hints, +30 seconds, +3 moves, skipping a regular level, and doubling a completion reward. Benefits require the SDK earned-reward callback; failed or dismissed ads grant nothing.
- **Coins:** 50 per new completion; collectible coins on every fifth Classic board. Claim-once ledgers prevent replay farming. Coins unlock and equip 12 original skins.
- **Daily rewards:** consecutive daily claims earn 25–55 coins. A date-seeded daily maze awards 100 coins once, alongside four milestone challenges.
- **Worlds:** Aurora, Timber, Porcelain, and Midnight themes with recessed corridors, continuous paint, reflective textured balls, animated coins, and native 3D collection previews.
- **Duel:** real two-player Game Center matchmaking with a shared maze, opponent progress, and a first-finish result. Requires configured Game Center and two accounts to verify an actual match.
- **No Ads:** StoreKit 2 non-consumable purchase and restoration suppress between-level interstitials while retaining voluntary reward videos. The App Store product is created; local StoreKit purchase, restore, revocation, and Ask to Buy flows pass. App Store sandbox and production purchases remain unverified.
- Separate saved runs for all three modes, saved daily progress, theme/skin preferences, haptics, move sounds, Reduce Motion, and VoiceOver movement actions. Original saves migrate without losing currency or ownership.

The [reference audit](FEATURE_AUDIT.md) distinguishes official current features, user observations, historical features, and unknown balancing details. Exact current installed-app parity has not been established.

## Open and run

Open `PrismRoll.xcodeproj`, select the **PrismRoll** scheme and an iPhone/iPad simulator, then Run. Dependencies are pinned in `Package.resolved`: Google Mobile Ads 13.9.0 and User Messaging Platform 3.1.0. Deployment target is iOS 17.

For a physical device, choose your development team in Signing & Capabilities. The project contains the Prism Roll bundle and team identifiers; a separate publisher needs its own signing, App Store, and advertising configuration. Prism Roll's App Store record and No Ads product have been created. A signed verification archive was produced with a beta SDK, but no build has been uploaded or submitted.

The current release configuration is build **2**. Production AdMob app and unit identifiers have been verified and configured; live publisher ad delivery and consent remain unverified. The unsigned generic iOS Release build passed in 11.6 seconds: `artifacts/ProductionConfigBuild2/Build/Products/Release-iphoneos/PrismRoll.app`, with checks recorded in `artifacts/ProductionConfigBuild2/verification.json`. The output is version 1.0.0 (2), arm64, using SDK `iphoneos27.0`; all three production identifiers pass the Release guard, the four Debug bypass strings and local StoreKit fixture are absent, and the support/privacy URLs are compiled in. The configured [support](https://thoughtahead.com/prism-roll/support.html) and [privacy policy](https://thoughtahead.com/prism-roll/privacy.html) URLs await publication verification. See [VALIDATION.md](VALIDATION.md) for the distinction between current release status and earlier validation results.

The project is generated from `project.yml` using [XcodeGen](https://github.com/yonaskolb/XcodeGen). Regenerate after adding source files:

```sh
cd ios
xcodegen generate
xcodebuild -project PrismRoll.xcodeproj -scheme PrismRoll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
```

## Test

The pure engine tests also run without a simulator:

```sh
swift test --package-path ios/EnginePackage
```

The package symlinks the app’s actual Core and test sources; there is no second engine implementation. Simulator tests include engine behavior, persistence/reward lifecycle, and UI flows for solving mazes, purchases, replay, relaunch, challenges, and settings:

```sh
cd ios
xcodebuild -project PrismRoll.xcodeproj -scheme PrismRoll \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.1' \
  -derivedDataPath DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

Use iOS **26.1** for the shared scheme's local StoreKit tests; the same fixture encountered a StoreKit runtime failure on iOS 26.5. Use a destination UDID if several simulators match. The local fixture uses simulated pricing and does not exercise App Store Connect purchases. The current pure package compiles and discovers 31 tests after the platform-guard correction; its last complete 31-test pass predates that correction.

`--uitesting` resets the app’s local save and disables ads in Debug. `--no-ads` preserves the save while disabling ads in Debug. `--ui-hints` allows deterministic hints for UI tests without resetting a save, and `--short-timer` uses two-second fresh timers in Debug. These flags do not bypass production behavior in Release.

## Advertising setup

Debug uses Google's official test ad units. Release is configured with verified publisher-owned app, rewarded, and interstitial identifiers and rejects Google's sample identifiers. Production inventory and published consent-message behavior still need live verification. Every ad request asks for non-personalized ads; publisher first-party ID and personalization are disabled, and restricted data processing is enabled globally. The first release is intended to use Google demand only. See [Ads/README.md](PrismRoll/Ads/README.md) for exact keys and configuration.

The app does not request tracking authorization. That release policy requires the live advertising configuration to avoid cross-company tracking; non-personalized ads still collect operational data and do not remove consent obligations. Coins are local gameplay currency; the separate No Ads purchase uses verified StoreKit entitlements. See [purchase setup](PrismRoll/Services/PURCHASES.md) and [Duel setup](PrismRoll/Services/Duel/README.md). Distribution still requires an eligible final archive, verified live services and policy URLs, and privacy disclosures matching the actual configuration. No copyrighted game assets are bundled.

## Source layout

| Folder | Responsibility |
| --- | --- |
| `PrismRoll/Core` | Seeded levels, slide solver, run state, reward ledger, skin catalog |
| `PrismRoll/App` | Observable state, save/resume, app lifecycle |
| `PrismRoll/Rendering` | 3D board, lighting, ball materials, queued roll/paint animations |
| `PrismRoll/Views` | Play, collection, journey, completion, and settings screens |
| `PrismRoll/Services` | StoreKit entitlements and Game Center Duel |
| `PrismRoll/Ads` | Consent, inventory, presentation, verified reward callbacks |
| `PrismRollTests` | Engine and state regression tests |
| `PrismRollUITests` | Real simulator interaction tests and screenshot attachments |

App icon artwork is generated locally with `swift scripts/generate_icon.swift PrismRoll/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.
