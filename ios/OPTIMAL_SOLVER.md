# Exact native move optimization

`MazeOptimality` now calls the native HiGHS integer optimizer through
`MazeNativeOptimizer` and the source-built `CPrismOptimizer` package. Every
supported board uses the same exact model, regardless of its level number or
difficulty. There is no time, search-node, or difficulty cutoff and no
approximate target. Work continues until the optimum is proved, the caller
cancels, or a failure is reported.

## Bundled Classic perfect counts

The first **1,000 Classic levels** bundle their already-proved starting move
counts in `MazePerfectMoveCatalog+Generated.swift`. `MazePerfectMoveCatalog`
checks the mode, level number, dimensions, starting position and exact 256-cell
occupancy mask before returning a count. These in-memory lookups perform no
level generation, file access or native optimization, so a canonical level's
perfect target is available immediately.

These 1,000 Classic boards also have unique wall layouts. An offline seed catalog
selects each board in level order and rejects repeated layouts. It applies the
existing difficulty and playability gates without retaining historical boards.
The native proof generator reuses only exact geometry matches. See [current catalog and proof identity](LEVEL_CATALOG.md).

Across all 1,000 Classic levels in the Release lookup benchmark, the median was
**1.292 µs**, p95 **1.708 µs**, and maximum **0.032667 ms**, excluding generation.
These are measured development-Mac lookup times, not device latency guarantees.

The offline counts do not stand in for move directions. An optimal hint still
comes from a native route proof for the actual current position and painted
cells. Other modes, levels beyond 1000, and any board whose geometry or start
differs from the recorded Classic catalog continue through the exact solver.
Changes to route hints, move allowances, timers or coin placement do not alter
the grid's minimum.

The native proof records and independent route-validation evidence are retained
under `ios/Validation/PerfectCounts/`. Tests check all 1,000 canonical lookups,
independent reference counts and current native proofs, fresh native proofs spread
through the later catalog, and rejection of mismatched boards. Separate cache
tests verify that perfect-count lookup starts no native work while requesting
move directions still requires a proved route.

## Model and correctness

Build a directed graph containing the current position and every reachable
wall-stop position. Each effective swipe is one edge, costs one move, and
paints its traversed cells. Direction matters: reversing a swipe need not
return to the previous stop. Blocked swipes are not edges.

The solver accepts the actual position and complete painted-cell set, so the
same exact model applies after a detour or when resuming a saved run. Coverage
constraints include only cells that still need paint. Previously painted cells
may be unreachable from the current position without making the remaining
problem infeasible. A complete paint set has a zero-move optimum. Invalid
positions and paint outside the board are rejected before native search.

For every edge `e`, the integer variable `x[e] >= 0` counts its traversals.
Minimize `sum(x[e])`, subject to:

1. **Coverage:** for every initially unpainted cell, the sum of traversals of
   edges painting it is at least one. If the edges painting cell A are a subset
   of those painting B, A's constraint already ensures B; redundant constraints
   are removed.
2. **One open or closed walk:** outgoing minus incoming traversal counts is
   between zero and one at the start, and between minus one and zero elsewhere.
   Integrality and total balance allow one endpoint, or a return to the start.
3. **Connectivity:** continuous flow travels only along selected edges, with
   `0 <= f[e] <= U*x[e]`. Every non-start node consumes one unit for each
   selected departure: `incoming(f) - outgoing(f) = outgoing(x)`. This forces
   all selected departures to be reachable from the start and rules out
   disconnected cycles masquerading as a solution.

Every legal covering route within the valid upper bound satisfies these
constraints. Conversely, their
integer traversal counts form a connected Euler trail from the start;
Hierholzer's algorithm reconstructs its swipe order. Coverage then makes that
trail a complete solution. Thus the model's minimum equals the game's minimum.
It optimizes corridor traversal counts instead of enumerating painted subsets.

`U` is a valid route-length upper bound, not a computational budget. A supplied
hint contributes only after replay proves it finishes the current state. Native
greedy routes with four directional tie orders can also tighten the bound after
replay. Otherwise use `N*R`, where N is the number of reachable stops and R the
number of unpainted cells: there are at most R first-paint events, and a segment between them can
have its repeated-position loops removed. This bounds some shortest covering
walk even when the graph is not strongly connected. The game's maximum 16×16
board therefore needs at most 65,280 route slots. Invalid hints never change
the answer or cause an otherwise solvable board to be rejected.

