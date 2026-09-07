# Automatic progression and faster swipes

September 6, 2026. Local source changes; the previously uploaded build is separate.

## Changes

- Completed solo levels advance after the final visible slide, without the Keep rolling button or a completion overlay. Time Rush advances between its five mazes and then to the next round. Daily completion returns to the saved solo run; Duel retains its match result.
- The root retains a pending completion through menus, backgrounding, and ad dismissal. Run identifiers reject repeated or stale completion callbacks. Existing interstitial frequency remains four completions and 90 seconds since the previous ad; unavailable ads do not delay progression. Intermediate Time Rush mazes do not trigger ads.
- Optional 50-coin completion bonuses are available on completed Journey rows. Their claim-once ledger and earned-ad callback are retained without interrupting the next level.
- Swipe recognition starts at 8 points instead of 12. Real coalesced touch samples and the lift-off position detect short flicks. Overlapping strokes no longer cancel each other after the first direction is recognized. Each physical stroke still generates only one move; taps, ambiguous diagonals, native controls, sheets, and stale sessions remain protected.
- Individual slide durations are 45–100 ms instead of 70–180 ms. Queued movement accelerates to drain within approximately 100 ms, retaining every original turn, travelled segment, and painted cell. Playback speed stays steady until idle, eliminating the old slow animation tail.
- Saving a move reuses encoded progress while the complete reward/preferences ledger is unchanged. The whole snapshot remains ordinary JSON, saved synchronously after each accepted move. New snapshot fields, including Time Rush courses, are encoded by the original synthesized type. An ambiguous placeholder falls back to ordinary encoding.

## Measurements

These component benchmarks run production Swift code on the development Mac. They are not physical-device touch-latency or GPU frame-pacing measurements.

| Motion at a simulated 60 fps | Before | After |
| --- | ---: | ---: |
| Four-cell slide | 150 ms | 83 ms |
| Ten-cell slide | 183 ms | 100 ms |
| 32 simultaneous queued moves, tail | 983 ms | 100 ms |
| 32 moves arriving 50 ms apart, final tail | 300 ms | 100 ms |

At 480 points/second, the sampled recognizer trace changes from 33.3 to 16.7 ms at 60 Hz. This measures the shorter recognition threshold only. At 120 Hz the same trace changes from 25 to 16.7 ms.

For 300 accepted forward/backward moves, the engine, calendar, coin accounting, encoding, and synchronous UserDefaults pipeline changes from 2.492 to 0.333 ms median with 5,000 completed levels; a 20,000-level stress save changes from 7.928 to 0.684 ms. Fresh saves change from 0.241 to 0.256 ms. Every final archive decodes to the exact expected state. These timings exclude SwiftUI/Combine, audio, haptics, rendering, and OS disk flushing.

Raw ignored evidence is in `artifacts/MotionResponsiveness` and `artifacts/SwipeResponsiveness`, with reproduction instructions, original/revised traces, and logs.

## Validation

- Pure engine/input package: 50 tests passed, including 1,000 consecutive strokes and overlapping/cancelled contacts.
- Five isolated motion tests passed at simulated 30, 60, and 120 fps, including 128 queued turns, paint ordering, complete travelled distance, reset, and exact-once completion.
- Five isolated snapshot tests passed, including 300 consecutive moves, every progress category, failed-encode recovery, and all five Time Rush stages with their shared clock.
- iPhone 17 Pro, iOS 26.1: 20 ten-point flicks outside the board all registered. Three Classic levels automatically advanced to Level 004 with 150 coins, zero moves on the new board, no Keep rolling button, and optional Journey bonuses still accessible.
- Native iOS suite: all 147 tests passed, including rendering, timers, reward ledgers, save migration, StoreKit state, input, and automatic progression.
- Recorded Limited Moves play shows the fully painted final board advancing to the next stable board in approximately 62 ms. The existing preparation indicator appears briefly during that transition. The last budgeted slide finishes before the failure card; retry restores the starting layout and budget.
- All 17 distinct UI regression flows passed across the combined run and focused follow-up. These cover consecutive automatic levels, short flicks outside the board, native controls, accessibility text, Limited Moves completion/failure/retry, Time Rush expiry/pause/restart, first-maze coaching, Daily rewards/replay, Journey resume, skin purchases/cancellation, and relaunch.

The combined run initially passed 15 UI flows. Daily replay was interrupted when the simulator's SimMetalHost process crashed in `MTLSimApplicationContext::newObjectCommand_DEPRECATED`; the app was then killed for losing its Metal XPC connection. Diagnostic excerpts are saved in `artifacts/SwipeResponsiveness/simulator-interruption.json`. The Time Rush restart test also still targeted the old "Restart level" label; its selector now matches "Restart round". Both affected flows passed twice in the isolated follow-up, with no product-code workaround for the simulator-service failure.

Native/UI result bundles are `Regression.xcresult`, `AutoAdvance.xcresult`, and `FocusedRerun.xcresult` under `artifacts/SwipeResponsiveness`. The focused rerun executed four tests with zero failures. The final source also passed `git diff --check`.

The pure package links the production Core, SwipeStroke, SwipeSequence, and tests. Native Xcode tests include UIKit integration and scene rendering. Simulator input proves the short-flick route works; physical-device touch latency and overlapping multi-finger UIKit event delivery are not measured by these tests.
