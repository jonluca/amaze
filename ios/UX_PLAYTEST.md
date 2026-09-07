# UX playtest — September 6, 2026

This improvement pass followed production build 3 and is now included in **TestFlight 1.0.0 (4)**. The existing App Review submission remains on build 3, and earlier TestFlight builds remain available. See [release verification](VALIDATION.md).

## Changes verified in the app

- Journey resumes an unfinished maze, including its remaining Time Rush clock, instead of resetting it. Earlier/next pages and a first/latest menu make all unlocked levels reachable.
- Replaying a completed daily maze starts a playable run and preserves the one-time reward ledger.
- Restart uses a native alert with explicit Keep playing and Restart actions. The clock pauses while the alert is open; confirmation is scoped to the run that opened it, so a later session cannot be reset accidentally.
- Ball unlocks show their coin price and shortfall. An affordable unlock asks before spending coins. Owned balls equip without a blocking success alert.
- The last accepted roll finishes before success or failure covers the maze. State and input still stop immediately when the run ends.
- Scene loading pauses Time Rush until the board can accept input. Old scene callbacks cannot resume a different run.
- Changing Reduce Motion stops existing movement effects and preview rotation. Large text on compact phones keeps the board above scrollable controls.
- Reward actions explicitly announce the video-ad requirement to VoiceOver. First-play guidance explains rolling to a wall; the move counter handles the singular case.

## Verification

- `FinalTests.xcresult`: all **85 native unit/state/rendering tests passed**, including the final failed-slide regression. Nine of twelve gameplay UI flows passed; the three remaining failures were duplicate native-button selectors.
- `CompactFinalTests.xcresult`: **4 UI flows passed on iPhone SE**, covering Journey resume/restart, paused Time Rush, purchase cancellation/equipping, and ordinary XXXL text in all three modes. This rerun fixes the three duplicate-selector failures above; its large-text scenario overlaps the iPhone 17 Pro run. Across the final runs, all **12 distinct gameplay UI flows pass**.
- `NativeTests.xcresult`: the local StoreKit purchase UI also passed. This earlier run predates the final alert and failed-slide fixes and was not a clean overall run.
- `swift test --package-path ios/EnginePackage`: **31 tests passed**. These overlap native engine coverage and are not additional unique tests.

## Evidence and scope

Local testing uses Xcode 27.0 (27A5209h) and iOS 26.1 simulators, including an iPhone 17 Pro and an isolated iPhone SE (3rd generation). No production archive was created with this toolchain.

The initial run caught a native confirmation popover hiding its cancel action and duplicate accessibility matches on its buttons. These led to native alerts and scoped first-match test queries. The initial runs are retained rather than represented as clean passes.

Actual simulator interactions include rapid short swipes, solving a level, canceling Restart with the timer paused, and browsing from a seeded level-45 Journey back to level 1. The higher Journey frontier was seeded only into an isolated simulator save for pagination coverage. The app has no new debug shortcut for it.

Artifacts are in the ignored `artifacts/UXPlaytest` directory: test logs/result bundles, accessibility snapshots, screenshots, the pagination fixture, and a manual-play recording. Gameplay UI tests use the existing Debug-only no-ad/hint controls. This pass does not establish live production ad serving, two-player Game Center behavior, or App Store sandbox purchases. Local StoreKit checks are reported separately from those services.

The manual recording shows the ball at its last tile with 100% painted before the completion card appears. Native frames and a focused clip are in `artifacts/UXPlaytest/manual-result-frames` and `manual-final-slide.mp4`. This establishes visual ordering on the simulator, not physical-device touch latency.
