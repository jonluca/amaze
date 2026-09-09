# Exact native move optimization

`MazeOptimality` now calls the native HiGHS integer optimizer through
`MazeNativeOptimizer` and the source-built `CPrismOptimizer` package. Every
supported board uses the same exact model, regardless of its level number or
difficulty. There is no time, search-node, or difficulty cutoff and no
approximate target. Work continues until the optimum is proved, the caller
cancels, or a failure is reported.

## Model and correctness

Build a directed graph containing the starting position and every reachable
wall-stop position. Each effective swipe is one edge, costs one move, and
paints its traversed cells. Direction matters: reversing a swipe need not
return to the previous stop. Blocked swipes are not edges.

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
hint contributes only after replay proves it covers the board. Otherwise use
`N*(T-1)`, where N is the number of reachable stops and T the number of open
cells: there are at most T−1 first-paint events, and a segment between them can
have its repeated-position loops removed. This bounds some shortest covering
walk even when the graph is not strongly connected. The game's maximum 16×16
board therefore needs at most 65,280 route slots. Invalid hints never change
the answer or cause an otherwise solvable board to be rejected.

## Accepting a proof

HiGHS runs serially with unlimited time and node settings, zero relative and
absolute MIP gaps, and feasibility tolerances of `1e-8`. A result is accepted
only when the solver reports optimality, the traversal counts are integral,
and the reconstructed integer route length agrees with both its objective and
the conservatively rounded global lower bound. C++ replays the route against
the graph; Swift independently replays every direction through the actual
`MazeRun` rules and checks that completion occurs at the reported move count.
An incumbent alone cannot supply a perfect target or crown.

The actor cache holds only proved minima for 32 recent grids, keyed by width,
height, open cells and starting position. Cancelled and failed requests are not
cached. Native interrupt callbacks run on the solving thread, preserving the
request's cancellation context; C++ exceptions never cross the C interface.

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

In the 111-level benchmark under concurrent build load, median solve time was
**547 ms**, p95 **1.83 s**, maximum **3.74 s**, and peak process RSS **70.2 MiB**.
These are development-Mac measurements, not physical-iPhone latency guarantees.
Integer optimization can still have expensive cases; removing artificial
cutoffs does not make every proof instantaneous. UI and progression remain
independent of that work.

From the repository root:

```sh
swift run --package-path ios/EnginePackage -c release MazeOptimalityBenchmark /tmp/minima.json
python3 ios/Packages/PrismOptimizer/scripts/vendor_highs.py --check
ios/Packages/PrismOptimizer/scripts/check_upstream_regressions.sh
ios/Packages/PrismOptimizer/scripts/check_apple_builds.sh
```

The benchmark fails on any missing proof or incorrect reference count and
excludes generation from solve timing. Local validation evidence is retained
under `ios/artifacts/NativeOptimizer/`. Patched macOS arm64 Release, generic
iOS arm64 Release, and iOS Simulator arm64 Release builds all pass.
