# Classic move targets

The Classic (infinite levels) heading shows a gold crown and **Perfect: N moves** when the minimum has been proven. This is the number of swipes from the level's starting position, so it stays fixed as the player moves. It also appears on Classic coin boards. Time Rush, Limited Moves, Daily, and Duel keep their existing summaries.

The calculation searches the same immutable grid used by gameplay. It does not treat the generated hint route as proof: Classic level 16's hint route takes 46 moves, while its verified minimum is **38**. Existing saved optimal completions can supply their proven count immediately.

An actor performs the bounded search away from the main actor and retains results for 32 recent grids. Identity includes the grid dimensions, open cells, and start. Leaving a level cancels its view's calculation; cancelled work is not cached. The row reserves its height while loading. Completion verification shares the cache, so meeting a displayed perfect count earns the corresponding crown.

Search is limited to 500,000 states and two seconds. If it cannot prove a minimum, the header displays **Best known: N moves** with a flag instead of a crown, using an executable stored route or a better saved completion. Such a target is achievable but is not labeled perfect. Some larger generated levels require this fallback.

## Validation

Validated on an isolated iPhone 17 Pro simulator running iOS 26.5. Across the focused runs, 27 native tests and four UI tests pass: exact search (including an independent oracle for all 511 nonempty 3×3 grids), bounded/cancelled work, grid cache identity/eviction, truthful fallback counts, progress/crown persistence, and the Classic target through a swipe, mode changes, and restart. A restored Level 16 completion earns a crown at 38 moves and does not at 40.

The final rendered Level 16 screen shows **0 moves** and **Perfect: 38 moves** without clipping. Local evidence is under `artifacts/PerfectMoveCount/`: `FinalChecks.xcresult` contains the eight passing final progress tests, `FinalUI.xcresult` contains the passing target UI test, and `level16-perfect-count.png` / `level16-ui.json` capture the rendered result. Earlier runs contain the passing solver, cache, fallback, and three award UI tests; the initial empty-view loading issue and restart test selector were corrected before the final UI run.
