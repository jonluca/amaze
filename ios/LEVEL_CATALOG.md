# Shared numbered levels

A regular level is identified by its mode and positive level number. Every player
gets the same board for that pair. Nonpositive numbers normalize to level 1.
Generation uses SplitMix64 with fixed mode salts, stable cell/direction ordering,
and explicit seed variations. It does not depend on installation, player, date,
clock, device speed, or Swift hash order. Coins use a separate fixed seed.
Time Rush stages use an explicit difficulty number alongside their seeded identity.

## Unique Classic levels 1–1000

`MazeClassicSeedCatalogGenerator` builds the catalog offline in level order. For
each level it selects the first deterministic seed variation that passes the
existing difficulty/playability requirements and has a wall layout distinct from
all earlier selected levels. The current catalog contains 1,000 distinct layouts
even when starting positions are ignored.

`MazeClassicBoardSeeds` bundles the selected variations. Opening a level performs
one immutable lookup and bounded generation; it never generates preceding levels
or scans the catalog. `Validation/PerfectCounts/classic-seeds-1-1000.json` records
the selected seeds and current grids. There are no original-board reservations,
replacement histories, or compatibility versions for this unreleased catalog.
Other modes and Classic levels above 1000 use procedural generation.

```sh
swift run --package-path ios/EnginePackage -c release MazeClassicSeedCatalogGenerator --check
swift run --package-path ios/EnginePackage -c release MazePerfectCountCatalogGenerator --check
python3 ios/scripts/verify_perfect_counts.py
```

## Perfect counts and progress

The first 1,000 Classic levels bundle exact native minimum counts, matched against
the complete grid and starting cell before use. Live optimal directions are
prepared asynchronously from the actual position and painted tiles. Gameplay
never waits for a proof. Counts are accepted only after an exact optimum and a
legal completing route have been verified.

The Levels tab shows completion checkmarks, best moves, and crowns for verified
optimal runs. Progress records use mode and level number, with a stage index for
Time Rush. Each record includes a compact exact grid identity. A different grid
starts a new record; an unverified move count cannot overwrite a proven minimum.
Saved pending Classic completions that do not match the current catalog are
discarded. There are no separate historical-board records or legacy proof rules.
Daily challenges and Duels do not write numbered-level records.

Completion and coin rewards remain claim-once operations. Matching saved runs
retain position and painted cells; grid identity is checked before reusing run
state or cached proof data. `hasSameGrid(as:)` ignores route and reward metadata.

## Regression checks

`MazeClassicUniquenessTests` checks all 1,000 current layouts, difficulty,
recoverability, completing routes, exact count availability, and deterministic
out-of-order/concurrent requests. `LevelCatalogTests` records current catalog
fingerprints with FNV-1a over sorted cell arrays. Native tests compare independent
reference cases and replay optimal routes. Progress tests verify exact-grid proof
reuse and rejection of unverified counts. See [validation evidence](VALIDATION.md).
