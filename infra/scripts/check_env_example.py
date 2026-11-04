#!/usr/bin/env python3
"""Fail if an environment variable read by the backend settings is missing from the env example.

Usage (from anywhere; standard library only, Python 3.9+):

    python3 infra/scripts/check_env_example.py            # check, exit 1 on missing names
    python3 infra/scripts/check_env_example.py --list     # also print every name found in code
    python3 infra/scripts/check_env_example.py --help

What it scans: every ``*.py`` under ``backend/config/`` (settings, sentry, celery) and
``backend/apps/`` (e.g. the seed command), except ``tests/`` folders and ``config/env.py`` (the
helper definitions), via the AST, for:

- ``env_str/env_int/env_bool/env_float/env_list/env_dict("NAME", ...)``
- ``env_test_database_name()`` / ``env_test_redis_db()`` (their default names) or with a name
- ``os.environ.get("NAME")``, ``os.environ["NAME"]``, ``os.environ.setdefault("NAME", ...)``,
  ``os.getenv("NAME")``

Every such name must appear as an uncommented ``NAME=`` line in ``infra/env/backend.env.example``.
Names in the example that no code reads are reported as a warning only (some are read by
docker-compose interpolation, e.g. MINIO_ROOT_USER). Read-only and idempotent: changes nothing.

Limits (static analysis only): names built dynamically (f-strings, concatenation, loops) or passed
through a constant or variable (``env_str(NAME)``) are not detected, nor are ``env_*`` calls that
pass the name as a keyword (``env_str(name="X")``); only ``env_test_*`` helpers read ``name=``.
Keep env reads as literal first arguments so this check sees them.
"""

from __future__ import annotations

import argparse
import ast
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SCAN_DIRS = [REPO_ROOT / "backend" / "config", REPO_ROOT / "backend" / "apps"]
DEFAULT_EXAMPLE = REPO_ROOT / "infra" / "env" / "backend.env.example"

ENV_HELPERS = {"env_str", "env_int", "env_bool", "env_float", "env_list", "env_dict"}
# Helpers whose variable name is a parameter default in config/env.py.
DEFAULT_NAME_HELPERS = {
    "env_test_database_name": "POSTGRES_TEST_DB",
    "env_test_redis_db": "TEST_REDIS_DB",
}
SKIP_FILES = {REPO_ROOT / "backend" / "config" / "env.py"}  # the helper definitions themselves
SKIP_DIR_NAMES = {"tests", "migrations"}
EXAMPLE_LINE = re.compile(r"^([A-Z][A-Z0-9_]*)=")
# Read by docker-compose interpolation, not by Django settings.
COMPOSE_ONLY = {"MINIO_ROOT_USER", "MINIO_ROOT_PASSWORD"}


def _const_str(node: ast.AST | None) -> str | None:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None


def _is_os_environ(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Attribute)
        and node.attr == "environ"
        and isinstance(node.value, ast.Name)
        and node.value.id == "os"
    )


def _is_env_getter(func: ast.Attribute) -> bool:
    """``os.environ.get`` / ``os.environ.setdefault`` / ``os.getenv``."""
    if func.attr in {"get", "setdefault"}:
        return _is_os_environ(func.value)
    return func.attr == "getenv" and isinstance(func.value, ast.Name) and func.value.id == "os"


def names_in_source(source: str, filename: str) -> dict[str, int]:
    """Map each environment variable name read in ``source`` to its first line number."""
    found: dict[str, int] = {}

    def add(name: str | None, node: ast.AST) -> None:
        if name and name not in found:
            found[name] = node.lineno

    for node in ast.walk(ast.parse(source, filename=filename)):
        if isinstance(node, ast.Call):
            func = node.func
            first = node.args[0] if node.args else None
            if isinstance(func, ast.Name) and func.id in ENV_HELPERS:
                add(_const_str(first), node)
            elif isinstance(func, ast.Name) and func.id in DEFAULT_NAME_HELPERS:
                keyword = next((k.value for k in node.keywords if k.arg == "name"), None)
                add(_const_str(first or keyword) or DEFAULT_NAME_HELPERS[func.id], node)
            elif isinstance(func, ast.Attribute) and _is_env_getter(func):
                add(_const_str(first), node)
        elif isinstance(node, ast.Subscript) and _is_os_environ(node.value):
            add(_const_str(node.slice), node)
    return found


def _relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def names_in_code(scan_dirs: list[Path]) -> dict[str, str]:
    """Map each name to the first ``file:line`` that reads it."""
    result: dict[str, str] = {}
    paths = sorted(path for directory in scan_dirs for path in directory.rglob("*.py"))
    for path in paths:
        if path.resolve() in SKIP_FILES or SKIP_DIR_NAMES.intersection(path.parts):
            continue
        source = path.read_text(encoding="utf-8")
        for name, line in names_in_source(source, str(path)).items():
            result.setdefault(name, f"{_relative(path)}:{line}")
    return result


def names_in_example(example: Path) -> set[str]:
    names = set()
    for line in example.read_text(encoding="utf-8").splitlines():
        match = EXAMPLE_LINE.match(line)
        if match:
            names.add(match.group(1))
    return names


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Check that every env var the backend reads is listed in the env example."
    )
    parser.add_argument(
        "--scan-dir",
        type=Path,
        action="append",
        dest="scan_dirs",
        help="directory to scan (repeatable; default: backend/config and backend/apps)",
    )
    parser.add_argument("--example", type=Path, default=DEFAULT_EXAMPLE)
    parser.add_argument("--list", action="store_true", help="print every name found in code")
    args = parser.parse_args(argv)

    scan_dirs = args.scan_dirs or DEFAULT_SCAN_DIRS
    in_code = names_in_code(scan_dirs)
    in_example = names_in_example(args.example)
    if not in_code:
        print(f"error: no environment variable reads found under {scan_dirs}")
        return 2

    if args.list:
        for name in sorted(in_code):
            print(f"{name:45} {in_code[name]}")

    missing = sorted(set(in_code) - in_example)
    unused = sorted(in_example - set(in_code) - COMPOSE_ONLY)
    for name in unused:
        print(f"::warning::{name} is in {args.example.name} but no backend code reads it")
    if missing:
        example = _relative(args.example)
        for name in missing:
            print(f"::error::{name} (read at {in_code[name]}) is missing from {example}")
        print(f"{len(missing)} variable(s) missing. Add them with a placeholder and a comment.")
        return 1
    print(f"OK: all {len(in_code)} variables the backend reads are in {args.example.name}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