## Exact search and response time

When the reduced coverage requirements and reachable stop positions fit in at
most 2²⁰ theoretical states, native breadth-first search finds the minimum
directly. Its mask tracks the inclusion-minimal coverage requirements rather
than every painted tile, and each edge still costs one swipe. This is an exact
fast path, particularly useful after much of the board is painted. Larger
states use the uncapped integer model above. Sparse constraint assembly and
validated feasible route bounds reduce its setup and proof work; heuristic
routes never become answers without an optimality proof.

## Accepting a proof

HiGHS runs serially with unlimited time and node settings, zero relative and
absolute MIP gaps, and feasibility tolerances of `1e-8`. A result is accepted
only when the solver reports optimality, the traversal counts are integral,
and the reconstructed integer route length agrees with both its objective and
the conservatively rounded global lower bound. C++ replays the route against
the graph; Swift independently replays every direction through the game's
cell-by-cell slide rules and checks completion at the reported move count.
An incumbent alone cannot supply a perfect target or crown.

The actor cache holds proved routes for 32 recent grids. A state lookup includes
the current position and exact paint set; revisiting a stop with different paint
cannot reuse the wrong answer. When a route is proved, its state suffixes are
cached immediately, up to 256 moves ahead for unusually long routes. Every
suffix is also optimal: a shorter
completion from any intermediate state would shorten the original proved
route. Following optimal guidance therefore reuses proof without another
optimization. A deviation triggers an exact solve from the new state.

Each grid retains at most 512 indexed states and 65,536 directions of shared
route buffers. Suffixes share a proved route's storage; whole older proofs are
evicted when their retained buffers exceed the budget. At most two native jobs
run concurrently. Identical requests share one solve, cancelling one requester
preserves the other waiters, and a cancelled native job occupies its slot until
it actually exits. Live hint requests go before queued background perfect-target
work, including promotion of an existing queued request for the same state.

The initial level minimum stays separate from its remaining-move minimum, so
progress through the board cannot lower its perfect target or award a false
crown. Cancelled and failed requests are not cached. Native interrupt callbacks
run on the solving thread, preserving the request's cancellation context; C++
exceptions never cross the C interface.

Gameplay and completion progression do not wait for proof. The header shows
**Calculating perfect…**, then **Perfect: N moves**, or a retry action on
failure. Completion can use a proof already available for its immediate crown
presentation. If proof is pending, the level still advances and store-owned
verification records any earned crown later against the captured completed
run, even after the player leaves that level.
Pending completed runs are saved and their proofs resume after relaunch. The
store cancels its native tasks on teardown; obsolete Daily/Duel proofs cancel
when those sessions are left because they do not earn catalog crowns.

## Native source provenance

