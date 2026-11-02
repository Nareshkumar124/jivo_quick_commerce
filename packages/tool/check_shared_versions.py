#!/usr/bin/env python3
"""Fails if a package resolves to different versions in different lockfiles.

The apps and packages are separate Flutter projects, each with its own
pubspec.lock. A dependency shared by two of them (e.g. dio in customer_app and
rider_app) must resolve to the same version everywhere, so the projects behave
alike and jivo_core is tested against the versions the apps ship.

Usage (from any directory):
    python3 packages/tool/check_shared_versions.py [LOCKFILE ...]

Without arguments it checks the lockfiles of customer_app, rider_app,
packages/jivo_core and packages/jivo_api. Uses only the standard library.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_LOCKFILES = [
    "customer_app/pubspec.lock",
    "rider_app/pubspec.lock",
    "packages/jivo_core/pubspec.lock",
    "packages/jivo_api/pubspec.lock",
]

_PACKAGE = re.compile(r"^  ([A-Za-z0-9_]+):\s*$")
_VERSION = re.compile(r'^    version: "?([^"\s]+)"?\s*$')
_SOURCE = re.compile(r"^    source: (\S+)\s*$")


def read_lockfile(path: Path) -> dict[str, tuple[str, str]]:
    """Returns {package: (version, source)} from a pubspec.lock."""
    packages: dict[str, tuple[str, str]] = {}
    in_packages = False
    name = version = source = None

    def flush() -> None:
        if name and version:
            packages[name] = (version, source or "?")

    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith(" "):
            flush()
            name = version = source = None
            in_packages = line.strip() == "packages:"
            continue
        if not in_packages:
            continue
        if match := _PACKAGE.match(line):
            flush()
            name, version, source = match.group(1), None, None
        elif match := _VERSION.match(line):
            version = match.group(1)
        elif match := _SOURCE.match(line):
            source = match.group(1)
    flush()
    if not packages:
        raise ValueError(f"no packages found in {path}")
    return packages


def main(argv: list[str]) -> int:
    paths = [Path(a) for a in argv] or [REPO_ROOT / p for p in DEFAULT_LOCKFILES]
    missing = [p for p in paths if not p.is_file()]
    if missing:
        print("Missing lockfile(s): " + ", ".join(map(str, missing)), file=sys.stderr)
        return 2

    locks = {p: read_lockfile(p) for p in paths}
    versions: dict[str, dict[str, list[Path]]] = {}
    for path, packages in locks.items():
        for name, (version, source) in packages.items():
            if source == "path":
                continue  # local packages (jivo_core, jivo_api) have no version pin
            versions.setdefault(name, {}).setdefault(version, []).append(path)

    conflicts = {n: v for n, v in sorted(versions.items()) if len(v) > 1}
    shared = sum(1 for v in versions.values() if sum(map(len, v.values())) > 1)
    for name, by_version in conflicts.items():
        print(f"{name}:", file=sys.stderr)
        for version, where in sorted(by_version.items()):
            print(f"  {version}: " + ", ".join(str(p) for p in where), file=sys.stderr)

    if conflicts:
        print(
            f"{len(conflicts)} shared package(s) resolve to different versions. "
            "Align the constraints or run `flutter pub upgrade <package>` in the "
            "projects that lag behind.",
            file=sys.stderr,
        )
        return 1
    print(f"OK: {shared} shared packages, same version in all {len(paths)} lockfiles.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
