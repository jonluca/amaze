# Crash and error reporting

The app reports native crashes to the **prism-roll** project in the private [GlitchTip dashboard](https://errors.watchtrader.net/). The public DSN is bundled with the app; the upload token must never be bundled or committed.

The SDK retains crash stacks, release/build identity and app/device versions. Client filtering removes exception text, request details, breadcrumbs, extra fields and installation identifiers; collector filtering provides a second layer. Performance tracing, replay, logs, automatic sessions and network instrumentation are disabled. Events expire after 30 days. Ordinary Debug builds do not send reports.

Prism Roll requires a fresh, separate opt-in in Settings. The earlier Firebase consent does not authorize GlitchTip, and Firebase crash reports are not imported. Firebase usage analytics remains independent.

## Release symbols

After archiving, run `scripts/upload_glitchtip_symbols.sh /path/to/App.xcarchive`. The script verifies bundle/project identity and matching executable/dSYM UUIDs, downloads checksum-pinned Sentry CLI 3.8.2, and uploads privately. It reads `SENTRY_AUTH_TOKEN` or the macOS Keychain item **GlitchTip Native Apps Upload**, account **jonluca-apps**. Upload failure fails the script. The production archive workflow invokes this step and its repository secret is configured.

Before distribution, verify the exact archived DSN and symbols, update any hosted privacy disclosure, and verify receipt using an isolated verification project. New installed binaries are required; an existing installation does not acquire the SDK automatically.

## Consent and bounded errors

`DiagnosticsService` retains its operation/domain allowlist, numeric-code bounds, deduplication, and maximum eight distinct errors per session. The new `prismroll.diagnostics.glitchtip.enabled` choice is independent of the earlier Firebase preference. Off by default means the GlitchTip SDK does not start until authorized; ordinary Debug, XCTest, and UI test runs remain excluded. The SDK can retain a crash locally after a mid-session opt-out but its before-send callback drops new events while disabled. Reports already authorized cannot be recalled. Native saved reports may be sent on a later opted-in launch.

Firebase Analytics stays on its existing independent opt-in path. Firebase Crashlytics is no longer linked by the app. The legacy Info.plist disabled flag remains as a defensive setting. No previously saved Firebase crash report is imported.
