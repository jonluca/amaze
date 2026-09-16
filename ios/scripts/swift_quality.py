#!/usr/bin/env python3
"""Run the repository's pinned Swift tools on macOS without changing Homebrew."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / ".cache" / "swift-quality"
SOURCES = ["ios/PrismRoll", "ios/PrismRollTests", "ios/PrismRollUITests", "ios/scripts"]


def tool_version(binary):
    return subprocess.check_output([str(binary), "--version"], text=True).strip()


def install_tool(name, specification):
    binary = CACHE / name / specification["version"] / name
    if not binary.exists():
        binary.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=binary.parent) as temporary:
            archive = Path(temporary) / "download.zip"
            print(f"Installing {name} {specification['version']} from its official release", flush=True)
            subprocess.run([
                "curl", "--fail", "--location", "--silent", "--show-error", "--retry", "3",
                "--output", str(archive), specification["url"],
            ], check=True)
            actual = hashlib.sha256(archive.read_bytes()).hexdigest()
            if actual != specification["sha256"]:
                raise RuntimeError(f"{name}: downloaded archive checksum does not match the pin")
            candidate = Path(temporary) / name
            # Extract only the named executable, never archive-provided paths.
            with zipfile.ZipFile(archive) as package:
                candidate.write_bytes(package.read(name))
            candidate.chmod(0o755)
            if tool_version(candidate) != specification["version"]:
                raise RuntimeError(f"{name}: downloaded executable has an unexpected version")
            os.replace(candidate, binary)
    actual = tool_version(binary)
    if actual != specification["version"]:
        raise RuntimeError(f"{name}: expected {specification['version']}, found {actual}")
    print(f"Using {name} {actual}", flush=True)
    return str(binary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["bootstrap", "check", "format"], nargs="?", default="check")
    arguments = parser.parse_args()
    if sys.platform != "darwin":
        parser.error("The pinned executables require macOS; CI uses macos-26.")

    specifications = json.loads((Path(__file__).with_name("swift-tools.json")).read_text())
    binaries = {name: install_tool(name, spec) for name, spec in specifications.items()}
    if arguments.command == "bootstrap":
        return 0

    formatter = [binaries["swiftformat"], *SOURCES, "--config", "ios/.swiftformat", "--cache", "ignore"]
    if arguments.command == "check":
        formatter.append("--lint")
    format_result = subprocess.run(formatter, cwd=ROOT, check=False)
    # Run both checks so one invocation reports formatting and lint failures.
    lint_result = subprocess.run([
        binaries["swiftlint"], "lint", "--config", "ios/.swiftlint.yml",
        "--strict", "--force-exclude", "--no-cache", "--quiet", *SOURCES,
    ], cwd=ROOT, check=False)
    return 1 if format_result.returncode or lint_result.returncode else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError, zipfile.BadZipFile, KeyError) as error:
        print(f"Swift quality check failed: {error}", file=sys.stderr)
        sys.exit(1)
