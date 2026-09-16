# Crash reporting

Prism Roll links Firebase Crashlytics from the existing pinned Firebase 12.19.2 package. App startup disables Google Mobile Ads' competing SDK crash handlers before configuring Crashlytics, as recommended by Firebase's troubleshooting guide. Settings → **Share saved and future crash reports** is a separate, optional choice, off by default. Analytics consent does not authorize crash-report uploads.

`FirebaseCrashlyticsCollectionEnabled=false` remains in the app's Info.plist, and the transport never enables automatic uploads. A saved diagnostics opt-in or enabling the setting explicitly authorizes one `sendUnsentReports()` action per process. Firebase can cache crashes locally after it starts for analytics, even while crash sharing is off. The setting and privacy policy explicitly include those previously saved reports. Current-session reports are normally sent on the next opted-in launch.

Disabling sharing stops new app-authored error recording and future upload authorizations. It cannot recall an upload already authorized during this launch. The SDK resolves send/delete through a single action per launch, so the app intentionally makes no claim that a later delete would retract an earlier send.

## Error scope

The app records progress load/save, product loading, and coin-delivery failures. `DiagnosticFailure` strips the original error's message, userInfo, file paths and arbitrary domains. Only fixed operation/domain categories and bounded numeric codes cross the SDK boundary. Repeated failures are deduplicated, with at most eight distinct nonfatal reports per session. No transaction IDs, receipts, player IDs, maze data, or emails are added. Firebase itself includes crash stacks, app/device information, and an installation identifier. When usage analytics is separately enabled, Firebase can attach analytics breadcrumbs.

Ordinary Debug runs, XCTest, and `--uitesting` do not start diagnostics. A manual Debug smoke run additionally requires `--diagnostics-debug` and explicit diagnostics consent. The deliberate crash flag `--diagnostics-smoke-crash` waits for the reporter to initialize, then crashes only in Debug. Release has no crash trigger. Never run the smoke flag on a player's installation.

## Symbols and verification

The app generates dSYMs in Debug and Release. The production archive workflow calls `scripts/upload_crashlytics_symbols.sh` after archive validation. It reads Firebase configuration from that exact archive, verifies the project/bundle and default-off collection setting, and uploads the matching app dSYM using the SDK's official uploader. Ordinary local builds and tests perform no symbol upload.

For a manual archive:

```sh
bash ios/scripts/upload_crashlytics_symbols.sh /path/to/PrismRoll.xcarchive /path/to/SourcePackages
```

For a deliberate simulator smoke check, use a dedicated simulator and an Xcode-signed Debug build (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`). An unsigned simulator build can record a crash but fail to upload because Firebase Installations cannot access the keychain. Enable diagnostics, launch without a debugger using `--diagnostics-debug --diagnostics-smoke-crash`, then relaunch with `--diagnostics-debug` and consent still enabled. Upload that build's dSYMs and verify the issue in the Firebase console. A passing unit test proves consent logic, not server receipt.

On September 16, 2026, the manual simulator check reached Firebase and showed a symbolicated stack frame at `DiagnosticsService.swift:76`, `runDebugSmokeCrashIfRequested()`. Analytics remained disabled. See the [validation record](Validation/LibraryAdoption/validation.md) for the console issue and local test evidence.

The in-app privacy policy and app privacy manifest include this behavior. Before a future release containing diagnostics, update the hosted privacy policy and App Store disclosures for Crash Data and installation identifiers used for app functionality. Build 14 is being released separately without this change; use a new build number for a future diagnostics release.

References: [Crashlytics setup](https://firebase.google.com/docs/crashlytics/ios/get-started), [collection controls](https://firebase.google.com/docs/crashlytics/ios/customize-crash-reports), [symbol uploads](https://firebase.google.com/docs/crashlytics/ios/get-deobfuscated-reports).
