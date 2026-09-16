# Library adoption validation — September 16, 2026

Implemented Firebase Crashlytics 12.19.2 and test-only SnapshotTesting 1.19.5.
Swift Collections was assessed separately and not adopted; see the
[benchmark assessment](collections-assessment.md).

## Environment

- Xcode 27.0 (27A266a), Apple Silicon macOS 27.0.
- Dedicated iPhone 17 Pro simulators, iOS 26.1 (23B86).
- Local Debug and Release simulator builds passed. This is not a production
  archive, on-device performance check, or App Store release.
- Work coexisted with the separate build 14 release. Build 14 excludes these
  changes; a release containing diagnostics must use a later build number and
  complete the privacy-disclosure updates in [DIAGNOSTICS.md](../../DIAGNOSTICS.md).

## Automated and visual checks

| Check | Result | Local evidence |
| --- | --- | --- |
| Native regression selection, including diagnostics, analytics, persistence and commerce | 62 passed, 0 failed, 0 skipped | `/tmp/prism-libraries-diagnostics.xcresult` |
| Final diagnostics and analytics selection plus settings UI persistence/independence test | 22 passed, 0 failed, 0 skipped | `/tmp/prism-libraries-final.xcresult` |
| Image comparisons and reference-protection guardrail | 4 passed, 0 failed, 0 skipped; 26 baselines unchanged | `/tmp/PrismRollSnapshotFinalComparison.xcresult` |
| Release simulator build | Passed | `/tmp/prism-libraries-release-build.log` |
| Xcode-signed Debug simulator build | Passed | `/tmp/prism-libraries-signed-build.log` |
| Final isolated source export after Swift quality setup and platform guards | 49 selected iOS tests passed, 0 failed, 0 skipped, including snapshot comparisons | `/tmp/PrismRollLibraryQualityFinal.xcresult` |
| macOS engine package and affected input tests | Full package compiled; 24 SwipeSequenceTests passed with 0 failures | `/tmp/prism-quality-engine-swipe-tests.log` |
| Symbol-upload wrapper | Shell syntax passed; mocked uploader received space-safe arguments; mismatched project and automatic collection were rejected | Local temporary fixture |

The 22-test selection overlaps the 62-test selection; these are not 84 unique
tests. The snapshot run used comparison mode, not reference recording. All 26
images and the diagnostics settings screenshot were visually reviewed.
The Release app excluded SnapshotTesting, the reference images, and the deliberate
smoke-crash message. Its collection defaults and crash-data manifest were checked.
The temporary logs and result bundles are machine-local evidence, not repository
artifacts.

The snapshot helper/tests and diagnostic error tests are guarded for UIKit, so
the macOS engine package can continue sharing the test directory without linking
the app's iOS-only test dependencies. The engine package excludes the reference
PNG directory. SwiftLint and SwiftFormat pass on all 254 owned Swift files in
the isolated export; see [SWIFT_QUALITY.md](../../SWIFT_QUALITY.md).
The full macOS Debug test run was stopped during the existing expensive
procedural-generation test after compilation succeeded. The targeted input run
completed; a complete macOS engine-suite pass is not claimed for this checkpoint.

## Firebase receipt and symbols

A deliberate Debug-only crash on a dedicated simulator was relaunched with
diagnostics explicitly enabled and analytics explicitly disabled. The signed
build resolved Firebase Installations' keychain requirement. The official SDK
uploader confirmed receipt of the matching main executable and debug-dylib dSYMs.

The authenticated Firebase console displayed one crash event from iOS Simulator,
version 1.1.0 (14), received September 16 at 3:59:07 PM Pacific. Its symbolicated
stack includes `DiagnosticsService.runDebugSmokeCrashIfRequested()` at
`DiagnosticsService.swift:76`. This identifies the intentional local smoke test;
it is not a crash from the separate production build 14.

[Verified Crashlytics issue](https://console.firebase.google.com/u/0/project/prism-roll/crashlytics/app/ios:com.jonluca.prismroll/issues/541edb448a8354918de7578f02b05bfc)

A subsequent signed-run submission also completed locally for report
`156df93c5807424d9660fdff35258956`. Evidence is in
`/tmp/prism-crash-xcode-signed-oslog.log`; symbol-upload evidence is in
`/tmp/prism-crash-symbols-xcode-signed.log`. Analytics collection was disabled in
the smoke-run logs. No player installation was used.
