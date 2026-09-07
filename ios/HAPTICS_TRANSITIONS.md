# Rolling feedback and level transitions

Implemented September 7, 2026. These changes follow the requested feel: continuous feedback during a roll, a short completion rhythm, then vertical progression to the next maze.

## Feedback

- `MazeHapticPlayer` follows the renderer's pending movement, so queued swipes sustain one rolling pattern until the visible ball stops. The model no longer triggers an additional impact on each successful swipe or an early success notification.
- Core Haptics loops a flat 0.24-second continuous pattern at 0.75 intensity and 0.45 sharpness. There is no repeating dip in strength. Completion stops that loop and plays four increasingly sharp, stronger taps over 0.30 seconds.
- Engine and player operations run on an owned serial queue. Preparation starts while the visible board is loading; the swipe path never waits for hardware startup. The engine uses haptics only and stays warm throughout the active gameplay session, reusing players between moves and levels.
- A prepared native impact covers a roll that begins before the engine is ready or when hardware playback fails. That fallback occurs at most once during the current rolling interval and never replays after the ball stops. Hardware failures are logged; another rolling interval can retry without retrying every frame.
- Settings, backgrounding, hidden gameplay, disabled haptics, run replacement, and teardown stop playback. Inactive gameplay releases the hardware; run replacement keeps it warm. Session and hardware identifiers reject stale asynchronous callbacks. Interrupted completion patterns do not replay. A hardware interruption can resume rolling only after a fresh visible-motion frame.
- Reduce Motion keeps an immediate native haptic for each accepted move even though the ball snaps directly to its destination. Devices without Core Haptics use a firm native impact and native success feedback.

The patterns use Apple's [continuous haptic engine](https://developer.apple.com/documentation/corehaptics/chhapticengine), [haptics-only playback](https://developer.apple.com/documentation/corehaptics/chhapticengine/playshapticsonly), and [advanced-player looping](https://developer.apple.com/documentation/corehaptics/chhapticadvancedpatternplayer/loopenabled). They approximate the behavior described by the user; they are not extracted from AMAZE.

## Progression

- Once the final accepted move visibly finishes, the rendered completion phase lasts 0.36 seconds. It uses the display clock and pauses with gameplay. The timer and gameplay input are already stopped for the completed maze.
- Automatic progression sends an ordered, run-scoped event before replacing the model, preserving the completed board independently of SwiftUI update ordering. After the next scene's first frame, a 0.30-second native animation slides the old maze upward and the next maze in from below.
- Input and the countdown resume after the incoming board settles. Manual restarts and mode changes keep their existing direct transitions.
- A stationary, clipped UIKit viewport contains the moving SceneKit view. Preparation resizing, including dismissal of the opening tutorial, preserves the outgoing snapshot's top position and aspect ratio. Resizing during animation settles the current board. Stale callbacks cannot make a replaced board ready.
- Reduce Motion uses a direct reveal. Returning from an interstitial retains the automatic entry intent.

## Level controls

The player's paint progress bar and pause button have been removed. Move counts and Coin Rush counts sit below the level title. Native Settings still suspends gameplay, and the existing background, navigation, and modal guards remain in place. The haptic preference is labeled "Haptics."

## Validation of this local update

- `artifacts/RollingHaptics/Tests.xcresult`: 72 native tests and eight UI tests passed on the compact iPhone simulator. Coverage includes three consecutive Classic levels, short/diagonal swipes outside the board, native controls, accessibility text sizing, Settings suspension, and Time Rush progression, navigation, and restart.
- `artifacts/RollingHaptics/FinalHapticTests.xcresult`: after the Reduce Motion fix, all 41 haptic and renderer tests passed on iPhone 17 Pro. This includes 15 facade/pattern tests, 10 actual-worker tests with delayed or failing injected hardware, and a coordinator integration test proving an accepted instant move reaches haptics exactly once while stale and inactive moves stay silent.
- `artifacts/RollingHaptics/final-source-hashes.json` verifies the workspace haptic, coordinator, view, and affected test files match the final frozen source snapshot. The UI suite ran before the final Reduce Motion addition; the final native suite covers that addition. Screenshots `level-screen.png`, `after-first-swipe.png`, and `settings-screen.png` were visually inspected.
- This update is local only; no new TestFlight upload was performed. Simulator checks cannot confirm physical vibration strength. The test results also retain SceneKit's existing internal QoS runtime warnings.

## Validation of the previous release

The change adds 13 haptic lifecycle/pattern tests, two completion-clock tests, nine transition geometry/lifecycle tests, three viewport layout tests, and five model-event ordering tests. Simulator execution, automated playthrough results, and visual recordings are stored locally under `artifacts/HapticsTransitions/`.

- `FinalTests.xcresult`: 78 native tests and five UI tests passed, including three consecutive Classic levels, fast short/diagonal swipes outside the board, native controls, and Time Rush progression, pause/resume, navigation, and restart.
- `PolishedGeometryTests.xcresult`: all 12 geometry/layout tests and the three-level UI playthrough passed after the final snapshot anchoring adjustment.
- `polished-level-entry.mp4`: the final iPhone 17 simulator recording was inspected frame by frame. The completed board stays visible, exits upward, and the incoming board settles without a blank frame or a downward jump. `level-transition-preview.mp4` is a short excerpt.
- `validation-result.json` records these previous results and source hashes. The earlier softer haptics and level transitions shipped in **TestFlight 1.0.0 (7)**; see [release verification](VALIDATION.md). The stronger rolling feedback and simplified controls described above are a subsequent local change.

Simulator checks validate timing and lifecycle, but cannot validate the physical sensation. Final intensity tuning requires play on an iPhone with Core Haptics.
