"""The run summary: `summary.json` (machine-readable) and `summary.md` (the results template with
the measured numbers filled in; a person adds the environment notes and the verdict)."""

import json
from dataclasses import asdict
from datetime import UTC, datetime
from pathlib import Path

from jivo_loadtest.profiles import Profile
from jivo_loadtest.thresholds import Breach, EndpointResult, p95_limit


def build(
    *,
    host: str,
    profile: Profile,
    results: list[EndpointResult],
    breaches: list[Breach],
    orders_per_min: float,
    outcomes: dict[str, int],
    run_seconds: float,
) -> dict:
    total = sum(r.requests for r in results)
    failures = sum(r.failures for r in results)
    return {
        "generated_at": datetime.now(UTC).isoformat(timespec="seconds"),
        "host": host,
        "profile": profile.name,
        "profile_description": profile.description,
        "peak_sessions": profile.peak_users,
        "buyers": profile.buyers,
        "riders": profile.riders,
        "target_orders_per_min": profile.orders_per_min,
        "min_orders_per_min": profile.min_orders_per_min,
        "measured_orders_per_min": round(orders_per_min, 2),
        "measured_from_s": profile.measure_from_s,
        "run_seconds": round(run_seconds, 1),
        "requests": total,
        "failures": failures,
        "error_rate": round(failures / total, 5) if total else None,
        "passed": not breaches,
        "breaches": [str(b) for b in breaches],
        "outcomes": dict(sorted(outcomes.items())),
        "endpoints": [
            {**asdict(r), "p95_limit_ms": p95_limit(r.method, r.name)[0]}
            for r in sorted(results, key=lambda r: (r.name, r.method))
        ],
    }


def render_markdown(summary: dict) -> str:
    verdict = "PASS" if summary["passed"] else "FAIL"
    lines = [
        f"# Load test results: {summary['profile']} on {summary['host']}",
        "",
        f"- Generated: {summary['generated_at']} (UTC)",
        f"- Profile: `{summary['profile']}`: {summary['profile_description']}",
        f"- Peak sessions: {summary['peak_sessions']} ({summary['buyers']} buyers, "
        f"{summary['riders']} riders, the rest anonymous browsers)",
        f"- Run time: {summary['run_seconds']} s",
        f"- Requests: {summary['requests']}, failures: {summary['failures']} "
        f"(error rate {summary['error_rate']:.2%})"
        if summary["error_rate"] is not None
        else "- Requests: 0",
        f"- Orders/min from {summary['measured_from_s']} s: "
        f"{summary['measured_orders_per_min']} (target {summary['target_orders_per_min']}"
        + (
            f", must reach {summary['min_orders_per_min']:.1f})"
            if summary["min_orders_per_min"]
            else ", not gated in this profile)"
        ),
        f"- **Thresholds: {verdict}**",
        "",
        "## Breached thresholds",
        "",
    ]
    lines += [f"- {b}" for b in summary["breaches"]] or ["- none"]
    lines += [
        "",
        "## Endpoints",
        "",
        "| Method | Endpoint | Requests | Failures | p95 (ms) | Limit (ms) | OK |",
        "|---|---|---:|---:|---:|---:|---|",
    ]
    for e in summary["endpoints"]:
        http = e["method"] in {"GET", "POST", "PATCH", "PUT", "DELETE"}
        ok = (
            e["p95_ms"] <= e["p95_limit_ms"]
            and (not e["requests"] or e["failures"] / e["requests"] <= 0.01)
            if http
            else e["failures"] == 0
        )
        limit = e["p95_limit_ms"] if http else "-"
        lines.append(
            f"| {e['method']} | `{e['name']}` | {e['requests']} | {e['failures']} | "
            f"{e['p95_ms']:.0f} | {limit} | {'yes' if ok else 'NO'} |"
        )
    lines += ["", "## Journey outcomes", "", "| Outcome | Count |", "|---|---:|"]
    lines += [f"| {name} | {count} |" for name, count in summary["outcomes"].items()]
    lines += [
        "",
        "## To fill in (see RESULTS_TEMPLATE.md)",
        "",
        "- Environment (backend commit, instance sizes, workers, DB, Redis): TODO",
        "- Server-side observations (CPU, DB connections, slow queries, Celery queue): TODO",
        "- Verdict and follow-ups: TODO",
        "",
    ]
    return "\n".join(lines)


def write(summary: dict, directory: Path) -> tuple[Path, Path]:
    directory.mkdir(parents=True, exist_ok=True)
    json_path, md_path = directory / "summary.json", directory / "summary.md"
    json_path.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    md_path.write_text(render_markdown(summary), encoding="utf-8")
    return json_path, md_path
