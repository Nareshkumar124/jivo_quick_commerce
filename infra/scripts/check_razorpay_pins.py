#!/usr/bin/env python3
"""Fail if the customer app's Razorpay SDK versions drift from the pinned, verified set.

Usage (from anywhere; standard library only, Python 3.9+):

    python3 infra/scripts/check_razorpay_pins.py
    python3 infra/scripts/check_razorpay_pins.py --help

razorpay_flutter depends on floating native versions (com.razorpay:checkout:1.6.+, and checkout on
standard-core:latest.integration), so customer_app/android/app/build.gradle.kts forces an exact
set. That set was checked for the release build (R8 keep rules, merged manifest and permissions,
Play Data Safety; customer_app/README.md "Payments"). This check makes a bump deliberate: change
the pins below together with the app, in the same reviewed change, after re-running those checks.

Checks:
1. customer_app/pubspec.yaml declares razorpay_flutter as an exact version (no ^ or range).
2. customer_app/pubspec.lock resolves razorpay_flutter to EXPECTED_FLUTTER_PLUGIN.
3. build.gradle.kts forces exactly EXPECTED_ANDROID (each artifact once, at that version).
4. rider_app does not depend on razorpay_flutter (payments are customer-only).

Read-only and idempotent.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# The verified set. Bump only together with customer_app (see the docstring).
EXPECTED_FLUTTER_PLUGIN = "1.4.7"
EXPECTED_ANDROID = {
    "com.razorpay:checkout": "1.6.41",
    "com.razorpay:standard-core": "1.7.22",
    "com.razorpay:core": "1.0.22",
}

PUBSPEC = REPO_ROOT / "customer_app" / "pubspec.yaml"
LOCKFILE = REPO_ROOT / "customer_app" / "pubspec.lock"
GRADLE = REPO_ROOT / "customer_app" / "android" / "app" / "build.gradle.kts"
RIDER_PUBSPEC = REPO_ROOT / "rider_app" / "pubspec.yaml"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def check_pubspec(text: str) -> list[str]:
    match = re.search(r"^\s+razorpay_flutter:\s*(\S+)\s*$", text, re.MULTILINE)
    if not match:
        return [f"{PUBSPEC.name}: razorpay_flutter is not declared as a plain version"]
    declared = match.group(1).strip("\"'")
    if declared != EXPECTED_FLUTTER_PLUGIN:
        return [
            f"{PUBSPEC.name}: razorpay_flutter is {declared!r}; the pin is exactly "
            f"{EXPECTED_FLUTTER_PLUGIN!r} (no ^ or range)"
        ]
    return []


def check_lockfile(text: str) -> list[str]:
    match = re.search(
        r"^  razorpay_flutter:\n(?:^    .*\n)*?^    version: \"([^\"]+)\"", text, re.MULTILINE
    )
    if not match:
        return [f"{LOCKFILE.name}: razorpay_flutter not found"]
    if match.group(1) != EXPECTED_FLUTTER_PLUGIN:
        return [
            f"{LOCKFILE.name}: razorpay_flutter resolves to {match.group(1)}, "
            f"expected {EXPECTED_FLUTTER_PLUGIN}"
        ]
    return []


def check_gradle(text: str) -> list[str]:
    errors = []
    forced = re.search(r"resolutionStrategy\.force\((.*?)\)", text, re.DOTALL)
    if not forced:
        return [f"{GRADLE.name}: no resolutionStrategy.force(...) block pinning the Razorpay SDK"]
    found: dict[str, list[str]] = {}
    for group, artifact, version in re.findall(
        r"\"(com\.razorpay):([\w.-]+):([^\"]+)\"", forced.group(1)
    ):
        found.setdefault(f"{group}:{artifact}", []).append(version)
    for coordinate, expected in EXPECTED_ANDROID.items():
        versions = found.get(coordinate)
        if not versions:
            errors.append(f"{GRADLE.name}: {coordinate} is not forced (expected {expected})")
        elif versions != [expected]:
            errors.append(f"{GRADLE.name}: {coordinate} forced to {versions}, expected {expected}")
    for coordinate in sorted(set(found) - set(EXPECTED_ANDROID)):
        errors.append(f"{GRADLE.name}: unexpected forced artifact {coordinate}; update this check")
    # Any other mention of a Razorpay artifact with a floating version is drift too.
    for coordinate, version in re.findall(r"\"(com\.razorpay:[\w.-]+):([^\"]+)\"", text):
        if "+" in version or "latest" in version:
            errors.append(f"{GRADLE.name}: {coordinate}:{version} is a floating version")
    return errors


def check_rider(text: str) -> list[str]:
    if re.search(r"^\s+razorpay_flutter:", text, re.MULTILINE):
        return [f"rider_app/{RIDER_PUBSPEC.name}: razorpay_flutter is customer-only"]
    return []


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check the customer app's Razorpay Flutter plugin and Android SDK pins."
    )
    parser.parse_args(argv)

    errors = (
        check_pubspec(_read(PUBSPEC))
        + check_lockfile(_read(LOCKFILE))
        + check_gradle(_read(GRADLE))
        + check_rider(_read(RIDER_PUBSPEC))
    )
    for error in errors:
        print(f"::error::{error}")
    if errors:
        print(
            "Razorpay SDK pins drifted. A bump is deliberate: update customer_app and the pins in "
            "infra/scripts/check_razorpay_pins.py together, and re-run the release-build checks."
        )
        return 1
    android = ", ".join(f"{c}:{v}" for c, v in EXPECTED_ANDROID.items())
    print(f"OK: razorpay_flutter {EXPECTED_FLUTTER_PLUGIN}; Android {android}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
