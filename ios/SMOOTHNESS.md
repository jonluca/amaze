# Smoother rendering and ProMotion

September 6, 2026. Local changes after TestFlight build 4, including the pending [missed-swipe fix](SWIPE_RELIABILITY.md). This pass has not been uploaded.

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

Evidence is in `artifacts/FrameSmoothness/`: `NativeAndUI-Verified.xcresult`, `native-ui-verified.log`, `level-30-playthrough.mp4`, and `playtest-*.png`. Sustained 120 FPS has not been measured on a physical iPhone. These changes remain local and have not been uploaded to TestFlight.
