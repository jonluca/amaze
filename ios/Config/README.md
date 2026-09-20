# Private AppsFlyer build configuration

The app's Debug and Release configurations use `PrismRoll.xcconfig`. Its empty
default keeps clean checkouts and CI builds keyless. It optionally includes
`Local.xcconfig` from this directory, which Git ignores. Xcode Run and Archive use
that local setting without a command-line override. XcodeGen retains the wiring
through `configFiles` in `../project.yml`.

Store only the issued **SDK developer key** in the local file:

```xcconfig
APPSFLYER_DEV_KEY = <issued SDK developer key>
```

Replace the example value before building; do not use an administrative API token.
Keep the file readable only by its owner (`chmod 600 ios/Config/Local.xcconfig`
from the repository root). Do not commit it, include it in support bundles, or run
unfiltered `xcodebuild -showBuildSettings` with this file present. Build settings,
the compiled app's `Info.plist`, and some build logs can expose its value. The SDK
key necessarily ships in an enabled app; this file prevents accidental source
control and command-history exposure, not extraction from the distributed app.

Only `PrismAppsFlyerDevKey` is expanded into the app's existing `Info.plist`; the
local configuration file is outside the app's resource directory and is not
bundled. Key configuration does not grant consent: existing runtime gates and
both player choices still apply, including suppression in normal Debug/test runs.

To build without AppsFlyer configuration locally, temporarily remove the local
file or pass an explicit empty build setting, `APPSFLYER_DEV_KEY=`, to
`xcodebuild`. Command-line build settings override this file. Do not place the
actual key in a shell command or public CI setting. A future enabled CI release
must deliberately provision the ignored file from its existing secret mechanism;
the committed CI workflow remains keyless.
