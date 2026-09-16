#!/usr/bin/env python3
"""Compare this checkout's motion timeline with a Deque-only substitution.

Builds a temporary release-mode Swift package. Nothing is added to the app's
dependencies. Results include source hashes so later runs remain attributable.
"""

import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    args = parser.parse_args()
    here = pathlib.Path(__file__).resolve().parent
    ios = here.parents[2]
    source_root = ios / "PrismRoll"
    source_paths = [
        "Core/GridCell.swift",
        "Core/MoveDirection.swift",
        "Rendering/MazeSceneMove.swift",
        "Rendering/MazeMotionUpdate.swift",
        "Rendering/MazeMotionTimeline.swift",
    ]
    with tempfile.TemporaryDirectory(prefix="prism-collections-") as directory:
        package = pathlib.Path(directory)
        source = package / "Sources" / "Benchmark"
        source.mkdir(parents=True)
        (package / "Package.swift").write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "MotionCollectionsBenchmark",
    platforms: [.macOS(.v15)],
    dependencies: [.package(url: "https://github.com/apple/swift-collections.git", exact: "1.6.0")],
    targets: [.executableTarget(name: "Benchmark", dependencies: [.product(name: "DequeModule", package: "swift-collections")])]
)
''')
        source_hashes = {}
        for path in source_paths:
            data = (source_root / path).read_text()
            source_hashes[path] = hashlib.sha256(data.encode()).hexdigest()
            if path.endswith("MazeMotionTimeline.swift"):
                assert data.count("private var moves: [MazeSceneMove] = []") == 1
                for variant in ["Array", "Deque"]:
                    transformed = data.replace("struct MazeMotionTimeline", f"struct {variant}MotionTimeline")
                    if variant == "Deque":
                        transformed = "import DequeModule\n" + transformed.replace(
                            "private var moves: [MazeSceneMove] = []",
                            "private var moves: Deque<MazeSceneMove> = []",
                        )
                    (source / f"{variant}MotionTimeline.swift").write_text(transformed)
                    (source / f"{variant}MotionTimeline+Benchmark.swift").write_text(
                        f"extension {variant}MotionTimeline: BenchmarkTimeline {{}}\n"
                    )
            else:
                (source / pathlib.Path(path).name).write_text(data)
        for path in here.glob("*.swift"):
            shutil.copy(path, source)
        subprocess.run(["xcrun", "swift", "build", "-c", "release", "--package-path", str(package)], check=True)
        result = subprocess.run([str(package / ".build" / "release" / "Benchmark")], check=True, capture_output=True, text=True)
        report = json.loads(result.stdout)
        report["source_sha256"] = source_hashes
        report["swift_version"] = subprocess.check_output(["xcrun", "swift", "--version"], text=True).strip()
        report["hardware"] = subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"], text=True).strip()
        report["os"] = subprocess.check_output(["sw_vers"], text=True).strip()
        report["package_resolution"] = json.loads((package / "Package.resolved").read_text())
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
