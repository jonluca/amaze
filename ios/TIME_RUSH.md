# Time Rush courses

The September 7 [maze growth update](MAZE_GROWTH.md) supersedes the size and timing curve below. The following records the earlier build 4 implementation and its validation.

Time Rush is now a series of **five distinct mazes sharing one countdown**. The first valid swipe starts the round. Each finished maze advances automatically after its final movement settles. The next maze resumes the remaining time as soon as its scene is ready, without waiting for another first swipe. Scene preparation, background time, menus, and reward videos do not consume time.

The opening round uses five 5×5 to 7×7 mazes under 60 seconds. Every three rounds the generator raises difficulty; later rounds reach five 9×9 mazes under 90 seconds. Bounded generation checks playable geometry, an executable covering route, and distinct layouts, with validated asymmetric fallback boards. The other modes retain their existing generators.

The first round contains 109 open cells and a 65-swipe hint route across all five mazes. An independent exact search found a 53-swipe optimal total. Round 25 has a 139-swipe hint route under 90 seconds. These measurements describe this game's balance, not the reference app's rules. Optimized generation measured 1–6 ms on the development Mac across sampled rounds, including extreme round numbers; this is not an on-device frame-time measurement.

## Rewards, retry, and resume

- Maze completions within a round do not award coins, increment completion challenges, unlock rounds, or show interstitials. Finishing all five awards the usual 50 coins once and advances to the next round through the normal between-round ad policy. Optional completion bonuses remain in Journey.
- Rewarded hints target the current maze. Earned +30 seconds extends the shared clock, including after expiration; the current stage, paint, and position remain intact. Duplicate and old-stage callbacks are rejected.
- Restart returns to maze 1 and resets the entire round's clock and extensions. Restart confirmation explains this, including when a later maze has no moves yet. Failure offers free full-round restart or earned extra time on the current maze.
- Journey, mode switches, daily play, Duel, and relaunch preserve the exact course, stage, paint, remaining fractional time, and earned extensions. Old single-maze Time Rush saves start a new course at their saved round number once; currency, ownership, other mode progress, and the existing timed completion ledger remain intact.
- A result that settles while a menu opens stays pending until gameplay resumes. Old input and result callbacks cannot move or skip the next maze.

## Validation

The pure course suite covers 100 rounds (500 executable, recoverable stages), determinism, distinct boards, the difficulty curve, extreme integers, saved-course round trips, and all 40 fallback size/orientation combinations. All eight tests passed in an isolated Swift package using the repository's exact source files.

The combined native suite passed all **147 tests**, including the eight course tests and twelve new session tests, on iPhone 17 Pro (iOS 26.1). Session tests cover shared fractional time, presentation gates, stale input/callbacks, final-only completion and bonus rewards, rewarded continuation, full-round restart, navigation, relaunch, pending transitions, and legacy migration. The cached snapshot encoder also passed its round-stage and shared-clock parity test. Evidence: `artifacts/SwipeResponsiveness/Regression.xcresult` and `regression-tests.log`.

The fresh simulator build and **iPhone SE UI playthrough passed**. Actual short swipes finished maze 1 and automatically entered maze 2 with 54 seconds remaining. The test painted maze 2, paused its shared clock, resumed through Journey with identical board position/paint/moves, verified the clock resumed, and confirmed restart returned to maze 1 with zero moves and 60 seconds. The 32-second test includes four screenshots, inspected for small-screen layout and absence of the bottom completion percentage.

- [Maze 2 with the carried clock](artifacts/TimeRushSeries/time-rush-second-maze-shared-clock.png)
- [Paused mid-round](artifacts/TimeRushSeries/time-rush-paused-mid-round.png)
- [Journey resumes maze 2](artifacts/TimeRushSeries/time-rush-journey-resumes-second-maze.png)
- [Restart returns to maze 1](artifacts/TimeRushSeries/time-rush-restart-resets-entire-round.png)
- UI result: `artifacts/TimeRushSeries/Playthrough.xcresult`; transcript: `playthrough.log`; build: `build.log`.

The broader automatic-advance regression passed 17 distinct UI flows across its initial run and focused follow-up. One initial Daily replay was killed by the simulator's Metal graphics service; two focused repeats passed without an app-code workaround. The Time Rush restart test's old button selector was updated to “Restart round” and passed twice.

This redesign is included in **TestFlight 1.0.0 (4)**. The App Store submission remains on build 3; see [release verification](VALIDATION.md).
