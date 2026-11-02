#!/usr/bin/env python3
"""Rewrites OpenAPI constructs that the dart-dio generator can't compile.

Used by generate_api.sh between converting the schema to JSON and generating
the Dart client. Never changes the contract's meaning, only its shape.

Rule: a `oneOf`/`anyOf` whose branches are all inline, non-enum schemas of
the same primitive type collapses into that type. drf-spectacular emits this for
blank-allowed format fields, e.g. `EmailField(allow_blank=True)` becomes
`oneOf: [{type: string, format: email}, {type: string, maxLength: 0}]`.
dart-dio would turn it into an empty model class that doesn't compile; as a
plain string it becomes `String`. Formats and length limits of the branches
are dropped (the server validates); nullable, readOnly, writeOnly and
description are kept.

Usage: normalize_openapi.py IN.json OUT.json   (standard library only)
"""

from __future__ import annotations

import json
import sys
from typing import Any

PRIMITIVES = {"string", "integer", "number", "boolean"}
KEPT_KEYS = ("nullable", "readOnly", "writeOnly", "description", "title", "default", "example")


def collapse(node: dict[str, Any]) -> dict[str, Any] | None:
    """The collapsed schema if [node] is a same-primitive oneOf/anyOf."""
    for key in ("oneOf", "anyOf"):
        branches = node.get(key)
        if not isinstance(branches, list) or not branches:
            continue
        types = {b.get("type") for b in branches if isinstance(b, dict)}
        all_inline = all(isinstance(b, dict) and "$ref" not in b for b in branches)
        # Enum branches carry meaning (allowed values); never collapse those.
        has_enum = any(isinstance(b, dict) and "enum" in b for b in branches)
        if all_inline and not has_enum and len(types) == 1 and types <= PRIMITIVES:
            rest = {k: v for k, v in node.items() if k != key}
            if any(k not in KEPT_KEYS and k != "type" for k in rest):
                return None  # other constraints alongside the oneOf: leave it alone
            collapsed = {"type": types.pop()}
            collapsed.update({k: rest[k] for k in KEPT_KEYS if k in rest})
            if any(isinstance(b, dict) and b.get("nullable") for b in branches):
                collapsed["nullable"] = True
            return collapsed
    return None


def walk(node: Any, path: str, changes: list[str]) -> Any:
    if isinstance(node, dict):
        replacement = collapse(node)
        if replacement is not None:
            changes.append(path)
            return replacement
        return {k: walk(v, f"{path}/{k}", changes) for k, v in node.items()}
    if isinstance(node, list):
        return [walk(v, f"{path}/{i}", changes) for i, v in enumerate(node)]
    return node


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    with open(argv[0], encoding="utf-8") as f:
        spec = json.load(f)
    changes: list[str] = []
    spec = walk(spec, "#", changes)
    with open(argv[1], "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=2)
    for change in changes:
        print(f"  collapsed same-type oneOf/anyOf: {change}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
