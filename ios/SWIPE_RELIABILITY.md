# Missed fast flicks

Implemented September 6, 2026 and released in **TestFlight 1.0.0 (5)** on September 7. See [release verification](VALIDATION.md).

## Reproduction

The installed build discarded all 20 alternating short diagonal flicks in a simulator HID batch. Each gesture moved 12 points along the intended axis and 11 across it, lasted 25 ms, and began over the level heading. The board stayed at zero moves. The same level's straight swipes worked.

The recognizer required one axis to exceed the other by 15%, even at lift-off. A flick near a diagonal could therefore disappear entirely, regardless of how far it traveled. Its eight-point threshold was also measured independently on each axis, making diagonal flicks less sensitive. Separately, a new finger was ignored whenever another contact had not yet produced a direction.

The store and rendering audit found no animation-based input lock. Valid moves are delivered synchronously to the ordered movement stream. Very tight out-and-back moves can occur within one rendered frame; adding a frame delay per move would create an animation backlog.

## Fix

- Keep early recognition for a clear direction. If a diagonal is still ambiguous at lift-off, resolve its dominant axis instead of dropping it. Exact ties use the vertical axis consistently.
- Use an eight-point radius from touchdown, giving the same travel threshold at every angle. Movements inside that radius remain taps.
- Track each contact independently, even when the next finger lands before the first direction has been recognized. A stationary or cancelled finger cannot block fresh flicks.
- Keep one move per physical stroke, coalesced real touch samples, native-control exclusions, and stale-session cancellation. No cooldown, additional timer, or animation delay was introduced.

## Validation

The new regressions fail against the old implementation. They cover 360 short flick angles, diagonal resolution at lift-off, angled travel below eight points per axis, early overlapping contacts, a stationary contact during 100 fresh flicks, and existing cancellation/one-shot behavior.

- **62 pure engine/input tests passed**, including all 13 swipe-sequence cases. Five of the revised cases fail against the old implementation.
- **165 native iOS tests passed** in one run, including input delivery, rendering, save/reward behavior, controls, and session cancellation.
- **Three UI flows passed** on iPhone 17 Pro / iOS 26.1: twenty ten-point straight flicks, three automatic level advances, and twenty short diagonal flicks followed by Pause/Resume without extra moves.
- The original twenty-flick HID batch changed from **0/20 to 20/20 registered moves**. The ball returned to row 1, column 1 with exactly three of sixteen squares painted, matching twenty alternating down/up moves. A repeat with the simulator's accessibility service refreshed also registered 20/20; the complete batch took 5.58 seconds, including automation overhead. The requested 25 ms gesture duration is not a measurement of touch latency or a 40-swipes/second throughput claim.

Evidence is in `artifacts/SwipeReliability/`: `regression-before.log`, `engine-tests.log`, `native-ui-tests.log`, `NativeAndUI.xcresult`, the exported `ui-attachments/`, `near-diagonal-flicks.txt`, the baseline/fixed accessibility snapshots and screenshot, and `batch-timing.json`. Simulator tests do not measure physical-device touch latency or multi-finger UIKit delivery; overlapping-contact handling is covered by the production state-machine tests.
