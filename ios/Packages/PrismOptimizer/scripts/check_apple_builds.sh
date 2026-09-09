#!/bin/sh
set -eu

prism_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
prism_artifact_dir=${PRISM_OPTIMIZER_BUILD_DIR:-"$prism_package_dir/.build/apple-validation"}
mkdir -p "$prism_artifact_dir"
cd "$prism_package_dir"

for prism_platform in iphoneos iphonesimulator; do
    if [ "$prism_platform" = iphoneos ]; then
        prism_destination='generic/platform=iOS'
    else
        prism_destination='generic/platform=iOS Simulator'
    fi
    xcodebuild build -scheme PrismOptimizer -configuration Release \
        -destination "$prism_destination" -sdk "$prism_platform" \
        -derivedDataPath "$prism_artifact_dir/$prism_platform" \
        ARCHS=arm64 ONLY_ACTIVE_ARCH=NO IPHONEOS_DEPLOYMENT_TARGET=17.0 \
        CODE_SIGNING_ALLOWED=NO > "$prism_artifact_dir/$prism_platform.log" 2>&1
    printf '%s build succeeded\n' "$prism_platform"
done
