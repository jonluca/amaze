#!/usr/bin/env python3
"""Reproduce the reviewed HiGHS source subset without build-time downloads."""

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request
from pathlib import Path

VERSION = "1.15.1"
COMMIT = "04024d701f79feb8e2f18bc3df0dffc04ef05088"
ARCHIVE_SHA256 = "2e121a70ae00f56db8e5ed993e4046c247248fa6280d839ff4808fa958971f0d"
URL = f"https://codeload.github.com/ERGO-Code/HiGHS/tar.gz/{COMMIT}"
PACKAGE = Path(__file__).resolve().parents[1]
PATCHES = (
    ("3177.patch", "664ed8898303f54614ab4f919d6b73b6d9099cd369f7f0665f0d7e1865393f68"),
    ("3179.patch", "d51fa825370fb1e785b3083cc61816eea6b0698f701989aa43efe7ec46c9411a"),
    ("3181.patch", "2d3fde7ca6da73a92b4bddd27c31e2f1239b41b0f9aa3107fb1f16a36e81ebe6"),
)
SOURCE_GROUPS = (
    "highs_sources", "cupdlp_sources", "ipx_sources", "basiclu_sources",
    "hipo_sources", "factor_highs_sources", "hipo_util_sources",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Use a previously downloaded archive")
    parser.add_argument("--check", action="store_true", help="Verify the checked-in subset matches the pin")
    args = parser.parse_args()

    with tempfile.TemporaryDirectory(prefix="prism-highs-") as temporary:
        workspace = Path(temporary)
        archive = args.archive or workspace / "source.tar.gz"
        if args.archive is None:
            urllib.request.urlretrieve(URL, archive)
        actual = hashlib.sha256(archive.read_bytes()).hexdigest()
        if actual != ARCHIVE_SHA256:
            raise SystemExit(f"HiGHS archive SHA256 mismatch: {actual}")
        with tarfile.open(archive) as source_archive:
            source_archive.extractall(workspace, filter="data")
        upstream = workspace / f"HiGHS-{COMMIT}"
        # Backport only the reviewed and merged upstream correctness fixes.
        # Each patch contains unchanged highs/ hunks from the linked PR diff.
        for name, expected in PATCHES:
            patch = PACKAGE / "Patches" / name
            if hashlib.sha256(patch.read_bytes()).hexdigest() != expected:
                raise SystemExit(f"Upstream fix checksum mismatch: {name}")
            subprocess.run(["git", "apply", "--check", str(patch)], cwd=upstream, check=True)
            subprocess.run(["git", "apply", str(patch)], cwd=upstream, check=True)
        result = workspace / "CHighs"
        include = result / "include"
        include.mkdir(parents=True)

        source_lists = (upstream / "cmake/sources.cmake").read_text()
        source_paths = []
        for group in SOURCE_GROUPS:
            match = re.search(r"set\(" + group + r"\s+([^)]*)\)", source_lists)
            if match is None:
                raise SystemExit(f"Missing upstream source list {group}")
            source_paths.extend("highs/" + name for name in match[1].split())
        source_paths.extend(("extern/HighsExtrasApi.cpp", "extern/HighsExtrasExternalDeps.cpp"))

        # Keep relative paths and bytes after the three declared upstream fixes.
        for relative in sorted(set(source_paths)):
            destination = result / "src" / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(upstream / relative, destination)
        for source in sorted((upstream / "highs").rglob("*")):
            if source.suffix not in {".h", ".hpp", ".hh"}:
                continue
            destination = include / source.relative_to(upstream / "highs")
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            # Preserve local quoted-include resolution. Several solver
            # components deliberately use the same header names (Model.h,
            # Control.h), so a flat header-search order would change semantics.
            local_header = result / "src/highs" / source.relative_to(upstream / "highs")
            local_header.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, local_header)
        for name in ("HighsExtrasApi.h", "HighsExtrasApiBinding.h", "HighsExtrasExternalDeps.h", "OrderingPrint.h"):
            shutil.copyfile(upstream / "extern" / name, include / name)
        # The upstream MIT build keeps these function declarations in its
        # disabled extras dispatch table; no provider implementation is copied.
        for name in ("amd/amd.h", "amd/SuiteSparse_config.h", "blas/mycblas.h", "metis/metis.h", "rcm/rcm.h"):
            destination = include / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(upstream / "extern" / name, destination)
        (include / "pdqsort").mkdir()
        shutil.copyfile(upstream / "extern/pdqsort/pdqsort.h", include / "pdqsort/pdqsort.h")
        # A few upstream sources use ../extern relative to the high-level
        # include root rather than the normal pdqsort/pdqsort.h spelling.
        (result / "extern/pdqsort").mkdir(parents=True)
        shutil.copyfile(upstream / "extern/pdqsort/pdqsort.h", result / "extern/pdqsort/pdqsort.h")

        # The optional HiPO external providers, compressed file reader, GPU, and
        # dynamic extras loading are absent. Internal HiPO wrappers remain in the
        # MIT core, exactly as in the upstream MIT static library configuration.
        (include / "HConfig.h").write_text(f'''// Generated by scripts/vendor_highs.py; Apple static, MIT configuration.
#ifndef HCONFIG_H_
#define HCONFIG_H_
#define FAST_BUILD
#define CUPDLP_CPU
#define HIGHS_NO_DEFAULT_THREADS
#define HIGHS_HAVE_BUILTIN_CLZ
#define HIGHS_GITHASH "{COMMIT}+upstream-3177-3179-3181"
#define HIGHS_VERSION_MAJOR 1
#define HIGHS_VERSION_MINOR 15
#define HIGHS_VERSION_PATCH 1
#endif
''')
        (include / "module.modulemap").write_text('''module CHighs {
    header "interfaces/highs_c_api.h"
    export *
}
''')
        manifest = {str(path.relative_to(result)): hashlib.sha256(path.read_bytes()).hexdigest()
                    for path in sorted(result.rglob("*")) if path.is_file()}
        manifest_path = PACKAGE / "VendorManifest.json"
        if args.check:
            checked_in = PACKAGE / "Sources/CHighs"
            actual_manifest = {str(path.relative_to(checked_in)): hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in sorted(checked_in.rglob("*")) if path.is_file()}
            if actual_manifest != manifest or json.loads(manifest_path.read_text()) != manifest:
                raise SystemExit("Vendored HiGHS differs from the pinned reproducible subset")
            print(f"Verified {len(manifest)} vendored files against HiGHS {VERSION} {COMMIT}")
            return
        destination = PACKAGE / "Sources/CHighs"
        if destination.exists():
            shutil.rmtree(destination)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(result, destination)
        manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
        licenses = PACKAGE / "Licenses"
        licenses.mkdir(exist_ok=True)
        shutil.copyfile(upstream / "LICENSE.txt", licenses / "HiGHS-MIT.txt")
        shutil.copyfile(upstream / "extern/pdqsort/license.txt", licenses / "pdqsort-Zlib.txt")
        shutil.copyfile(upstream / "extern/amd/License.txt", licenses / "AMD-BSD-3-Clause.txt")
        shutil.copyfile(upstream / "extern/metis/LICENSE.txt", licenses / "METIS-Apache-2.0.txt")
        shutil.copyfile(upstream / "extern/rcm/LICENSE", licenses / "RCM-MIT.txt")
        print(f"Vendored {len(manifest)} files from HiGHS {VERSION} {COMMIT}")


if __name__ == "__main__":
    main()
