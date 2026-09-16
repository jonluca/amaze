# Native Game Center integration

The app initializes Game Center once per launch. The dedicated Game Center page
is reachable from Challenges and Settings and shows device progress, achievements,
and links to Apple's all-leaderboard, individual-leaderboard, and achievement
dashboards. Solo gameplay remains available while signed out or offline.

When GameKit cannot present sign-in, the page directs the player to Settings →
Game Center. Check sign-in status reuses the original authentication observer and
any pending sign-in controller. A completed signed-out attempt keeps the Settings
guidance visible without waiting for another GameKit callback.

Game Center presentation waits for consent, ads, rewards, existing sheets, and
their dismissal transitions. Delayed authentication does not interrupt a maze
after its first move; it waits for a menu or completed run. The native controller
pauses the game clock and disables maze input until dismissal completes.

## Reporting and account ownership

`GameStore.gameCenterProgress` changes only after the wallet/progress save succeeds.
Counts come from distinct completed-level records and exact Perfect proofs. An
unlocked frontier, skipped level, replay, purchased coin, reward video, or login
reward cannot increase a leaderboard count. Five proved Time Rush stages count as
one Perfect round, and only after that round has been completed.

The first authenticated player adopts existing saved progress. Later accounts
receive only gameplay increments earned after their own activation; prior account
queues remain separate. Local maze saves and the wallet remain shared on this
installation. Game Center is not a cloud-save or wallet-transfer service. Another
device's progress is not added to this device's cumulative totals; Apple retains
the player's best submitted leaderboard scores and achievement percentages.

The durable report ledger keeps per-player pending values and acknowledgements.
Only a successful GameKit callback acknowledges the exact value sent. Newer
progress during a request remains pending; late callbacks from another account
are ignored. Per-counter high-water marks prevent restoring an older save from
earning the same totals again. Foregrounding, connection recovery, new saved
progress, and the Sync progress button retry pending reports. A failed resource
does not block other reports. Existing achievements are fetched before reporting
fresh completion banners, so historical backfills do not produce a banner storm.

## Apple Games activities

On iOS 26 and newer, a local-player listener is registered before authentication
to accept cold launches for the three configured activity identifiers. Unknown
identifiers are rejected. Accepted activities wait for the same safe navigation
conditions as Game Center UI, then open Classic, Time Rush, or the daily maze.
Opening an expired Time Rush round starts a fresh attempt. Activity timing pauses
with gameplay; activities end on completion, failure, sign-out, or a mode change.
iOS 17–25 retain authentication, achievements, and leaderboards without Activities.

Existing shareable puzzle links remain available. The cumulative leaderboards are
not configured as native competitive Challenges, because comparing lifetime totals
would not represent a fair individual challenge attempt. Real-time Duel remains
hidden and does not install a competing Game Center authentication handler.

## Validation

The focused native suite covers counting, migration, exact IDs, account switches,
backfill banners, failed reports, in-flight newer progress, queue restoration,
rollback deduplication, controller presentation gates, failed save suppression, and
Games activity routing. UI tests cover signed-out solo play, Settings-to-Game Center
navigation, dashboard dismissal, and accessibility text sizes.

On 2026-09-16, the isolated iPhone 17 Pro simulator running iOS 26.5 passed the
31-test focused native/UI suite (`ios/artifacts/GameCenter/Final.xcresult`). After
the live signed-out check exposed GameKit's absent callback on reauthentication,
the fix and two new service regressions passed together with all three UI tests:
eight passing tests in `SignInRegression.xcresult`, or 33 distinct native/UI tests
across the two runs. The 10 progress/activity tests also passed in EnginePackage.
SwiftLint, SwiftFormat, and `git diff --check` passed. The service typechecks for
iOS 17. Final screenshots are in `ios/artifacts/GameCenter/final-screens`.

The app was then launched with live GameKit and no test fixture. Repeated Check
sign-in status taps retained the Settings guidance and usable local score page;
`ios/artifacts/GameCenter/live-final-retry.png` records the result. The simulator
has no signed-in Game Center account, and the connected physical iPhone was
unavailable. No signed-in score or achievement submission is claimed.

`PRISM_GAME_CENTER_STATE=authenticated` and `offline` are Debug-only fixtures. UI
tests never authenticate or submit real scores. A fixture dashboard verifies
presentation/lifecycle integration; it does not establish an authenticated Apple
server round trip. Release authentication uses GameKit. Live account sign-in,
score/achievement delivery, and launching from the Games app still need a signed-in
device or simulator with the integration build and the staged catalog.

See [catalog and review staging](README.md) for remote IDs, artwork verification,
and how these first Game Center components join the next app-version review.
