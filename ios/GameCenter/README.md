# Prism Roll Game Center catalog

`catalog.json` defines the identifiers, English metadata, points, artwork and activity associations used by the native app. The catalog contains 12 achievements worth 550 points, five classic (all-time) cumulative leaderboards, and three single-player activities.

- Achievement identifiers: `com.jonluca.prismroll.achievement.*`
- Leaderboard identifiers: `com.jonluca.prismroll.leaderboard.*`
- Activities: `com.jonluca.prismroll.activity.classic`, `.time_rush`, and `.daily`
- App Store Connect app: `6809253424`; bundle: `com.jonluca.prismroll`

The daily achievement counts seven different daily mazes; it is not a consecutive-day streak. The coin achievement counts actual maze pickups, not purchases, gifts or the wallet balance. Every leaderboard stores an integer count, sorts descending, and retains the best score. Classic Mazes Completed is the default leaderboard. These cumulative leaderboards are not configured as competitive Challenges.

## Reproduce and verify

The following commands reproduce the original staging workflow from the repository root. Python 3, `rsvg-convert`, ImageMagick and an authenticated `asc` CLI are needed. Authentication stays in the CLI/keychain; no credentials are stored here. The catalog is now submitted: the staging script, including `--verify-only`, deliberately requires `PREPARE_FOR_SUBMISSION` and rejects the current review state. Use the [build 15 review record](../VALIDATION.md#build-15-app-store-review) for submission verification.

```sh
python3 ios/GameCenter/scripts/build_manifest.py
python3 ios/GameCenter/scripts/render_artwork.py
python3 ios/GameCenter/scripts/stage_catalog.py
python3 ios/GameCenter/scripts/stage_catalog.py --verify-only
```

`build_manifest.py` reads achievement text/points from the Swift catalog. Artwork is original, reproducible SVG with the app's violet/pink palette and rolling-ball motif. PNG exports are opaque RGB at 72 ppi: 1024 × 1024 for achievements and 3840 × 2160 for activities. `artwork/contact-sheet.png` shows all achievement designs in catalog order.

`stage_catalog.py` creates missing resources, English localizations and images, then adds activity associations. Each activity has both default and localized artwork. The CLI handles catalog and localized image uploads; the official API handles default activity images because the CLI does not expose that upload relationship. The script checks existing metadata instead of silently overwriting differences. It never creates releases, submits review content, uploads a build, or modifies an app version. `--verify-only` performs reads only. A mismatch or unfinished image processing stops the script.

`staging.json` records successful writes and verified remote IDs. `verification.json` is the subsequent read-only snapshot from before submission; its `PREPARE_FOR_SUBMISSION` states are historical. Reports retain resource IDs and local image hashes, not authentication material or upload URLs. The staging verification checked remote metadata, image dimensions and delivery, component version states and absent releases. Activity associations and the disabled party-code setting were checked with Apple's read API using a short-lived CLI token held only in memory. These checks do not establish authenticated GameKit behavior on a device.

## Publication state and app review

The app version and all 20 Game Center component versions are **`WAITING_FOR_REVIEW`**, verified **September 16, 2026 at 4:54 PM Pacific** (`2026-09-16T23:54:27.768Z`). They are pending approval, not live. Game Center remains enabled for the app version. Release is automatic after approval (`AFTER_APPROVAL`); the live App Store version remains **1.0.0 (12)**.

The accepted review submission contains **21 items**: app version **1.1.0**, linked to **build 15**, plus all 12 achievements, five leaderboards, and three activities. This replaces the earlier build 14 submission. The release identifiers are:

| Resource | Identifier |
| --- | --- |
| App version 1.1.0 | `dfb5f5db-4c9b-4ff0-970e-4947fa001dea` |
| Build 15 | `aa54a9db-0896-4b78-a15c-ca3f162007f9` |
| Current review submission | `d4b41867-3019-4ae9-bd7a-0b640db04441` |
| Replaced build 14 submission | `4b391def-b28d-4554-b47c-1e36b59912ab` |

Apple requires the first Game Center components to be reviewed in the same submission as a Game Center-enabled app version. This submission attaches the following component **version IDs** recorded in `verification.json`, alongside the `appStoreVersions` item:

| Catalog entries | Review item type | Identifier to attach |
| --- | --- | --- |
| 12 achievements | `gameCenterAchievementVersions` | Each `achievements[].versions[].id` |
| Five leaderboards | `gameCenterLeaderboardVersions` | Each `leaderboards[].versions[].id` |
| Three activities | `gameCenterActivityVersions` | Each `activities[].versions[].id` |

For future catalog submissions, the supported command for adding a component to an editable draft is:

```sh
asc review items add --submission DRAFT_SUBMISSION_ID --item-type gameCenterAchievementVersions --item-id COMPONENT_VERSION_ID
```

Use the corresponding item type from the table for leaderboards and activities. In the App Store Connect UI, the equivalent is Game Center → component → Add for Review → the app version's existing draft submission. The current submission has already been sent to Apple; these commands document the workflow for future releases.

Production source `b8ba1f8b499d1ab1f2bbcbfd1040718e210d7b18` was archived with Xcode **26.6** in [run 35163482422](https://github.com/jonluca/amaze/actions/runs/35163482422), then signed and exported locally. See [build 15 review verification](../VALIDATION.md#build-15-app-store-review) for final artifact and Apple readback evidence. Authenticated achievement and leaderboard reporting on a device remains unverified.

Official references: [submit Game Center components](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components), [enable Game Center for an app version](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-an-app-version-for-game-center), [Game Center artwork and design](https://developer.apple.com/design/human-interface-guidelines/game-center).
