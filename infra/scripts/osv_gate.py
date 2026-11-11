#!/usr/bin/env python3
"""Fail on HIGH/CRITICAL dependency advisories in an osv-scanner JSON report.

Usage (from the repo root; standard library only, Python 3.9+):

    osv-scanner scan source --config infra/security/osv-scanner.toml \\
        -L backend/uv.lock -L customer_app/pubspec.lock ... --format json --output-file osv.json
    python3 infra/scripts/osv_gate.py osv.json                  # fail on HIGH and CRITICAL
    python3 infra/scripts/osv_gate.py osv.json --fail-on critical
    python3 infra/scripts/osv_gate.py --self-test
    python3 infra/scripts/osv_gate.py --help

osv-scanner has no severity threshold: it exits 1 for any advisory. This script reads its JSON
report and rates each advisory group (one advisory and its aliases, e.g. PYSEC-... + GHSA-...):
- the CVSS base score osv-scanner reports for the group (`max_severity`): >= 9.0 CRITICAL,
  >= 7.0 HIGH, >= 4.0 MEDIUM, > 0 LOW;
- raised to the GitHub advisory label (`database_specific.severity`: CRITICAL, HIGH, MODERATE,
  LOW) when that is higher, or used when there is no score;
- a MAL-* id (a known malicious package) is always CRITICAL;
- otherwise UNKNOWN, reported as a warning to check by hand.

It prints one line per group (severity, package@version, lockfile, ids, fixed versions) and,
on GitHub Actions, writes ::error (at or above --fail-on) / ::warning annotations on the lockfile
and a Markdown table to $GITHUB_STEP_SUMMARY.

Exit codes: 0 nothing at or above --fail-on; 1 at least one advisory at or above it; 2 the
report could not be read. Read-only and idempotent. Reviewed exceptions belong in
infra/security/osv-scanner.toml (docs/deployment.md §2.2), never in this script.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

LEVELS = ("UNKNOWN", "LOW", "MEDIUM", "HIGH", "CRITICAL")
RANK = {name: rank for rank, name in enumerate(LEVELS)}
# GitHub advisory labels (database_specific.severity) -> our levels.
GHSA_LABELS = {
    "LOW": "LOW",
    "MODERATE": "MEDIUM",
    "MEDIUM": "MEDIUM",
    "HIGH": "HIGH",
    "CRITICAL": "CRITICAL",
}
SUMMARY_ROWS = 200


@dataclass
class Finding:
    severity: str
    lockfile: str
    ecosystem: str
    name: str
    version: str
    ids: list[str]
    fixed: list[str] = field(default_factory=list)
    summary: str = ""

    @property
    def package(self) -> str:
        return f"{self.name}@{self.version}"


def rate_score(score: object) -> str:
    try:
        value = float(str(score))
    except ValueError:
        return "UNKNOWN"
    if value >= 9.0:
        return "CRITICAL"
    if value >= 7.0:
        return "HIGH"
    if value >= 4.0:
        return "MEDIUM"
    return "LOW" if value > 0 else "UNKNOWN"


def rate_group(group: dict, vulns: dict[str, dict]) -> str:
    ids = list(group.get("ids") or []) + list(group.get("aliases") or [])
    if any(str(i).startswith("MAL-") for i in ids):
        return "CRITICAL"
    best = rate_score(group.get("max_severity"))
    for vid in ids:
        label = ((vulns.get(vid) or {}).get("database_specific") or {}).get("severity")
        mapped = GHSA_LABELS.get(str(label).upper()) if label else None
        if mapped and RANK[mapped] > RANK[best]:
            best = mapped
    return best


def _norm(name: str) -> str:
    return re.sub(r"[-_.]+", "-", name).lower()


def _version_key(version: str) -> list[tuple[int, int | str]]:
    return [(0, int(p)) if p.isdigit() else (1, p) for p in re.split(r"[.+\-]", version) if p]


def fixed_versions(vulns: list[dict], name: str, ecosystem: str, current: str) -> list[str]:
    """The fixed versions of this package newer than the current one (all of them if none is)."""
    found: set[str] = set()
    for vuln in vulns:
        for affected in vuln.get("affected") or []:
            pkg = affected.get("package") or {}
            if str(pkg.get("ecosystem", "")).split(":")[0] != ecosystem:
                continue
            if _norm(str(pkg.get("name", ""))) != _norm(name):
                continue
            for rng in affected.get("ranges") or []:
                for event in rng.get("events") or []:
                    if "fixed" in event:
                        found.add(str(event["fixed"]))
    ordered = sorted(found, key=_version_key)
    newer = [v for v in ordered if _version_key(v) > _version_key(current)]
    return newer or ordered


def _relative(path: str) -> str:
    try:
        rel = os.path.relpath(path)
    except ValueError:  # another drive on Windows
        rel = path
    return rel.replace("\\", "/")


def collect(report: dict) -> list[Finding]:
    findings = []
    for result in report.get("results") or []:
        lockfile = _relative(str((result.get("source") or {}).get("path", "?")))
        for pkg in result.get("packages") or []:
            info = pkg.get("package") or {}
            name, version = str(info.get("name", "?")), str(info.get("version", "?"))
            ecosystem = str(info.get("ecosystem", "?"))
            vulns = {str(v.get("id")): v for v in pkg.get("vulnerabilities") or []}
            for group in pkg.get("groups") or []:
                ids = [str(i) for i in group.get("ids") or []]
                members = [vulns[i] for i in ids if i in vulns]
                summary = next((str(v["summary"]) for v in members if v.get("summary")), "")
                findings.append(
                    Finding(
                        severity=rate_group(group, vulns),
                        lockfile=lockfile,
                        ecosystem=ecosystem,
                        name=name,
                        version=version,
                        ids=ids,
                        fixed=fixed_versions(members, name, ecosystem, version),
                        summary=summary,
                    )
                )
    findings.sort(key=lambda f: (-RANK[f.severity], f.lockfile, f.name, f.ids))
    return findings


def _say(text: str) -> None:
    sys.stdout.write(text + "\n")


def _escape_data(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def _escape_prop(text: str) -> str:
    return _escape_data(text).replace(":", "%3A").replace(",", "%2C")


def annotation(finding: Finding, failing: bool) -> str:
    kind = "error" if failing else "warning"
    fixed = ", ".join(finding.fixed) or "no fixed version yet"
    title = f"{finding.severity} advisory in {finding.package}"
    ids = " / ".join(finding.ids)
    message = f"{ids} ({finding.ecosystem}): {finding.summary} Fixed in: {fixed}."
    return (
        f"::{kind} file={_escape_prop(finding.lockfile)},title={_escape_prop(title)}::"
        f"{_escape_data(message)}"
    )


def markdown(findings: list[Finding], fail_on: str) -> str:
    counts = {level: sum(f.severity == level for f in findings) for level in reversed(LEVELS)}
    lines = [
        f"### osv-scanner: {len(findings)} advisory group(s), failing at {fail_on} and above",
        "",
        " | ".join(f"{level} {n}" for level, n in counts.items()),
        "",
    ]
    if findings:
        lines += [
            "| Severity | Package | Lockfile | Advisory | Fixed in |",
            "|---|---|---|---|---|",
        ]
        for f in findings[:SUMMARY_ROWS]:
            links = ", ".join(f"[{i}](https://osv.dev/vulnerability/{i})" for i in f.ids)
            fixed = ", ".join(f.fixed) or "none yet"
            lines.append(f"| {f.severity} | `{f.package}` | `{f.lockfile}` | {links} | {fixed} |")
        if len(findings) > SUMMARY_ROWS:
            lines.append(f"\n{len(findings) - SUMMARY_ROWS} more not shown; see the job log.")
    return "\n".join(lines) + "\n"


def evaluate(report: dict, fail_on: str, github: bool = False) -> tuple[int, list[str]]:
    findings = collect(report)
    threshold = RANK[fail_on]
    out = []
    for f in findings:
        failing = RANK[f.severity] >= threshold
        fixed = ", ".join(f.fixed) or "none yet"
        out.append(
            f"{f.severity:8s} {f.package} ({f.ecosystem}) {f.lockfile}  "
            f"{' / '.join(f.ids)}  fixed: {fixed}"
        )
        if github:
            out.append(annotation(f, failing))
    blocking = sum(RANK[f.severity] >= threshold for f in findings)
    out.append(
        f"osv-scanner: {len(findings)} advisory group(s); {blocking} at {fail_on} or above "
        f"({'FAIL' if blocking else 'OK'})."
    )
    return (1 if blocking else 0), out


def _vuln(vid: str, label: str | None = None, fixed: str = "2.0.1") -> dict:
    """A minimal OSV record for the self-test (package name spelled differently on purpose)."""
    return {
        "id": vid,
        "summary": f"summary of {vid}",
        "database_specific": {"severity": label} if label else None,
        "affected": [
            {
                "package": {"name": "Some_Pkg", "ecosystem": "PyPI"},
                "ranges": [{"events": [{"introduced": "0"}, {"fixed": fixed}]}],
            }
        ],
    }


def self_test() -> int:
    vuln = _vuln
    report = {
        "results": [
            {
                "source": {"path": "backend/uv.lock"},
                "packages": [
                    {
                        "package": {"name": "some-pkg", "version": "2.0.0", "ecosystem": "PyPI"},
                        "vulnerabilities": [
                            vuln("A-1", fixed="1.9.9"),
                            vuln("A-2"),
                            vuln("B-1", "HIGH"),
                            vuln("C-1", "MODERATE"),
                            vuln("D-1"),
                            vuln("E-1", "LOW"),
                        ],
                        "groups": [
                            {"ids": ["A-1", "A-2"], "max_severity": "9.8"},
                            {"ids": ["B-1"], "max_severity": ""},
                            {"ids": ["C-1"], "max_severity": "5.3"},
                            {"ids": ["D-1"], "max_severity": ""},
                            {"ids": ["E-1"], "max_severity": "8.1"},
                            {"ids": ["MAL-2026-1"], "max_severity": ""},
                        ],
                    }
                ],
            }
        ]
    }
    got = {f.ids[0]: f.severity for f in collect(report)}
    want = {
        "A-1": "CRITICAL",  # score
        "B-1": "HIGH",  # GHSA label, no score
        "C-1": "MEDIUM",  # score and MODERATE agree
        "D-1": "UNKNOWN",  # nothing to go on
        "E-1": "HIGH",  # score higher than the label
        "MAL-2026-1": "CRITICAL",  # malicious package
    }
    checks = [
        ("ratings", got == want),
        ("fixed versions above current", collect(report)[0].fixed == ["2.0.1"]),
        ("fails at high", evaluate(report, "HIGH")[0] == 1),
        ("only-medium passes at high", evaluate(_only(report, "C-1"), "HIGH")[0] == 0),
        ("only-medium fails at medium", evaluate(_only(report, "C-1"), "MEDIUM")[0] == 1),
        ("unknown passes at low", evaluate(_only(report, "D-1"), "LOW")[0] == 0),
        ("empty report passes", evaluate({"results": []}, "HIGH")[0] == 0),
        ("annotation escaping", "%2C" in _escape_prop("a,b") and "%0A" in _escape_data("a\nb")),
    ]
    for name, ok in checks:
        _say(f"{'ok  ' if ok else 'FAIL'} {name}")
    if got != want:
        _say(f"     got {got}")
    return 0 if all(ok for _, ok in checks) else 1


def _only(report: dict, vid: str) -> dict:
    pkg = dict(report["results"][0]["packages"][0])
    pkg["groups"] = [g for g in pkg["groups"] if g["ids"][0] == vid]
    return {"results": [{"source": report["results"][0]["source"], "packages": [pkg]}]}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Rate an osv-scanner JSON report and fail on HIGH/CRITICAL advisories."
    )
    parser.add_argument("report", nargs="?", help="osv-scanner --format json output file")
    parser.add_argument(
        "--fail-on",
        type=str.upper,
        choices=("CRITICAL", "HIGH", "MEDIUM", "LOW"),
        default="HIGH",
        help="lowest severity that fails (default: high)",
    )
    parser.add_argument("--self-test", action="store_true", help="check the rating logic, exit")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if not args.report:
        parser.error("the report path is required (or use --self-test)")
    try:
        report = json.loads(Path(args.report).read_text(encoding="utf-8"))
        if not isinstance(report, dict) or not isinstance(report.get("results", []), list):
            raise ValueError("not an osv-scanner JSON report")
    except (OSError, ValueError) as exc:
        _say(f"::error::cannot read {args.report}: {exc}")
        return 2

    github = os.environ.get("GITHUB_ACTIONS") == "true"
    code, lines = evaluate(report, args.fail_on, github=github)
    _say("\n".join(lines))
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with open(summary_path, "a", encoding="utf-8") as fh:
            fh.write(markdown(collect(report), args.fail_on))
    return code


if __name__ == "__main__":
    sys.exit(main())
