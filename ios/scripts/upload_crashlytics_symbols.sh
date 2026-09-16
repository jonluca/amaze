#!/bin/bash
# Explicit release step: ordinary local builds and unit tests never upload symbols.
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <PrismRoll.xcarchive> <SourcePackages directory>" >&2
  exit 64
fi

archive="$1"
packages="$2"
app="$archive/Products/Applications/PrismRoll.app"
config="$app/GoogleService-Info.plist"
symbols="$archive/dSYMs/PrismRoll.app.dSYM"
uploader="$packages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"

for required in "$config" "$app/Info.plist" "$uploader"; do
  [[ -f "$required" ]] || { echo "Missing required file: $required" >&2; exit 1; }
done
[[ -d "$symbols" ]] || { echo "Missing app dSYM: $symbols" >&2; exit 1; }
[[ -x "$uploader" ]] || { echo "Crashlytics symbol uploader is not executable" >&2; exit 1; }

python3 - "$config" "$app/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path
config, info = (plistlib.loads(Path(path).read_bytes()) for path in sys.argv[1:])
assert config['PROJECT_ID'] == 'prism-roll', 'Unexpected Firebase project'
assert config['BUNDLE_ID'] == info['CFBundleIdentifier'] == 'com.jonluca.prismroll', 'Bundle mismatch'
assert info.get('FirebaseCrashlyticsCollectionEnabled') is False, 'Crash collection must be opt-in'
PY

"$uploader" -gsp "$config" -p ios "$symbols"
