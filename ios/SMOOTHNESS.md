# Smoother rendering and ProMotion

Implemented September 6, 2026 and released in **TestFlight 1.0.0 (5)** on September 7, including the [missed-swipe fix](SWIPE_RELIABILITY.md). See [release verification](VALIDATION.md).

## Rapid queued turns: TestFlight build 9, September 7

The earlier 100 ms queue budget limited when a burst finished, but still made later swipes wait behind older movement. The settling curve also slowed to zero at every wall, including walls with another turn already queued.

Older turns now drain within 8.33 ms of a new accepted swipe. They continue through wall contact without easing to a stop, following each original segment in order. If input arrives mid-slide, continuation starts at the current eased position so the ball cannot rewind or jump. The newest move retains its visible roll and gentle final stop; the entire remaining route still finishes within 100 ms. Isolated slide durations remain unchanged.

Replay measurements using the production Swift timeline:

| Input at 120 Hz, four-cell slides | Previous maximum move-start delay | Revised maximum move-start delay |
| --- | ---: | ---: |
| Two queued swipes | 58.3 ms | 16.7 ms |
| Eight queued swipes | 91.7 ms | 16.7 ms |
| 32 or 128 queued swipes | 100 ms | 16.7 ms |
| Sustained swipes every 25 ms | 83.3 ms | 16.7 ms |

All 72 replay scenarios preserve route order, paint coverage, rolling distance, and exactly-once completion at 30/60/120 Hz. All 13 timeline tests pass; the four new regression tests fail against the previous implementation. Evidence and the reusable benchmark are in `artifacts/RapidMoveLatency/`. These are sampled timeline measurements, not physical touchscreen-to-display latency or a sustained device FPS measurement. This follow-up is released in **TestFlight 1.0.0 (9)**; see [release verification](VALIDATION.md#build-9-testflight-release).

The dedicated iOS 26.1 simulator also passed 45 native checks and four gameplay UI tests, including repeated ten-point flicks, diagonal flicks, native controls, and automatic progression through three mazes. These counts include the 13 timeline tests. `VerifiedNativeAndUI.xcresult` and `verified-native-ui-tests.log` contain the successful run; `verified-gameplay.mp4` and its inspected frames show the rendered board, ball, trail, and paint during play.

## What caused the rough motion

Both the SceneKit game view and its separate movement display link explicitly requested a maximum of 60 FPS. The app also lacked the iPhone high-refresh opt-in. Animated collection previews were capped at 30 FPS.

The movement clock used the previous frame's timestamp, which can produce uneven progress when the display changes refresh rate. Ball movement was linear and stopped at full speed at the destination. Each painted frame also created five new effect geometries and one material; completion created another 34 geometries and 34 materials after scene preparation.

## Changes

- Enable `CADisableMinimumFrameDurationOnPhone` and request up to 120 FPS for both SceneKit and the movement display link. Preferences follow the attached display's capability; iOS still controls power, thermal, and accessibility limits. Collection previews use the same policy. Native SwiftUI/UIKit animations can use the app's ProMotion opt-in.
- Advance to `CADisplayLink.targetTimestamp`. The clock resets on pause, visibility changes, and scene preparation, so returning to play does not consume suspended time. Duplicate or invalid frame timestamps cannot advance or rewind it.
- Use a bounded cubic motion curve with immediate movement and a gentle stop exactly at the wall. Position, rolling distance, and paint crossings share the same curve. Slides retain their 45–100 ms durations and the existing 100 ms queued-motion budget.
- Prepare and reuse eight splash groups and one celebration group: eight geometries, four materials, and 74 mesh nodes total. Geometry, materials, and action templates are created before movement; active splashes reuse the oldest slot once the pool is full. Tiny decorative effects no longer cast shadows. Board lighting, board shadows, and 4× antialiasing remain unchanged.

Apple recommends [ProMotion opt-in and target-frame timing](https://developer.apple.com/documentation/quartzcore/optimizing-iphone-and-ipad-apps-to-support-promotion-displays) and warns that [loading SceneKit resources during rendering can cause stutters](https://developer.apple.com/documentation/scenekit/scnscenerenderer/prepare(_:completionhandler:)). The [AMAZE listing](https://apps.apple.com/us/app/amaze/id1452526406) was used as a play-style reference; it does not establish that app's actual FPS or motion timings, and this pass does not claim measured parity with it.

## Motion measurements

These step the actual production timeline in a native Swift executable. They describe sampled motion, not physical GPU/display performance.

| Ten-cell slide, 100 ms | Previous motion at 60 Hz | Revised motion at 120 Hz |
| --- | ---: | ---: |
| Changing position samples | 6 | 12 |
| Largest frame-to-frame step | 1.667 cells | 1.105 cells |
| Final step into the wall | 1.667 cells | 0.133 cells |

At the same refresh rate the curve deliberately moves slightly faster through the middle to settle gently within the original deadline. All 21 before/after isolated, burst, and sustained-input scenarios finish at the same time. Every queued turn and painted cell is preserved, including revisits. A burst can contain more turns than display frames; no artificial pause was added to display each one separately.

Nine focused timeline tests passed, including 30/60/120 Hz equivalence, 120→60→80 Hz changes, no overshoot, immediate progress, correct paint/rotation, and exact completion. Raw curves and test logs are in `artifacts/SmoothMotion/`.

## App verification

The iOS 26.1 iPhone 17 Pro simulator passed 178 native tests and five gameplay UI tests with zero failures. Coverage includes rapid diagonal flicks, small flicks, automatic level advancement, Time Rush's shared countdown, and Limited Moves failure/retry. The native tests also verify the built app's high-refresh opt-in, changing display cadence, motion/paint equivalence, effect reuse, and Reduce Motion cleanup.

A separate recorded playthrough completed Classic level 30 using 28 short swipes. At move 14 the board correctly had 25 of 46 squares painted and 555 coins; completion collected all three coins, awarded the level reward, and automatically opened level 31 with 615 coins and zero moves. Before/mid/after screenshots, accessibility snapshots, the recording, and extracted motion frames were inspected for board, ball, and paint alignment. The recording is visual evidence, not a physical-device FPS benchmark.

Evidence is in `artifacts/FrameSmoothness/`: `NativeAndUI-Verified.xcresult`, `native-ui-verified.log`, `level-30-playthrough.mp4`, and `playtest-*.png`. Sustained 120 FPS has not been measured on a physical iPhone. The production build 5 IPA independently passed signature, capability, icon, and high-refresh configuration checks before Apple processed it and enabled private testing.
