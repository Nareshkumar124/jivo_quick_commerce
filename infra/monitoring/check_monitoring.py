#!/usr/bin/env python3
"""Validate the monitoring-as-code files (docs/deployment.md §10). Read-only; changes nothing.

Usage (needs PyYAML, which the backend environment has):

    uv run --project backend python infra/monitoring/check_monitoring.py
    uv run --project backend python infra/monitoring/check_monitoring.py --help

Checks:
- alerts.yml: every rule has alert, expr, for, labels.severity (page/ticket/ops), and
  annotations summary/description/runbook_url; alert names are unique.
- Every metric an alert expression uses is in metrics.yml (histogram ``_bucket``/``_sum``/
  ``_count`` series count as their histogram).
- Every runbook_url points at docs/deployment.md and its #anchor matches a heading there.
- Every metric in sql_exporter/*.collector.yml is in metrics.yml.

PromQL syntax itself is checked in CI by ``promtool check rules`` (pinned image).
Exit codes: 0 ok, 1 problems found, 2 usage error.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
MON = ROOT / "infra" / "monitoring"
DEPLOYMENT_MD = ROOT / "docs" / "deployment.md"
RUNBOOK_PREFIX = (
    "https://github.com/Nareshkumar124/jivo_quick_commerce/blob/main/docs/deployment.md#"
)
SEVERITIES = {"page", "ticket", "ops"}
METRIC_RE = re.compile(r"\b((?:jqc|celery|redis|pg|probe)_[a-z0-9_]+)\b")
HISTOGRAM_SUFFIXES = ("_bucket", "_sum", "_count")


def github_anchor(heading: str) -> str:
    """GitHub's heading slug: lowercase, drop punctuation except - and _, spaces to -."""
    text = unicodedata.normalize("NFKD", heading.strip().lower())
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors(markdown: Path) -> set[str]:
    out = set()
    for line in markdown.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^#{1,6}\s+(.*)$", line)
        if m:
            out.add(github_anchor(m.group(1)))
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.parse_args(argv)
    problems: list[str] = []

    catalog = yaml.safe_load((MON / "metrics.yml").read_text(encoding="utf-8"))["metrics"]
    names = {m["name"] for m in catalog}
    histograms = {m["name"] for m in catalog if m["type"] == "histogram"}
    for m in catalog:
        for key in ("name", "type", "labels", "source", "status", "description"):
            if key not in m:
                problems.append(f"metrics.yml: {m.get('name', '?')} has no {key}")

    def known(metric: str) -> bool:
        if metric in names:
            return True
        return any(
            metric.endswith(s) and metric.removesuffix(s) in histograms for s in HISTOGRAM_SUFFIXES
        )

    doc_anchors = anchors(DEPLOYMENT_MD)
    rules = yaml.safe_load((MON / "alerts.yml").read_text(encoding="utf-8"))
    seen: set[str] = set()
    count = 0
    for group in rules.get("groups", []):
        for rule in group.get("rules", []):
            count += 1
            name = rule.get("alert", "?")
            where = f"alerts.yml {group.get('name')}/{name}"
            if name in seen:
                problems.append(f"{where}: duplicate alert name")
            seen.add(name)
            for key in ("alert", "expr", "for"):
                if key not in rule:
                    problems.append(f"{where}: missing {key}")
            sev = (rule.get("labels") or {}).get("severity")
            if sev not in SEVERITIES:
                problems.append(f"{where}: severity {sev!r} not in {sorted(SEVERITIES)}")
            ann = rule.get("annotations") or {}
            for key in ("summary", "description", "runbook_url"):
                if not ann.get(key):
                    problems.append(f"{where}: missing annotations.{key}")
            url = ann.get("runbook_url", "")
            if url and not url.startswith(RUNBOOK_PREFIX):
                problems.append(f"{where}: runbook_url must start with {RUNBOOK_PREFIX}")
            elif url and url.removeprefix(RUNBOOK_PREFIX) not in doc_anchors:
                problems.append(f"{where}: no heading for #{url.removeprefix(RUNBOOK_PREFIX)}")
            for metric in METRIC_RE.findall(str(rule.get("expr", ""))):
                if not known(metric):
                    problems.append(f"{where}: metric {metric} is not in metrics.yml")

    for collector in sorted((MON / "sql_exporter").glob("*.collector.yml")):
        data = yaml.safe_load(collector.read_text(encoding="utf-8"))
        for m in data.get("metrics", []):
            if m["metric_name"] not in names:
                problems.append(f"{collector.name}: {m['metric_name']} is not in metrics.yml")
            if not re.match(r"^\s*select\b", m.get("query", ""), re.I):
                problems.append(f"{collector.name}: {m['metric_name']} query must be a SELECT")

    for p in problems:
        sys.stderr.write(f"ERROR: {p}\n")
    sys.stdout.write(
        f"check_monitoring: {count} alert rules, {len(names)} catalogued metrics, "
        f"{len(problems)} problem(s)\n"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
