# Rolling feedback and level transitions

Implemented September 7, 2026. These changes follow the requested feel: continuous feedback during a roll, a short completion rhythm, then vertical progression to the next maze.

## Feedback

- `MazeHapticPlayer` follows the renderer's pending movement, so queued swipes sustain one rolling pattern until the visible ball stops. The model no longer triggers an additional impact on each successful swipe or an early success notification.
- Core Haptics loops a soft 0.24-second continuous pattern with a repeating intensity curve. Completion stops that loop and plays four increasingly sharp, stronger taps over 0.30 seconds.
- Engine and player operations run on an owned serial queue. Preparation is asynchronous; the swipe path never waits for hardware startup. The engine uses haptics only and reuses players between moves.
- Pause, backgrounding, hidden gameplay, disabled haptics, run replacement, and teardown stop playback. Interrupted completion patterns do not replay. A hardware interruption can resume rolling only after a fresh visible-motion frame.
- Devices without Core Haptics use a light native impact and native success feedback.

The patterns use Apple's [continuous haptic engine](https://developer.apple.com/documentation/corehaptics/chhapticengine), [haptics-only playback](https://developer.apple.com/documentation/corehaptics/chhapticengine/playshapticsonly), and [advanced-player looping](https://developer.apple.com/documentation/corehaptics/chhapticadvancedpatternplayer/loopenabled). They approximate the behavior described by the user; they are not extracted from AMAZE.

## Progression

- Once the final accepted move visibly finishes, the rendered completion phase lasts 0.36 seconds. It uses the display clock and pauses with gameplay. The timer and gameplay input are already stopped for the completed maze.
- Automatic progression sends an ordered, run-scoped event before replacing the model, preserving the completed board independently of SwiftUI update ordering. After the next scene's first frame, a 0.30-second native animation slides the old maze upward and the next maze in from below.
- Input and the countdown resume after the incoming board settles. Manual restarts and mode changes keep their existing direct transitions.
- A stationary, clipped UIKit viewport contains the moving SceneKit view. Preparation resizing, including dismissal of the opening tutorial, preserves the outgoing snapshot's top position and aspect ratio. Resizing during animation settles the current board. Stale callbacks cannot make a replaced board ready.
- Reduce Motion uses a direct reveal. Returning from an interstitial retains the automatic entry intent.

## Validation

The change adds 13 haptic lifecycle/pattern tests, two completion-clock tests, nine transition geometry/lifecycle tests, three viewport layout tests, and five model-event ordering tests. Simulator execution, automated playthrough results, and visual recordings are stored locally under `artifacts/HapticsTransitions/`.

- `FinalTests.xcresult`: 78 native tests and five UI tests passed, including three consecutive Classic levels, fast short/diagonal swipes outside the board, native controls, and Time Rush progression, pause/resume, navigation, and restart.
- `PolishedGeometryTests.xcresult`: all 12 geometry/layout tests and the three-level UI playthrough passed after the final snapshot anchoring adjustment.
- `polished-level-entry.mp4`: the final iPhone 17 simulator recording was inspected frame by frame. The completed board stays visible, exits upward, and the incoming board settles without a blank frame or a downward jump. `level-transition-preview.mp4` is a short excerpt.
- `validation-result.json` records these results and final rendering/haptic source hashes. The checked changes ship in **TestFlight 1.0.0 (7)**; see [release verification](VALIDATION.md).

Simulator checks validate timing and lifecycle, but cannot validate the physical sensation. Final intensity tuning requires play on an iPhone with Core Haptics.
