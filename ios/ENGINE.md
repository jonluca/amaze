# Engine verification

Audited September 6, 2026, using Swift 6.4 with `swiftc -O` on an Apple M4 Max, macOS 27.0. These are local elapsed-time measurements, including scheduling delays, not physical iPhone frame-time measurements.

## Generation and movement

`MazeLevel.generate(number:mode:)` seeds SplitMix64 from the level number and mode. It grows boards from 4×4 to at most 9×9, considers at most 12 random layouts, and retains a strongly connected region of the **slide graph**. Graph transitions run all the way to the next wall; ordinary walking connectivity is insufficient for this game.

The retained region is validated again: every paintable tile must lie on a reachable slide, and every reachable stopping point must return to the start. This prevents permanent traps after a player takes a different route. Repeated breadth-first searches find the next unpainted tile and construct a complete, executable covering solution. A perimeter board provides a bounded, solvable fallback if no candidate passes.

`MazeRun` paints the starting tile and counts only effective moves. Hints follow the saved route; deviations trigger a new covering route. `hintIsGuaranteed` describes feasibility within the remaining **move** budget, not remaining clock time.

The three persisted mode values are:

- `endless`: unlimited moves and time.
- `challenge`: solution length plus `max(2, solution length / 5)` moves. Finishing on the final move succeeds. A rewarded extra-move grant can revive a failed run; the grant persists and resets on retry.
- `timed`: Time Rush, with `max(30, 2 × solution length + 15)` seconds. The app owns elapsed time, background/modal pauses, expiry, and rewarded extra time; the pure engine generates the board and budget.

## Coins and challenges

- Every fifth endless board has three deterministic coin tiles, excluding the start. Passing through a tile collects it, including tiles in the middle of a slide. Each tile awards 5 coins once per mode, level, and cell, even across retries and relaunches.
- A completed normal level awards 50 coins once. Its earned ad-bonus callback can award another 50 once. Twelve ball skins cost 0–2,200 coins; purchases use catalog prices.
- Daily login rewards begin at 25 coins, add 5 per consecutive day, and cap at 55. Missing a day resets the displayed streak and the next reward. Day identity uses Gregorian dates in the supplied local time zone; duplicate-day and clock-rollback claims are denied.
- A daily challenge uses a deterministic date seed and a move-limited board with no coin tiles. Its 100-coin reward and completion streak are separate from ordinary progression, so it cannot advance a normal level frontier.
- Four one-time milestones reward 5 normal completions (75 coins), 25 completions (200), 10 actual Time Rush completions (200), or ownership of 4 distinct skins (150). Unlocking/skipping a level does not count as completing it.

## Measured results

The audit generated and solved **9,000 regular boards**, covering all three modes for levels 1–1,000, 1,000,000–1,000,999, and the highest 1,000 positive `Int` values. Every board passed slide-graph validation, its complete solution, and a partial-run JSON save/restore followed by completion through hints.

| Measurement | Median | 95th percentile | Maximum |
| --- | ---: | ---: | ---: |
| Regular board generation | 0.445 ms | 1.410 ms | 5.722 ms |
| Time Rush generation | 0.448 ms | 1.412 ms | 5.722 ms |
| Daily board generation | 0.564 ms | 2.533 ms | 28.999 ms |
| Player deviation and hint replanning | 0.042 ms | 0.065 ms | 1.820 ms |
| One partially played run, encoded as JSON | 1,797 bytes | — | 2,518 bytes |

All 9,000 regular board geometries/start positions were distinct, excluding mode and level number from the comparison. None used perimeter geometry. The three ranges had median solutions of 29, 29, and 30 moves; the largest solution used 65 moves. No high-number overflow was observed. Time Rush budgets ranged from 30 to 143 seconds, with a median of 73 seconds.

The audit also verified all 600 coin boards and 1,800 collectible tiles, including duplicate awards after save/restore. A separate run generated, solved, and awarded **365 daily boards** for calendar year 2026 in `America/Los_Angeles`. All daily geometry/start combinations were distinct. Both streaks reached 365, awarding 19,970 login coins and 36,500 daily-completion coins, with repeated claims rejected and normal frontiers unchanged. All four milestones rejected premature claims, awarded 625 coins after qualifying, and rejected duplicate claims after restoration.

An independent exhaustive state search found the exact optimum for the first 25 challenge levels. Their actual optima were 6–24 moves. Generated solutions were a median 1.09 times optimal. Budgets were a median 1.33 times optimal, ranging from 1.20 to 1.80 times optimal. This gives some recovery room while preserving a finite move objective.

Three new processes produced the same canonical fingerprint, including mode, layout, solution, move/time budgets, and coin cells:

```text
eb3d70aa75656d8688c8ab2805090f4ab2fa863503ee2f2d2cbe0b08744802fb
```

All **31 pure unit tests passed in 6.15 seconds**. Coverage includes 1,050 deterministic generated solutions across three modes, 200 independent reachability checks, 100 random-deviation recoveries, 200 additional timed levels, 100 daily boards, extra-move revival, coin/milestone idempotency, v1 save fixtures, DST transitions, rollback, and missed-day resets. UIKit/app lifecycle tests are separate from this package.

## Backward migration and limits

- Custom Codable decoding accepts original v1 payloads. Existing `points` remain the coin balance; preferences, purchased/selected skins, frontiers, completion counts, and reward ledgers are retained. Missing timed/daily/coin/milestone state uses defaults. Original boards retain their saved shape and hint route, with no timer, coin tiles, or extra moves added during restoration. The app can carry this state into its v2 snapshot.
- Saved runs include the board, paint state, moves, extra-move grants, and remaining hint route. Restoration does not require regeneration. Round trips preserve values; raw JSON byte order is not canonical because several fields are sets.
- The caller awards completion only after a valid finish, and ad benefits only from earned-reward callbacks. Daily challenges have a separate date ledger; coin tiles, milestones, base completions, and ad bonuses each retain their own replay protection.
- A save with 10,000 completions and 5,000 bonuses measured 223,707 bytes. Local ledgers grow with use; there is no cloud synchronization or trusted server clock.
- “Endless” is a procedural sequence with bounded board sizes. Uniqueness across the entire sequence is not guaranteed. Difficulty varies between seeds and stops increasing in board dimensions after level 26.
- Covering solutions are feasible rather than globally shortest. A false `hintIsGuaranteed` is not proof that a challenge has become impossible: a shorter remaining solution may exist. Reset is always available.

## Reproduce

From the repository root:

```sh
swift test --package-path ios/EnginePackage
swiftc -O ios/PrismRoll/Core/*.swift ios/scripts/EngineAudit.swift -o /tmp/prism-engine-audit
/tmp/prism-engine-audit
/tmp/prism-engine-audit --fingerprint-only
```

The audit script is outside the iOS application target. Its exact shortest-path search is capped at 250,000 states and reports `-1` if that measurement cap is reached; runtime gameplay does not run that exhaustive search.
