"""Map a pytest JUnit XML report to test case IDs (P<phase>-TC-<nn>).

Usage: uv run python tools/tcmap.py <junit.xml> [<junit.xml> ...]

A case is PASS when every test naming it passed (xfail counts as KNOWN), FAIL when any failed or
errored, SKIP when all were skipped. Test names carry the case numbers: test_p5_tc69_..., and
combined tests such as test_p6_tc14_tc15_tc16_... map to each number.
"""

from __future__ import annotations

import re
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict

NAME = re.compile(r"test_p(\d)_((?:tc\d+[a-z]?_)+)")


def outcome(case: ET.Element) -> str:
    for child in case:
        if child.tag in ("failure", "error"):
            return "FAIL"
        if child.tag == "skipped":
            return "XFAIL" if "xfail" in (child.get("type", "") + child.get("message", "")).lower() else "SKIP"
    return "PASS"


def main(paths: list[str]) -> None:
    cases: dict[str, list[tuple[str, str]]] = defaultdict(list)
    for path in paths:
        for tc in ET.parse(path).getroot().iter("testcase"):
            m = NAME.search(tc.get("name", ""))
            if not m:
                continue
            for n in re.findall(r"tc(\d+)", m.group(2)):
                cases[f"P{m.group(1)}-TC-{int(n):02d}"].append((tc.get("name"), outcome(tc)))
    summary = defaultdict(int)
    for cid in sorted(cases, key=lambda c: (c[:2], int(c.split("-")[-1]))):
        res = [o for _, o in cases[cid]]
        if "FAIL" in res:
            verdict = "FAIL"
        elif all(o == "SKIP" for o in res):
            verdict = "SKIP"
        elif "XFAIL" in res:
            verdict = "KNOWN"
        else:
            verdict = "PASS"
        summary[verdict] += 1
        detail = ", ".join(f"{n}={o}" for n, o in cases[cid] if o != "PASS") if verdict != "PASS" else ""
        print(f"{cid} {verdict} {detail}")
    print("SUMMARY", dict(summary))


if __name__ == "__main__":
    main(sys.argv[1:])
