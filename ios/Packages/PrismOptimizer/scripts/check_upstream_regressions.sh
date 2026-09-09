#!/bin/sh
set -eu

prism_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$prism_package_dir"
swift build -c release --product CPrismOptimizer
prism_bin_dir=$(swift build -c release --show-bin-path)
prism_library="$prism_bin_dir/libCPrismOptimizer.a"
# Xcode's SwiftPM backend exposes its product folder via this path.
if [ ! -f "$prism_library" ]; then
    prism_library="$prism_package_dir/.build/out/Products/Release/libCPrismOptimizer.a"
fi
xcrun clang++ -std=c++17 -O2 -mmacosx-version-min=13.0 \
    -isystem "$prism_package_dir/Sources/CHighs/include" \
    "$prism_package_dir/Validation/UpstreamRegressionTest.cpp" \
    "$prism_library" -o "$prism_bin_dir/upstream-regressions"
"$prism_bin_dir/upstream-regressions" "$prism_package_dir/Validation"
