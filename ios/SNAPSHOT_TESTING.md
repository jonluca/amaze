# Image regression tests

`SnapshotTesting` is linked only to `PrismRollTests`. Approved PNG references live
in `PrismRollTests/__Snapshots__`; Xcode excludes that directory from bundle
resources. The app does not ship the library or the references.

The reference environment is **iPhone 17 Pro (`iPhone18,1`), iOS 26.1 (23B86)**, recorded
with **Xcode 27.0 (27A266a)**. Use the same simulator runtime and Xcode version
when comparing or recording references.
Image tests explicitly skip other device models, iOS versions, or runtime builds, rather than
silently approving a different rendering environment. This does not skip the
image-comparison guardrail test or other rendering/model assertions.

The comparisons cover:

- Every ball's trail after ten deterministic 1/120-second updates.
- Six recorded gameplay states: moving trail, wall squash, recovered ball,
  completion coin fan, completion coin spin, and Reduce Motion completion.
- Tutorial tips at standard and accessibility text sizes, rendered in English,
  dark mode, at a fixed 360-point width and 1x image scale.

Existing scene tests still validate semantic state and attach review montages.
Their new comparisons inspect each rendered `UIImage` separately, without
introducing another view lifecycle or animation clock. These image checks do not
replace touch, device performance, or accessibility interaction tests.

## Compare

Run these selected tests on a dedicated matching simulator:

```sh
xcodebuild test \
  -project ios/PrismRoll.xcodeproj -scheme PrismRoll \
  -destination 'platform=iOS Simulator,id=YOUR_DEDICATED_SIMULATOR_UDID' \
  -only-testing:PrismRollTests/BallTrailTests/testRenderEveryBallTrailForVisualReview \
  -only-testing:PrismRollTests/MazeMotionPolishVisualTests \
  -only-testing:PrismRollTests/SnapshotRegressionTests \
  -parallel-testing-enabled NO
```

Normal runs explicitly select `.never` recording. Changed **and missing**
references fail; neither can overwrite or create an approved reference. Failure
attachments include the reference, new image, and difference.

The strategy uses `precision: 0.999` with direct image comparison, permitting
at most 0.1% different color-channel bytes for small antialiasing/rounding changes.
It intentionally avoids Core Image perceptual comparison: on the transparent
SceneKit snapshots that path reported broad differences when the exported PNGs
actually differed in only 1–5 pixels. `testVisibleImageRegressionFailsWithoutReplacingReference`
checks that the same strategy passes an unchanged image, rejects an 8x8 white
patch in a 64x64 black image, preserves the reference bytes, and rejects a missing
reference without creating it.

## Intentionally update references

Set `PRISM_RECORD_SNAPSHOTS=1` in the local Xcode scheme's **Test > Arguments >
Environment Variables**, then run only the selected image tests above on the
matching simulator. For command-line `test-without-building`, set that key in the
test target's `EnvironmentVariables` in a temporary copy of the generated
`.xctestrun` file. Do not commit the recording setting or use it in CI.

Recording deliberately reports failures after writing the images. Inspect every
changed PNG, remove the environment variable, then rerun all selected tests.
Only the subsequent comparison run establishes a passing result. Commit the
reviewed PNGs alongside an intentional visual change. Do not accept refreshed
references simply to make an unexplained failure disappear.

## Initial verification

On September 16, 2026, all 26 reference images were recorded and visually
reviewed in the environment above. A separate comparison run with recording
disabled passed all four selected tests, with zero failures and zero skips.
That run included the visible-change/missing-reference guardrail. SHA-256 checks
confirmed all 26 approved reference files remained byte-for-byte unchanged.
