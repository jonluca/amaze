# Swift Collections assessment — 2026-09-16

**Decision: retain `Array` in `MazeMotionTimeline` for now.** The release-mode
benchmark does not establish a useful improvement for the small animation
queues expected during play. `Deque` substantially improves deliberately large
backlogs, but that alone does not justify a new production dependency.

The earlier recommendation made this dependency conditional on profiling.
This assessment completes that investigation; Swift Collections is downloaded
only into a temporary benchmark package, and the app's dependencies and motion
timeline remain unchanged.

## Measurement

The harness copies this checkout's real `MazeSceneMove`, `GridCell`,
`MoveDirection`, `MazeMotionUpdate`, and `MazeMotionTimeline`. It generates two
timeline variants whose only behavioral implementation difference is
`[MazeSceneMove]` versus `Deque<MazeSceneMove>` storage. Source SHA-256 values and
the exact package revision are retained in the [raw results](collections-benchmark-2026-09-16.json).

- Apple M4 Max, macOS 27.0 (26A428), Apple Swift 6.4.
- SwiftPM release build (`-O`), native arm64 macOS executable.
- [Apple Swift Collections 1.6.0](https://github.com/apple/swift-collections/releases/tag/1.6.0),
  revision `a0cb0954ecb21e4e31b0070e6ed5674e8556685a`, `DequeModule` product.
- Nine samples per case, alternating Array/Deque order after warm-up.
- Repeated square-route fixtures with four-cell slides and cumulative painted
  cell sets. Fixture construction is outside the measured region. Each full
  timeline iteration resets and replays one route with the actual enqueue and
  advance methods; queue capacity is retained between iterations.
- 120 Hz simulated display intervals. These are CPU-time measurements, not
  elapsed animation durations; no sleeping or real rendering is involved.
- Checksums consume the output to prevent the benchmark from becoming dead work.

Median microseconds per complete enqueue-and-drain burst:

| Moves in burst | Queue only: Array | Queue only: Deque | Full timeline: Array | Full timeline: Deque |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.031 | 0.014 | 1.491 | 1.545 |
| 4 | 0.118 | 0.068 | 3.097 | 3.023 |
| 8 | 0.336 | 0.159 | 5.740 | 5.932 |
| 16 | 0.563 | 0.278 | 7.909 | 7.708 |
| 128 (stress) | 9.001 | 1.950 | 58.663 | 52.764 |
| 1,024 (stress) | 565.720 | 17.196 | 755.948 | 424.641 |

A sustained route of 64 swipes arriving every 25 ms, advanced at 120 Hz, took
47.460 µs with Array and 50.974 µs with Deque for the entire simulated route.

For 1–16-move bursts, the full timeline's median difference is under 0.21 µs,
with mixed direction and overlapping sample ranges. The 128- and 1,024-move
stress bursts benefit by about 10% and 44%, respectively. Those large backlogs
are useful asymptotic checks, not evidence of normal gameplay queue sizes.
The existing timeline accelerates older turns so that the newest queued move
starts within roughly one 120 Hz interval; a steady input stream therefore does
not require such backlogs.

## Correctness and limits

All **63 frame-by-frame parity cases passed**: burst sizes 1/4/8/16/128/1,024,
slide lengths 1/4/10, and frame rates 30/60/120 Hz; plus 64-move sustained streams
at 25/50/90 ms arrival spacing and the same three frame rates. Every frame checks
position, painted set, ordered paint events, rotation segments, completion,
wall impact, and pending move count for exact equality.

This is a controlled comparison of the current CPU-side timeline, not a device
FPS, GPU, energy, or allocation profile. Other applications and a concurrent
build were active on the host, so sample variation is substantial; the raw JSON
includes every sample. The small-case percentages should not be interpreted as
proven speedups or regressions. Small burst sizes are an explicit workload
assumption, not production telemetry. No allocation-count or on-device
performance claim is made.

Revisit Deque if a device trace identifies motion queue removal as a meaningful
cost, or if a new feature intentionally queues hundreds of moves. At present,
the benchmark supports keeping the simpler existing dependency set.

## Reproduce

From the repository root:

```sh
python3 ios/Validation/LibraryAdoption/CollectionsBenchmark/run.py \
  --output /tmp/prism-collections-benchmark.json
```

The runner creates and removes a temporary standalone Swift package. It never
rewrites the app's package resolution or Xcode project, and it refuses to run if
the expected Array declaration has changed, so a future implementation change
cannot silently invalidate the comparison.
