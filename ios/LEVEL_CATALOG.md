# Shared numbered levels

A regular level is identified by its persisted mode and positive level number.
Classic (`endless`) level 10 therefore has the same dimensions, open cells, start,
coins, and generated route for every installation. Each mode has its own catalog;
Classic level 10 and Challenge level 10 are different puzzles. Nonpositive input
numbers normalize to level 1.

`MazeLevel.generate(number:mode:)` uses a fixed SplitMix64 seed derived only from
the number and an explicit mode salt. There is no player identifier, installation
seed, date, system random generator, device speed, or wall-clock deadline in level
generation. Coins use their own fixed seed so collectible placement cannot consume
maze randomness. Time Rush course stages use the separate, explicit
`difficultyNumber` input to combine a seeded stage identity with round difficulty.

Every decision that can select a different board or route has a fixed traversal
order: row/column cell sorting, candidate attempts, route priority, and fallback
catalog order. `MazeSolver` keeps its directional tie order explicit instead of
depending on the declaration order of input/UI enum cases. Remaining unordered
Set/Dictionary traversals only accumulate unions, counts, or reachability, where
iteration order cannot change the result. Generation work is bounded by attempt
and state counts, never a timing cutoff.

These numbered identities are a compatibility contract. Changing a seed, difficulty
curve, fallback, route tie-break, or candidate gate can replace a player's puzzle
even if the generator is still deterministic. Preserve the frozen catalog fixtures;
do not refresh them merely to make a changed generator pass. New generation rules
that change existing grids need a separate content identity and explicit migration.

`MazeLevel.hasSameGrid(as:)` compares dimensions, starting cell, and open cells.
Saved paint and position can remain valid when route, coins, or limit metadata
changes; they cannot be carried onto a different grid.

## Regression checks

`LevelCatalogTests` freezes 51 complete level fingerprints covering all three modes,
board-size boundaries, late difficulty changes, coin levels, and the largest level
number. It also spells out the three level-10 grids for readable review. The test
fingerprint uses explicit FNV-1a and sorted cell arrays, never Swift's randomized
`Hasher` or raw Set JSON order.

The separate process audit compares the full canonical level descriptions across
four processes, with randomized and fixed Swift hashing and both forward and reverse
generation order. This also checks that lazy fallback preparation does not change
the generated catalog.

From the repository root:

```sh
swift test --package-path ios/EnginePackage --filter LevelCatalogTests
swiftc -O ios/PrismRoll/Core/*.swift ios/scripts/LevelCatalogAudit.swift -o /tmp/prismroll-level-catalog-audit
/tmp/prismroll-level-catalog-audit
```

The audit helper is outside the iOS application target.

## Saved completion and crowns

The Levels tab replaces the Journey label and keeps per-mode progress, replay,
resume, and claim-once rewards. Pages contain 20 rows and can continue beyond the
unlocked frontier; a direct number jump reaches any positive level. Locked levels
remain visible but cannot be opened.

Checkmarks come from the existing completion ledger, so older saves retain their
solved status and skipped levels do not count as solved. New completed runs record
the player's lowest move count. A crown requires an exact proof from
`MazeOptimality`; matching the hint route is not enough. Its bounded search may
leave a difficult solve unverified, in which case the best move count and checkmark
are still saved. An older save has no historical move counts or optimal proof,
so replaying is required to establish a crown.

GameStore owns verification away from the UI actor. It captures the completed
board and Time Rush stage, persists the result even after navigation, and shares
the result with the perfect-solve celebration. A later, slower replay never removes
an earned crown, and recording a new best never awards duplicate coins. Daily
challenges and Duels do not write numbered-level records.

Time Rush records mastery for each of the five stage grids. Its round crown means
the round has been completed and all five stages have been solved optimally, which
can be achieved across replays. Stage bests are not added into a purported best
single-round move count.

On loading older saves, GameStore compares each regular saved board with its shared
catalog grid. An identical grid keeps its exact run and timing metadata. A differing
grid starts fresh; a differing Time Rush course restarts at stage one. Wallet,
unlocks, completed-level history, skins, preferences, and earned extra-move/time
allowances are preserved. Daily boards remain tied to their separate date identity.

## Local validation — September 7, 2026

- 51 frozen level identities matched untouched generation output across four independent processes.
- 25 focused engine checks passed, including completion migration and optimality proof cases.
- 55 simulator native checks passed, covering saved grids, rewards, replay, navigation, and Time Rush. These overlap the engine checks.
- Three Levels UI flows passed: solved-only persistence, crown/best-move persistence and mode separation, and future-page/direct-number browsing with locked rows and return to play.
- Three existing perfect-solve UI flows passed, including nonoptimal completion and interrupted celebration.

The final browsing result is `artifacts/LevelCatalog-Browse-Final.xcresult`.
Native and completion-flow results are recorded in `artifacts/level-catalog-verified.log`;
the solved/crown persistence cases are in `artifacts/level-catalog-ui.log`. Early UI
assertions were corrected for native accessibility wrappers and localized number
formatting. A visual preview is saved at `artifacts/level-catalog-preview.png`.
Released in **TestFlight 1.0.0 (9)** on September 7 at 4:07 PM Pacific. Apple verified
the build as VALID and IN_BETA_TESTING in the existing Owner Testing group. The
production archive uses source `03b6a2845c4871eebb1f8afb25d2c2ac61618790`; its clean
checkout passed all 103 Release engine tests, and the release checkpoint passed 38
native checks plus all three Levels UI flows on a dedicated simulator. See
[release verification](VALIDATION.md#build-9-testflight-release).
