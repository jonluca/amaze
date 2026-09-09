# Classic perfect move count

Classic/infinite levels show a gold crown and **Perfect: N moves** beneath the
current move count, including coin boards. N is the fewest swipes from the
level's starting position, so it stays fixed while the player moves. Level 16
shows **38**; Level 50 shows **58**. Other modes retain their existing summaries.

The row shows **Calculating perfect…** while native integer optimization proves
the answer. There is no time, search-node, or difficulty cutoff and no
best-known approximation. If work fails, **Retry perfect count** starts a new
attempt. The row stays present throughout, and gameplay remains available.

The solver searches the immutable grid used by gameplay, reconstructs an
optimal route, and independently replays it through `MazeRun`. A generated
hint is only a verified upper bound, never a perfect count: Level 16's stored
hint takes 46 moves, while its exact minimum is 38. Existing saved optimal
completions can supply their already-proved minimum immediately.

An actor performs optimization away from the main actor and caches only proved
minima for 32 recent grids. Identity includes dimensions, open cells and start.
Leaving a level cancels its view's request; cancelled or failed work is not
cached, so revisiting or retrying can calculate it again.

Completion progression never waits for an unfinished proof. A ready result can
show the immediate perfect-solve celebration; otherwise the player advances
while store-owned verification continues. The captured completed run receives
its earned crown when verification finishes, even if another level is open.
Pending completed runs survive app restart and resume verification on launch.
Meeting the displayed minimum and earning the saved crown use the same proof.

[The algorithm and native package notes](OPTIMAL_SOLVER.md) explain the integer
flow model, source pin, three merged upstream correctness backports and
reproduction commands. Final mathematical validation matches all 111 sampled
canonical levels and all 2,304 independent 3×3 board/start oracle cases. Local
native, UI and benchmark evidence is retained under `artifacts/NativeOptimizer/`.
