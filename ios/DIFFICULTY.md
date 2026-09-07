# More demanding maze progression

September 6, 2026. Local source work; release build 3 is separate.

## Why the previous levels felt easy

An independent audit sampled 200 Classic and Limited Moves boards, including levels 1–20 and four later bands. Its initial search solved 36 small boards exactly. An extended search resolved all 40 early baseline boards and 39 of the 40 revised boards using breadth-first search over position and painted tiles.

- Classic levels 1–3 each needed only six swipes. Levels 6 and 7 still needed seven, and level 15 dropped to nine after level 11 needed seventeen.
- Limited Moves level 6 had no stopping point with three legal directions and needed six swipes. Levels 7 and 10 also needed six.
- Among 17 early Limited Moves boards solved exactly, the allowed budget averaged 40% above the optimum. Level 11 allowed eighteen moves for a ten-move solution; level 20 allowed twenty for twelve.
- Later feasible-route averages plateaued around 25–31 moves. The old generator selected for covered area more than decisions, and its final fallback was a simple perimeter loop. That fallback did not occur in this particular sample.

Raw baseline metrics and representative boards are in `artifacts/Difficulty/baseline.json` and `baseline-boards.json`.

## Generation approach

Difficulty considers actual stopping-point choices, dead ends, the number of path segments needed to cover the board, and the length of a verified route. A wide open room should not qualify merely because it contains many tiles. Every reachable stop remains connected back to the start; Limited Moves still requires finishing within its budget.

For a structural lower bound, each unpainted tile connects its horizontal and vertical corridor segments in a bipartite graph. Every swipe can cover only one segment. Maximum matching gives the minimum segment cover by [König's theorem](https://algs4.cs.princeton.edu/code/javadoc/edu/princeton/cs/algs4/BipartiteMatching.html). Applying that result to the maze gives a lower bound on swipes, not an optimal route: it ignores travel and whether an entire segment can be painted in one move.

The generation-only route planner uses bounded exact search on early small boards and otherwise compares deterministic covering orders. Difficulty is evaluated after this improvement, reducing dependence on the original greedy route. Structural floors also apply, and larger feasible routes are not assumed optimal. The live hint solver and the separate five-maze Time Rush course retain their existing behavior.

## Revised curve and measurements

The configured route ranges are verified executable solutions. The first five Classic boards and first Limited Moves board use exact shortest routes; larger boards do not claim optimality.

| Classic levels | Board size | Verified route range |
| --- | --- | --- |
| 1 | 5×5 | 7–8 swipes |
| 2–3 | 6×6 | 10–14 swipes |
| 4–5 | 6×6 | 12–16 swipes |
| 6–10 | 7×7 | 16–24 swipes |
| 11–20 | 8×8 | 20–28 swipes |
| 21–79 | 9×9 | 25–38 swipes |
| 80 onward | 10×10 | 30–45 swipes |

Limited Moves starts at 6×6 with 12–17 swipes, rises to 7×7 at level 2 and 8×8 at level 6, and reaches 33–45-swipe routes on 10×10 boards. It allows three moves beyond the verified route through level 5, two through level 20, and one thereafter.

In the independent 200-board comparison:

- Classic levels 1–5 change from exact minima of **6, 6, 6, 7, 9** to **8, 13, 14, 15, 16**. All twenty early Classic boards were solved exactly in both versions: the average increases from **11.1 to 19.1** required swipes, or 72%.
- Mean early Classic branching stops increase from **4.55 to 8.75**; the lower bound on unavoidable repeated tile traversal rises from **0.4 to 2.85**.
- Mean early Limited Moves branching stops increase from **5.15 to 12.2**, with verified routes averaging **26.05** instead of **13.1** swipes. Across the nineteen early levels solved exactly in both versions, actual minimum moves increase from **10.58 to 23.21**, or 119%, while excess move budget falls from **39.6% to 20.7%**. Revised Limited Moves level 16 reached the audit's search cap; its lower bound is 23 swipes and its verified route uses 32.
- Each 20-board band contains **19–20 distinct shapes**, even after ignoring rotation/reflection. No perimeter loops were generated. Eighteen of 200 boards match the stronger fallback layouts.
- Optimized Swift generation on the development Mac has band medians of **4.6–7.2 ms** and a maximum of **8.55 ms** in this sample. This is a generator component benchmark, not an iPhone frame-time measurement. Candidate search is capped at 48 attempts; the fallback is a validated branching layout.

## Validation

Five focused difficulty tests passed, covering 206 boards, deterministic generation, complete executable solutions, recoverability from every stopping point, all fallback orientations, and independent small-board searches. Three focused coin-migration tests and four Duel handshake tests also passed.

All **161 native test cases** passed across the main run and an isolated camera rerun on the iPhone 17 Pro simulator (iOS 26.1). The main command returned exit 65 because the simulator's `SimMetalHost` graphics service crashed during the camera-bounds test; its 160 other native cases passed. The interrupted camera test then passed all three isolated repeats. No application workaround was added for the simulator service failure. Logs and diagnostic excerpts are in `artifacts/Difficulty/native-tests-final.log`, `camera-rerun.log`, and `simulator-interruption.json`.

All **eight selected UI flows** passed: repeated ten-point flicks outside the board, three automatic Classic advances, Limited Moves completion, failure/retry, progression/shop/relaunch, five-maze Time Rush shared clock and restart, Daily replay without duplicate rewards, and Journey resume/restart. Native compatibility tests additionally preserve old saved geometry, extensions, skins, and same-day Daily rewards.

A separate playthrough loaded a generated Classic 30 save into the QA simulator: **9×9, 46 playable tiles, 11 branching stops, and a 28-swipe verified route**. Twenty-eight 36-point, 50 ms touch gestures completed it. At the midpoint, the displayed position and painted count exactly matched the independently calculated state (row 1, column 6; 25/46 tiles). Completion collected all three coins and advanced automatically to level 31 with zero moves and 615 coins (550 starting balance + 15 collectibles + 50 completion). Screenshots were inspected before play, halfway through, and after advancement; the board and controls remained readable.

Evidence: `artifacts/Difficulty/NativeAndUI-Final.xcresult`, `CameraRerun.xcresult`, `ui-attachments/`, `manual-playthrough.json`, and `classic-30-before.png`, `classic-30-midpoint.png`, `classic-31-after.png`. Touch duration describes the injected gesture, not a measured physical-device latency. Live ads were disabled during UI playtesting. This local pass was not uploaded to TestFlight or App Store Connect.

## Compatibility

- Saved active Classic, Limited Moves, and same-day Daily runs retain their original geometry, paint, hints, and earned extensions. New levels use the updated generator. Replay resets the saved board; reopening a completed level can generate its updated layout.
- Collectibles keep a three-coin lifetime allowance per mode and level. Legacy coordinate keys are counted once when loading. Moving coins in a regenerated layout cannot repay a previously collected allowance. Partial collections retain only their remaining slots, without a per-move history scan.
- Completion bonuses and Daily rewards retain their existing identifiers and claim-once ledgers.
- Duel matchmaking and its invite/wire handshake use generator protocol version 2. Different generator versions cannot start a race with different boards. Live two-account matchmaking remains a separate validation requirement.
