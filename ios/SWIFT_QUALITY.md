# Swift code quality

Run from any working directory by passing the path to this script:

```sh
# Check without rewriting source (the default command).
python3 ios/scripts/swift_quality.py check

# Apply the agreed whitespace formatting, then run correctness checks.
python3 ios/scripts/swift_quality.py format

# Optional: install the pinned tools without checking source.
python3 ios/scripts/swift_quality.py bootstrap
```

Commands above assume the repository root. The runner finds the root from its
own location, so `python3 scripts/swift_quality.py check` also works inside `ios`.
macOS, Python 3, curl, and an Xcode installation are required. The first invocation
downloads **SwiftLint 0.65.1** and **SwiftFormat 0.62.1** from their official GitHub
releases and verifies the archives against committed SHA-256 values. Later runs
reuse the executables under the ignored `.cache/swift-quality` directory and
check their exact versions. Homebrew and global tools are left unchanged.

## Scope and policy

- App source, unit tests, UI tests, and Swift files under `ios/scripts` are checked.
- Generated level/optimal-count catalogs, snapshot PNGs, benchmark evidence,
  build/release artifacts, vendored solver packages, and duplicate engine-package
  source symlinks are excluded. Canonical engine source in `PrismRoll` is checked.
- `.swiftlint.yml` selects 23 correctness rules, including duplicate conditions,
  discarded observers, unhandled throwing tasks, and delegate ownership. Warnings
  fail the check. There is no grandfathered violation baseline.
- `.swiftformat` selects whitespace rules only. It preserves indentation,
  wrapping, inline statements, declarations, explicit `self`, and types. This
  avoids a broad reformat or language migration. Swift 5 language mode matches
  the Xcode project; Swift 6.0 is the minimum compiler version for these sources.
- `check` runs both tools, reports both sets of findings, and returns nonzero if
  either fails. `format` rewrites formatting only; fix remaining lint findings
  manually. Neither tool is linked into the app or run on every Xcode build.

The [Swift Quality workflow](../.github/workflows/swift-quality.yml) runs the same
check on iOS-related pushes and pull requests, and can be dispatched manually.
It uses `macos-26` and Xcode 26.6 to match the production compiler environment.
It does not archive, sign, upload symbols, or release the app.

## Updating versions or rules

Version pins, official release URLs, and checksums live in
`scripts/swift-tools.json`. Update them together using the official release asset
digests, then run `check` and inspect the effect of new rules before enabling
them. Clear only `.cache/swift-quality` to force a fresh installation. Do not
enable all new rules implicitly or regenerate a baseline to hide findings.

References: [SwiftLint](https://github.com/realm/SwiftLint),
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat).

## Initial verification

On September 16, 2026, a clean source export installed both pinned releases and
passed all checks across 254 Swift files with no violation baseline. The initial
formatting fix changed only two range-spacing expressions in `SwipeSequenceTests`.
Temporary fixtures confirmed that trailing whitespace and duplicate imports
fail the check, generated catalogs remain excluded, and `check` leaves source
bytes unchanged. Invocations from both the repository root and `ios` passed.