The package vendors HiGHS 1.15.1 at commit
`04024d701f79feb8e2f18bc3df0dffc04ef05088`, plus narrowly scoped, merged upstream
correctness fixes [3177](https://github.com/ERGO-Code/HiGHS/pull/3177),
[3179](https://github.com/ERGO-Code/HiGHS/pull/3179), and
[3181](https://github.com/ERGO-Code/HiGHS/pull/3181). These address invalid cuts
and a failed solution-repair path that could otherwise yield a false optimum.
The official false-optimum regression models pass with presolve on and off.

[Package documentation](Packages/PrismOptimizer/README.md) records the static
Apple build configuration and licenses;
[patch provenance](Packages/PrismOptimizer/Patches/README.md) records exact
merge commits and checksums. The vendoring script verifies the pinned source
archive, every patch and all 789 source/header files. No optimization code is
downloaded during an app build or at runtime. The MIT core and required
declaration/header notices are included in the app's third-party notices;
optional HiPO providers and GPU support are disabled.

## Validation and reproduction

The final Release benchmark proved **111/111** canonical levels, matching the
independent SciPy flow reference: levels 1–100, 150, 200, 250, 500, 1000, 1001,
10000, 100000, 1000000, 1000000000 and `Int.max`. Representative minima are
Level 16: **38**, Level 50: **58**, Level 100: **90**, and Level 1000: **88**.

An independent literal-grid breadth-first oracle also checked all **2,304**
nonempty 3×3 board/start combinations: **934 solvable** and **1,370 infeasible**,
with complete agreement. Tests cover invalid hints, cancellation, route-buffer
bounds, cache identity, failed-request retries and Swift gameplay replay.
All native callbacks stayed on the caller thread; a 100 ms cancellation
request returned at approximately 108 ms in the native harness.

For arbitrary current states, the native C API matched a literal-grid oracle
on all **59,049** 3×3 geometry/position/paint-set combinations: **41,959 feasible**
and **17,090 infeasible**. A separate build with the small-state BFS path
disabled exercised the integer model on **3,473** evenly sampled states,
including **2,463 feasible** and **1,010 infeasible** cases. Every returned route
was replayed; invalid paint, missing current-position paint, cancellation, null
paint buffers and insufficient output capacity were checked separately.

The current Release state benchmark checked **321 cached suffix lookups**, all
matching their proved remaining-move counts. Cold current-state solves at the
halfway point also matched those suffix minima:

| Level | Cold initial proof | Cold halfway proof | Cached suffix median / max |
| --- | ---: | ---: | ---: |
| 1 | 0.20 ms | 0.01 ms | 0.58 / 0.83 µs |
| 16 | 252.41 ms | 21.17 ms | 1.79 / 2.29 µs |
| 100 | 419.26 ms | 55.81 ms | 3.46 / 5.79 µs |
| 1000 | 485.51 ms | 347.79 ms | 3.33 / 6.21 µs |
| `Int.max` | 1405.04 ms | 227.23 ms | 3.13 / 6.04 µs |

These cold timings measure native **route proofs**. Bundled perfect-count
lookup for the first 1,000 canonical Classic levels does not run that search.

Cold detour proofs took **36.79 ms** on Level 100 and **237.93 ms** on Level 1000;
each returned route was replayed to completion. The final focused Swift suites
passed **24/24** catalog and cache tests, including all 1,000 bundled grid
identities, fresh native catalog samples, actual simultaneous HiGHS routes for
levels 16 and 100, and worker, cancellation, coalescing and priority tests.

For reference, the earlier 111-level initial-state benchmark under concurrent
build load had a median of **547 ms**, p95 **1.83 s**, maximum **3.74 s**, and peak
process RSS **70.2 MiB**. That earlier baseline is separate from the current
state measurements above. These are development-Mac measurements, not
physical-iPhone latency guarantees.
Integer optimization can still have expensive cases; removing artificial
cutoffs does not make every proof instantaneous. UI and progression remain
independent of that work.

From the repository root:

```sh
swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark /tmp/minima.json
swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark --current-state-only /tmp/current-states.json
swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark --catalog-only /tmp/bundled-counts.json
python3 ios/Packages/PrismOptimizer/scripts/vendor_highs.py --check
ios/Packages/PrismOptimizer/scripts/check_upstream_regressions.sh
ios/Packages/PrismOptimizer/scripts/check_current_state_oracle.sh
ios/Packages/PrismOptimizer/scripts/check_current_state_oracle.sh --force-mip
ios/Packages/PrismOptimizer/scripts/check_apple_builds.sh
```

The benchmark fails on any missing proof or incorrect reference count and
excludes generation from solve timing. Its current-state section samples levels
1, 16, 100, 1000 and `Int.max`, checking cold halfway solves against independently
proved route suffix lengths and replaying detour routes. It reports initial and
current-state cold solve times separately from median and maximum warm suffix
cache lookup times. `--current-state-only` runs this bounded sample without the
full initial-level sweep. The exhaustive current-state test additionally
compares all 1,458 valid geometry/position/paint-set combinations of 2x3 boards
against a separate literal-grid breadth-first search.

`--catalog-only` checks all 1,000 current Classic grids and measures only the
bundled count lookup, excluding generation and any native route optimization.

Local validation evidence is retained
under `ios/artifacts/NativeOptimizer/`, with current-state logs and JSON under
`CurrentState/`. Earlier native-package validation covered macOS arm64 Release,
generic iOS arm64 Release and iOS Simulator arm64 Release; those build records
predate the current-state changes. The current-state proof tests and timings
reported here use macOS arm64 Release.
