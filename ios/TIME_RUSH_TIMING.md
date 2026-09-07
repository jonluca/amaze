# Tighter Time Rush timing

September 7, 2026. Local changes after TestFlight 1.0.0 (6); not yet uploaded.

Build 6 allowed 0.95–0.75 seconds for every move in a stored covering route, plus ten seconds and a one-minute minimum. That route can include inefficient travel. Charging the same allowance for painting and predictable returns produced overly long rounds.

The revised budget replays each of the five stored solutions once:

- A successful swipe that paints new ground gets 0.50 seconds in round 1, decreasing by 0.0075 per round to 0.35 from round 21 onward.
- A successful swipe over already-painted ground gets 0.16 seconds.
- Each maze gets one second of reading allowance. The combined budget rounds up to five seconds; there is no one-minute floor.
- Blocked moves and unused moves after completion do not inflate the budget.

| Round | Build 6 | Revised |
| --- | --- | --- |
| 1 | 2:00 | 0:55 |
| 5 | 5:25 | 2:10 |
| 10 | 6:30 | 2:30 |
| 20 | 8:20 | 3:00 |
| 40 | 7:05 | 2:50 |

Maze geometry, solution paths, difficulty progression and rewards are unchanged. All five mazes still share one clock. Loading, menus, background time and reward videos remain excluded; an earned video still adds 30 seconds.

## Saved rounds

An already-started round keeps its exact stage, paint, remaining fractional time and earned extensions. Restart applies the new budget to the same saved mazes and resets the full round as before. A pristine, unstarted saved round adopts the tighter budget when restored; previously earned extra seconds carry over. The updated course is persisted so subsequent restores cannot repeatedly adjust rewards.

## Validation

An independent optimized Swift probe covered rounds 1–100. Revised budgets range from 55 to 185 seconds, and every budget is below 46% of its build 6 allowance. All stored solutions fit at four swipes per second plus one second per maze, with at least 16 seconds left. This demonstrates mechanical feasibility; it does not measure human completion rates.

Budget replay itself averaged 0.04–0.37 ms per five-maze course across seven sample rounds, measured over 1,000 repetitions on the development Mac. These are CPU measurements, not physical-device frame-rate measurements. The new calculation does not run per frame or per player swipe.

All **83 engine/input tests passed**, including ten course tests. **32 native state tests and one real-touch UI flow passed** on iPhone 17 Pro / iOS 26.1. The native cadence regression drives the actual game store through all five stages with a virtual clock: focused play completes rounds 1 and 20 without ads, while 0.8-second swipes expire in round 1 even though that route would fit the previous 120-second budget. Active-save preservation, pristine-save migration, earned extra time, restart and snapshot persistence also pass.

The UI flow completed maze 1 with 48 seconds left, resumed the same second maze through Pause and Journey, and restarted at zero moves with 55 seconds. The second-maze and restart screenshots were visually inspected. Native/UI validation used an isolated build 6 source snapshot plus the six timing-related Swift files; concurrent depth/color and haptics edits are outside that snapshot. The timing methods in the working tree match the tested copy.

Evidence is in the ignored `artifacts/TimeRushTiming/` directory: the independent 100-round report and probe, replay-cost measurements, source hashes, and test logs.
