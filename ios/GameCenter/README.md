# Prism Roll Game Center catalog

`catalog.json` defines the identifiers, English metadata, points, artwork and activity associations used by the native app. The catalog contains 12 achievements worth 550 points, five classic (all-time) cumulative leaderboards, and three single-player activities.

- Achievement identifiers: `com.jonluca.prismroll.achievement.*`
- Leaderboard identifiers: `com.jonluca.prismroll.leaderboard.*`
- Activities: `com.jonluca.prismroll.activity.classic`, `.time_rush`, and `.daily`
- App Store Connect app: `6809253424`; bundle: `com.jonluca.prismroll`

The daily achievement counts seven different daily mazes; it is not a consecutive-day streak. The coin achievement counts actual maze pickups, not purchases, gifts or the wallet balance. Every leaderboard stores an integer count, sorts descending, and retains the best score. Classic Mazes Completed is the default leaderboard. These cumulative leaderboards are not configured as competitive Challenges.

## Reproduce and verify

Run these commands from the repository root. Python 3, `rsvg-convert`, ImageMagick and an authenticated `asc` CLI are needed. Authentication stays in the CLI/keychain; no credentials are stored here.

```sh
python3 ios/GameCenter/scripts/build_manifest.py
python3 ios/GameCenter/scripts/render_artwork.py
python3 ios/GameCenter/scripts/stage_catalog.py
python3 ios/GameCenter/scripts/stage_catalog.py --verify-only
```

`build_manifest.py` reads achievement text/points from the Swift catalog. Artwork is original, reproducible SVG with the app's violet/pink palette and rolling-ball motif. PNG exports are opaque RGB at 72 ppi: 1024 × 1024 for achievements and 3840 × 2160 for activities. `artwork/contact-sheet.png` shows all achievement designs in catalog order.

`stage_catalog.py` creates missing resources, English localizations and images, then adds activity associations. Each activity has both default and localized artwork. The CLI handles catalog and localized image uploads; the official API handles default activity images because the CLI does not expose that upload relationship. The script checks existing metadata instead of silently overwriting differences. It never creates releases, submits review content, uploads a build, or modifies an app version. `--verify-only` performs reads only. A mismatch or unfinished image processing stops the script.

`staging.json` records successful writes and verified remote IDs. `verification.json` is a subsequent read-only snapshot. Reports retain resource IDs and local image hashes, not authentication material or upload URLs. Verification checks remote metadata, image dimensions and delivery, component version states and absent releases. Activity associations and the disabled party-code setting are checked with Apple's read API using a short-lived CLI token held only in memory. These checks do not establish authenticated GameKit behavior on a device.

## Publication state and next app review

These resources are staged in `PREPARE_FOR_SUBMISSION`, not live. On 2026-09-16, existing iOS 1.1.0 was already `WAITING_FOR_REVIEW` and 1.0.0 was available for distribution. Both had Game Center enabled. That submission was left unchanged.

Apple requires the first Game Center components to be reviewed in the same submission as a Game Center-enabled app version. After the new binary containing this integration has been uploaded and validated, prepare its editable app version, keep Game Center enabled, and add all 20 component **version IDs** from `verification.json` to that version's draft review submission. Use these item types:

| Catalog entries | Review item type | Identifier to attach |
| --- | --- | --- |
| 12 achievements | `gameCenterAchievementVersions` | Each `achievements[].versions[].id` |
| Five leaderboards | `gameCenterLeaderboardVersions` | Each `leaderboards[].versions[].id` |
| Three activities | `gameCenterActivityVersions` | Each `activities[].versions[].id` |

The supported command for adding each component to the chosen draft is:

```sh
asc review items add --submission DRAFT_SUBMISSION_ID --item-type gameCenterAchievementVersions --item-id COMPONENT_VERSION_ID
```

Use the corresponding item type from the table for leaderboards and activities. The same draft must contain the new `appStoreVersions` item; do not attach these first components to an old binary without the integration. In the App Store Connect UI, the equivalent is Game Center → component → Add for Review → the new app version's existing draft submission. Review and submit that complete draft only as part of the separately authorized app release.

Official references: [submit Game Center components](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components), [enable Game Center for an app version](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-an-app-version-for-game-center), [Game Center artwork and design](https://developer.apple.com/design/human-interface-guidelines/game-center).
