# Crash and error reporting

The app reports native crashes to the **prism-roll** project in the private [GlitchTip dashboard](https://errors.watchtrader.net/). The public DSN is bundled with the app; the upload token must never be bundled or committed.

The SDK retains crash stacks, release/build identity and app/device versions. Client filtering removes exception text, request details, breadcrumbs, extra fields and installation identifiers; collector filtering provides a second layer. Performance tracing, replay, logs, automatic sessions and network instrumentation are disabled. Events expire after 30 days. Ordinary Debug builds do not send reports.

Prism Roll requires a fresh, separate opt-in in Settings. The earlier Firebase consent does not authorize GlitchTip, and Firebase crash reports are not imported. Firebase usage analytics remains independent.

## Release symbols

After archiving, run `scripts/upload_glitchtip_symbols.sh /path/to/App.xcarchive`. The script verifies bundle/project identity and matching executable/dSYM UUIDs, downloads checksum-pinned Sentry CLI 3.8.2, and uploads privately. It reads `SENTRY_AUTH_TOKEN` or the macOS Keychain item **GlitchTip Native Apps Upload**, account **jonluca-apps**. Upload failure fails the script. The production archive workflow invokes this step and its repository secret is configured.

Before distribution, verify the exact archived DSN and symbols, update any hosted privacy disclosure, and verify receipt using an isolated verification project. New installed binaries are required; an existing installation does not acquire the SDK automatically.
