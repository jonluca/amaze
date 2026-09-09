# Classic perfect-count proofs

`classic-1-1000.json` stores the current grid, starting cell, exact minimum move
count, and optimal completing route for every Classic level from 1 through 1000.
Coordinates use `row * 16 + column`. `classic-seeds-1-1000.json` stores the selected
seed variations and current layouts, with no historical-board compatibility data.

The seed generator selects unique boards sequentially using the existing
playability and difficulty gates. The count generator calls `MazeNativeOptimizer`
directly, bypassing caches and the bundled table. It accepts only exact optima and
independently replays every swipe on the raw grid. It checkpoints completed proofs
and emits the Swift count table only when all 1,000 records are complete. Both
generators reject duplicate wall layouts.

From the repository root:

```sh
swift run --package-path ios/EnginePackage -c release MazeClassicSeedCatalogGenerator --check
swift run --package-path ios/EnginePackage -c release MazePerfectCountCatalogGenerator --check
python3 ios/scripts/verify_perfect_counts.py
swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark --catalog-only /tmp/bundled-counts.json
```

Run the seed generator without `--check` to regenerate the current catalog.
After an intentional geometry change, `MazePerfectCountCatalogGenerator
--regenerate-changed` retains only matching proof records and solves changed grids.
Ordinary generation and `--check` reject stale geometry. Reusing an identical
grid's exact proof is an offline computation cache, not a compatibility policy.

The independent Python validator checks unique layouts, completing routes, and
exact agreement with all four occupancy masks and counts in the Swift table.
Replay establishes route feasibility and artifact integrity; optimality comes
from the exact native solver. Swift tests check all current boards, deterministic
requests, difficulty/playability, native reference cases, and rejection of
mismatched geometry or starting positions.

Counts are an immutable in-memory lookup in the app. Current-state directions
still require an asynchronous native route proof. Detailed release and test
results are in [VALIDATION.md](../../VALIDATION.md).
