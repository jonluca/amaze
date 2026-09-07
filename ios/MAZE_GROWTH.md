# Larger mazes and sustained progression

September 7, 2026. Local development changes; not yet uploaded to TestFlight.

## Progression

The previous curve held Classic at 9×9 for levels 21–79 and capped the game at 10×10. The new curve increases both the occupied board and the structural work needed to paint it.

| First Classic level | Maze size |
| --- | --- |
| 1 | 5×5 |
| 2 | 6×6 |
| 4 | 7×7 |
| 7 | 8×8 |
| 10 | 9×9 |
| 15 | 10×10 |
| 22 | 11×11 |
| 30 | 12×12 |
| 42 | 13×13 |
| 56 | 14×14 |
| 75 | 15×15 |
| 100 | 16×16 |

At 16×16, the structural requirements continue increasing through levels 150 and 200. Limited Moves uses the next size band, with additional late-game requirements. Its move allowance stays tied to a verified executable route plus three, two, then one spare move. Routes on larger boards are feasible solutions, not claimed optima.

Every accepted maze fills its actual width and height, occupies at least half its board, and meets increasing minimums for independent path-segment coverage, branching stops, dead ends, and unavoidable corridor returns. The most advanced boards require at least 56% occupied area. Validated full-size fallback families meet the same requirements; no smaller maze is padded into larger dimensions. Every reachable stop can return to the start, so a wrong turn cannot permanently trap the ball.

Time Rush follows the same curve across its five stages: round 1 spans 6×6 to 8×8, and round 20 reaches 16×16. The five mazes keep one shared countdown. The budget scales with the total executable route and gradually raises the target pace, instead of imposing the old 90-second ceiling on much larger rounds. Daily Challenge retains its date-based identity at an explicit 12×12 difficulty; a date hash no longer accidentally selects maximum progression.

## Rendering and compatibility

Larger boards progressively use more of the canvas to preserve path readability. Static channel-edge shading was batched into one mesh/material while paint remains independently animated per tile. The final visual design shows a path grid with contour walls and transparent cutouts; the complete 16×16 geometry was visually inspected on the iPhone SE.

Existing saved Classic, Limited Moves, Daily, and Time Rush runs retain their exact geometry, paint, hints, clock, stage and extensions. New levels and new courses use the new generator. Currency, skins, daily streaks and claim-once reward ledgers retain their existing identifiers. Duel's generator handshake advances to version 3 to reject races between incompatible generators.

## Validation

Validation evidence and measurements are recorded under `artifacts/MazeGrowth/`. The independent audit measures occupied spans, area, branching, required return steps, and a swipe lower bound separately from the stored covering route. Mac CPU timings are not physical-device frame-rate measurements.

### Measured change

| Classic level | Previous board / playable cells | New board / playable cells |
| --- | --- | --- |
| 20 | 8×8 / 38 | 10×10 / 67 |
| 40 | 9×9 / 58 | 12×12 / 87 |
| 100 | 10×10 / 64 | 16×16 / 157 |

The level-100 independent witness bound rises from 17 to 54 swipes, branching stops from 18 to 42, and required repeated leaf-corridor steps from 5 to 18. Those are geometry measurements independent of the stored route's efficiency. The final first Time Rush round contains 113 route moves over five mazes under 120 seconds.

Across 100 sampled levels per mode at levels 1000–1099, the final generator produced 99 distinct Classic layouts, 96 Limited Moves layouts, and 97 timed layouts. After removing rotations/reflections there were 86, 80, and 82 shapes respectively. Exact fallback usage was 2–4%; all 272 fallback family/orientation combinations remained playable.

Fresh-process optimized Mac measurements: Classic 1 cold 1.76 ms; Time Rush 1 cold 12.43 ms; Time Rush 40 cold 47.01 ms. The largest measured fresh hint among the 72 audited boards was 0.40 ms. Full values and source hashes are in `artifacts/MazeGrowth/comparison.md`, `after.json`, `performance.json`, and `after-source-sha256.json`.

### Regression evidence

- The initial integration snapshot passed all 201 native tests on iPhone 17 Pro / iOS 26.1, including 272 fallback orientations, 500 Time Rush stages, rendering bounds, rapid painting, old saved courses, and claim-once rewards: `Native.xcresult`, `native-summary.json`, and `native-initial-source-sha256.json`.
- The final generator's preferred-start change passed all 80 distinct pure engine/input tests across the full run and one focused test correction. The correction removes an obsolete assumption that every starting position blocks upward movement; it now tests an actual adjacent wall. Evidence: `engine-final.log` and `engine-blocked-regression.log`. Other test failures were absent.
- The simulator's optional post-test diagnostic collection stalled after all native tests completed. Its diagnostic child was stopped; `xcodebuild` then exited 0 and its finalized result reports 201 passed, zero failed or skipped. This did not stop or bypass any test.

- The final generator integrated with the new visual design passed 37 additional native checks (geometry, rendering, save compatibility, Time Rush sessions and blocked swipes) and five real-touch UI flows, including shared-clock maze advancement, pause/Journey resume, restart, rapid swipes, and automatic level advancement: `artifacts/OpenBoard/NativeAndUI.xcresult`. These counts overlap earlier suites.

- Final iPhone SE playthrough completed Classic 100 with 115 real swipes and automatically advanced to 101. At 50 moves, actual and independently calculated position/paint matched exactly (row 4, column 14; 96/157 tiles). The final state was level 101, zero moves, 1/150 tiles painted, and 615 coins from an initial 550 (three five-coin pickups plus the 50-coin completion reward). All paths and controls fit the small screen. Evidence: `artifacts/OpenBoard/se-playthrough-proof.json`, `se-first50-proof.json`, the 50/65-step swipe logs, and the visually inspected [midpoint](artifacts/OpenBoard/se-level100-mid.png) and [next level](artifacts/OpenBoard/se-level101.png) screenshots.
