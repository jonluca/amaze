# Swipe direction correction

September 7, 2026. Local fix after TestFlight 1.0.0 (5); not uploaded.

## Reproduction

Build 5 could lock the wrong axis on the first small diagonal motion. For example, a rightward stroke at `(0, 0) → (5, 7) → (14, 7) → (30, 8)` emitted down at `(5, 7)` and ignored the clearly horizontal remainder. Its eight-point radial threshold and 1.15 axis ratio admitted that initial wobble.

The native observer also replayed coalesced samples oldest first. A packet containing `(0, 9) → (12, 4)` could therefore commit down even though the newer position in the same event already showed a rightward swipe. At lift-off this happened before the final displacement was considered.

Replaying 24 mirrored/rotated wobble traces and four coalesced packets through the old implementation produced 28 wrong-axis results. The revised implementation produces zero wrong-axis results for those same traces. These are deterministic reproductions, not recordings of the user's fingers or a population-wide error-rate estimate.

## Changes

- Require one axis to lead the other by eight points before committing while the finger is down. Straight eight-point swipes still move immediately. Small initial diagonal drift waits for clearer direction.
- Preserve the eight-point radial travel threshold at lift-off, so short angled flicks still register without a cooldown or timer.
- Choose the newest confident real observation within each touch event. At lift-off, use the complete displacement before consulting older samples. Historical samples still preserve short out-and-back flicks.
- Order different fingers by the earliest confident observation supporting each chosen direction. Newer redundant samples cannot swap the order of two already-clear swipes.
- Retain one move per stroke, cancellation, native-control exclusions, and session checks before each gameplay callback. Already-emitted contacts are removed normally at lift-off.

An already-delivered unambiguous swipe still moves the ball immediately; the recognizer does not retrospectively change a move because the same finger later changes direction.

## Verification

All 25 focused pure input tests passed. Coverage includes the 24 wobble traces, immediate eight-point cardinal swipes, newest-sample and lift-off precedence, 360 short-flick angles, overlapping contacts, preserved chronology, out-and-back motion, duplicate samples, cancellation, and reset.

**34 native input/touch tests and four UI flows passed**, with zero failures. The UI flows verify actual row/column changes for all four angled swipe directions, twenty short diagonal flicks with Pause/Resume, twenty ten-point reversals outside the board, and three automatic level transitions.

These native/UI checks used an isolated copy of the released build 5 source plus this input fix because another task is concurrently changing maze generation and rendering in the shared checkout. All eight input and test files exactly match their tested copies. This validates the input fix against build 5; the parallel maze changes require their own integration checks. Evidence is in `artifacts/SwipeDirection/`: `replay-before.json`, `replay-after.json`, `focused-tests-final.log`, `tested-source.json`, and `NativeAndUI.xcresult`.
