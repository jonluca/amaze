#!/bin/sh
set -eu

prism_package_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$prism_package_dir"
swift build -c release --product CPrismOptimizer
prism_bin_dir=$(swift build -c release --show-bin-path)
prism_library="$prism_bin_dir/libCPrismOptimizer.a"
if [ ! -f "$prism_library" ]; then
    prism_library="$prism_package_dir/.build/out/Products/Release/libCPrismOptimizer.a"
fi

prism_validation_dir=$(mktemp -d)
trap 'rm -rf "$prism_validation_dir"' EXIT HUP INT TERM
prism_stride=1
set -- "${1:-}"
case "$1" in
    "") set -- ;;
    --force-mip)
        # Change only a temporary copy, so this deliberately slower oracle
        # cannot alter the shipping solver or its normal small-state fast path.
        python3 - "$prism_package_dir/Sources/CPrismOptimizer/PrismOptimizer.cpp" "$prism_validation_dir/PrismOptimizer.cpp" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
original = "constexpr uint32_t kMaximumStates = 1u << 20;"
if source.count(original) != 1:
    raise SystemExit("Cannot identify exactly one native BFS state limit")
Path(sys.argv[2]).write_text(source.replace(original, "constexpr uint32_t kMaximumStates = 0;"))
PY
        set -- "$prism_validation_dir/PrismOptimizer.cpp"
        prism_stride=17
        ;;
    *) printf '%s\n' "Usage: $0 [--force-mip]" >&2; exit 2 ;;
esac

xcrun clang++ -std=c++17 -O2 -mmacosx-version-min=13.0 \
    -I "$prism_package_dir/Sources/CPrismOptimizer/include" \
    -isystem "$prism_package_dir/Sources/CHighs/include" \
    "$prism_package_dir/Validation/CurrentStateOracle.cpp" "$@" \
    "$prism_library" -o "$prism_validation_dir/current-state-oracle"
"$prism_validation_dir/current-state-oracle" "$prism_stride"
