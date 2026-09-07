# Prism Roll for iOS

A native SwiftUI + SceneKit maze-painting game inspired by the swipe-to-paint mechanics of [AMAZE](https://apps.apple.com/us/app/amaze/id1452526406). Prism Roll has its own name, interface, procedural levels, materials, and artwork. The original solver elsewhere in this repository is preserved.

## Play

Swipe up, down, left, or right anywhere in the gameplay area, including the heading and empty space around the board. The native touch recognizer acts once a stroke crosses 12 points with a clear direction, before the finger lifts. Buttons, tabs, pickers, scrolling controls, and presented sheets keep their normal interactions. The ball rolls until a wall stops it, painting every tile it crosses. Paint all open tiles to finish. Blocked swipes do not count as moves.

Build **1.0.0 (3)** is the current local polish checkpoint and is being prepared for release. It adds native `TabView` navigation, `NavigationStack` toolbars, a segmented mode `Picker`, and `List`/`Form` screens. Accessibility text sizes keep the board visible while the controls scroll. The camera uses a smaller fit with a 68% width and 78% height budget inside the 3D canvas. Texture generation runs away from the UI actor, the scene waits for prepared resources and its first rendered frame, and the launch screen uses the app's dark background. Ordered move events preserve rapid turns through display updates; old touches and callbacks cannot affect a reset run. The replacement [generated icon and its prompt](Design/README.md) are included. The App Store and TestFlight status below refers to **build 2**, not build 3.

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

For a physical device, choose your development team in Signing & Capabilities. The project contains the Prism Roll bundle and team identifiers; a separate publisher needs its own signing, App Store, and advertising configuration. Prism Roll's App Store record and No Ads product have been created. Version **1.0.0 (2)** has a production archive built on GitHub with Xcode **26.6 (17F113)** and the **iOS 26.5 SDK**, followed by local distribution signing and export. Upload, processing, and review status are tracked in [VALIDATION.md](VALIDATION.md).

Version **1.0.0 (2)** and **No Ads** are **Waiting for Review**. Production AdMob identifiers and published privacy messages are configured; sample-ad requests and US opt-out were exercised, while production serving and European consent delivery remain unverified. The production archive contains the app and both Google SDK privacy manifests. The public [support](https://thoughtahead.com/prism-roll/support.html) and [privacy policy](https://thoughtahead.com/prism-roll/privacy.html) URLs are verified; see [VALIDATION.md](VALIDATION.md) for release evidence and service limits.

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

[Build 2's successful run](https://github.com/jonluca/amaze/actions/runs/34068850920) archived source commit `611143747ec64c7bf3332f810167637533cb4882`. Its downloaded archive checksum and executable SDK metadata were verified locally. The local export passed strict code-signature verification and matched the app's dSYM UUID; the production SDK metadata remained unchanged.

For another release, update the workflow's expected version/build and configuration checks before dispatching it for the intended source commit. Download its archive artifact and verify `SHA256SUMS` before extraction. Sign and export on the release Mac using its existing distribution identity and App Store provisioning profile.

**Preserve entitlements before export.** Exporting this unsigned archive directly omitted Game Center from the resulting signature. The successful route signed the archived app locally with entitlements derived from the project's requested capabilities and the matching provisioning profile, then ran `xcodebuild -exportArchive` with the local distribution configuration. Verify the final IPA's signature and embedded profile, including the correct application and team identifiers, `com.apple.developer.game-center = true`, `get-task-allow = false`, and `beta-reports-active = true`. Do not change SDK or Xcode metadata to make an archive appear to use a different toolchain.

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

The build 3 polish checkpoint passed 69 unit/state tests in `PolishTests-2`, then five renderer regressions and seven UI flows in `PolishTests-3`; these counts overlap. A final short-flick smoke test passed after the final edits. Coverage includes 600 synchronous moves, stale-snapshot rejection, reset/modal suppression, native controls, and accessibility text layout. See [VALIDATION.md](VALIDATION.md) for the exact runs, earlier UI-selector failures, and measured processing times.

`--uitesting` resets the app’s local save and disables ads in Debug. `--no-ads` preserves the save while disabling ads in Debug. `--ui-hints` allows deterministic hints for UI tests without resetting a save, and `--short-timer` uses two-second fresh timers in Debug. These flags do not bypass production behavior in Release.

## Advertising setup

Debug uses Google's official test ad units. Release is configured with verified publisher-owned app, rewarded, and interstitial identifiers and rejects Google's sample identifiers. Production serving awaits Google's account/app approval and public-store linking. Every ad request asks for non-personalized ads; publisher first-party ID and personalization are disabled, and restricted data processing is enabled globally. Published regional messages select Google, but this does not imply Google-only worldwide demand. See [Ads/README.md](PrismRoll/Ads/README.md) for exact keys and configuration and [VALIDATION.md](VALIDATION.md) for US and European consent results.

The app does not request tracking authorization. That release policy requires the live advertising configuration to avoid cross-company tracking; non-personalized ads still collect operational data and do not remove consent obligations. Coins are local gameplay currency; the separate No Ads purchase uses verified StoreKit entitlements. See [purchase setup](PrismRoll/Services/PURCHASES.md) and [Duel setup](PrismRoll/Services/Duel/README.md). The submitted app uses published policy URLs and privacy disclosures matching the configured SDKs. No reference game assets are bundled.

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
