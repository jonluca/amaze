# PrismOptimizer native package

Static SwiftPM library for iOS 17+ and macOS 13+. `CPrismOptimizer` exposes the
maze-specific C interface and depends on the private `CHighs` C/C++ target.
Swift callers do not need C++ interoperability enabled. Both simulator and
device builds compile the reviewed source, without fetching or loading code at
runtime and without an opaque prebuilt binary dependency.

## Upstream pin and licenses

- HiGHS **1.15.1**, official stable release published July 2, 2026.
- Repository: <https://github.com/ERGO-Code/HiGHS>
- Commit: `04024d701f79feb8e2f18bc3df0dffc04ef05088`
- Source archive SHA256:
  `2e121a70ae00f56db8e5ed993e4046c247248fa6280d839ff4808fa958971f0d`
- Three narrowly scoped, merged upstream correctness backports: PRs 3177,
  3179 and 3181. Exact patches, hashes and merge commits are recorded in
  [Patches/README.md](Patches/README.md). This is an explicitly patched 1.15.1
  baseline; it does not silently track upstream development.
- `Licenses/HiGHS-MIT.txt` applies to the solver core. The required `pdqsort`
  header retains its Zlib license in `Licenses/pdqsort-Zlib.txt`. This matches
  the upstream release's **MIT** flavor. Optional provider implementations
  are not included. Their interface declaration headers are required by
  upstream's disabled extras dispatch table; the AMD BSD-3-Clause, METIS
  Apache-2.0, and RCM MIT notices are also retained in `Licenses`.

`scripts/vendor_highs.py` downloads only this commit archive and checks its
SHA256 before extraction. It checks and applies the three recorded upstream
patches, then reproduces the native source groups from upstream
`cmake/sources.cmake`, the two static extras-dispatch sources, and their headers.
Solver files are copied unchanged after those declared fixes. Headers appear both beside their
source files (preserving local quoted includes) and in the public include tree
(for the bridge). `VendorManifest.json` records every copied/generated file's
SHA256. To audit the checked-in subset:

```sh
python3 scripts/vendor_highs.py --check
```

An optional `--archive /path/to/source.tar.gz` makes the audit entirely offline.
Running without `--check` replaces only `Sources/CHighs`, the manifest, and the
  upstream license files. It never modifies the maze bridge.

## Configuration

- C++17, static linking, normal 32-bit `HighsInt`.
- `HIGHS_NO_DEFAULT_THREADS` defaults the scheduler to one thread. The bridge
  additionally sets `threads = 1` and `parallel = off` for deterministic,
  serial solve/callback ownership.
- No optional HiPO external providers (BLAS, AMD, METIS, RCM), GPU/CUDA, Zlib
  compressed-file support, external processes, Python, Fortran or dynamically
  loaded extras. The internal MIT wrappers remain in the source list, matching
  upstream's static MIT build configuration.
- No `fast-math` or altered floating-point semantics.
- Upstream C++ headers are reachable from the bridge with `#include "Highs.h"`;
  the Clang module map exports only the upstream C API to Swift.

The optimization proof relies on the maze bridge's model, solver status/bound
checks and independent integer route replay, rather than treating a feasible
incumbent as an optimum. Cancellation belongs to that interface.

## Current-state optimization

`PrismOptimizerSolveState` accepts the current position and a row-major painted
cell array, so its result is the minimum **additional** slides from any valid
state. Painted cells must be open and include the current position. Already
painted cells can be disconnected from that position; only the remaining cells
need to be reachable. `PrismOptimizerSolve` remains the compatible entry point
for an untouched level. Supplied hints are replayed from the supplied state.

The native bridge removes redundant coverage requirements and uses an exact
breadth-first search when the requirement masks and reachable stop positions
have at most 1,048,576 possible states. This makes small boards and endgames
avoid integer-programming setup. Larger problems use the uncapped HiGHS model.
Four greedy route candidates tighten its bounds and seed its search, but they
are never reported as optimal without a proof. Both algorithms independently
replay the final route with the initial painted cells before returning Optimal.
Matrix rows are assembled sparsely, and all paths poll cancellation.

## Build checks

```sh
swift build -c release --target CPrismOptimizer
./scripts/check_apple_builds.sh
./scripts/check_upstream_regressions.sh
```

The second command compiles the package for generic arm64 iOS 17 and iOS 17
Simulator destinations, using the selected Xcode and isolated DerivedData.
The third checks both upstream false-optimum reproductions with presolve on
and off. Full app linking and gameplay tests are run by the host project.

The Apple builds use a 17.0 deployment target. Upstream source warnings about
integer narrowing remain unchanged; the bridge validates the game's small
dimensions before passing them to HiGHS.

Validation of the patched source on September 9, 2026, using Xcode 27.0
(27A5209h): macOS arm64 Release static library build passed; generic iOS arm64
and iOS Simulator arm64 Release compilation passed; all four upstream
false-optimum regression checks passed. The archive contains no unresolved
AMD, METIS, BLAS or RCM provider symbols. These package checks are separate
from the host application's gameplay and exhaustive small-maze oracle tests.
