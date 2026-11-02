"""Light performance baseline against the QA instance (never 8001): ~30 sequential calls per
main endpoint (p50/p95/max) and short concurrency bursts of <= 20 requests. Also measures the
remote-DB connect + SELECT 1 latency, which dominates local timings (CONN_MAX_AGE=0 opens a new
DB connection per request).

    cd qa && uv run python tools/perf_baseline.py [--n 30] [--burst 20]
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tests"))
from conftest import ADDRESS, TERMS_VERSION, login  # noqa: E402
from qa_support import APP_HEADERS, BASE_URL, QA_PHONES, TEST_OTP, bearer, db_connect  # noqa: E402


def pct(values: list[float], p: float) -> float:
    ordered = sorted(values)
    k = max(0, min(len(ordered) - 1, round(p / 100 * len(ordered) + 0.5) - 1))
    return ordered[k]


def summarise(name: str, samples: list[float], statuses: list[int]) -> dict:
    return {
        "endpoint": name,
        "n": len(samples),
        "p50_ms": round(statistics.median(samples), 1),
        "p95_ms": round(pct(samples, 95), 1),
        "max_ms": round(max(samples), 1),
        "errors": sum(1 for s in statuses if s >= 500),
        "statuses": sorted(set(statuses)),
    }


def timed(c: httpx.Client, method: str, path: str, **kw) -> tuple[float, int]:
    t0 = time.perf_counter()
    r = c.request(method, path, **kw)
    return (time.perf_counter() - t0) * 1000, r.status_code


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=30)
    ap.add_argument("--burst", type=int, default=20)
    args = ap.parse_args()
    assert args.burst <= 20, "keep bursts <= 20 (shared DB)"

    # Remote DB latency (connect + SELECT 1), host -> shared PostgreSQL.
    db_connect_ms, db_query_ms = [], []
    for _ in range(10):
        t0 = time.perf_counter()
        conn = db_connect()
        t1 = time.perf_counter()
        with conn.cursor() as cur:
            cur.execute("select 1")
            cur.fetchone()
        t2 = time.perf_counter()
        conn.close()
        db_connect_ms.append((t1 - t0) * 1000)
        db_query_ms.append((t2 - t1) * 1000)

    s = login(QA_PHONES["d"])
    auth = {**APP_HEADERS, **bearer(s.access)}
    results = []
    with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=60) as c:
        c.get("/health/live")  # warm-up
        plans = [
            ("GET /health/live", "GET", "/health/live", {}),
            ("GET /health/ready", "GET", "/health/ready", {}),
            ("GET /api/v1/config/app/", "GET", "/api/v1/config/app/", {}),
            ("GET /api/v1/me/", "GET", "/api/v1/me/", {"headers": auth}),
            ("GET /api/v1/addresses/", "GET", "/api/v1/addresses/", {"headers": auth}),
            ("PATCH /api/v1/me/", "PATCH", "/api/v1/me/", {"headers": auth, "json": {"marketing_opt_in": False}}),
            (
                "POST /api/v1/auth/otp/request/ (test no.)",
                "POST",
                "/api/v1/auth/otp/request/",
                {"json": {"phone": QA_PHONES["d"], "app": "customer"}},
            ),
        ]
        for name, method, path, kw in plans:
            samples, statuses = [], []
            for _ in range(args.n):
                ms, st = timed(c, method, path, **kw)
                samples.append(ms)
                statuses.append(st)
            results.append(summarise(name, samples, statuses))

        # OTP verify + token refresh (each needs fresh state).
        v_samples, v_status, r_samples, r_status = [], [], [], []
        for _ in range(args.n):
            c.post("/api/v1/auth/otp/request/", json={"phone": QA_PHONES["d"], "app": "customer"})
            ms, st = timed(
                c,
                "POST",
                "/api/v1/auth/otp/verify/",
                json={"phone": QA_PHONES["d"], "otp": TEST_OTP, "app": "customer", "terms_version": TERMS_VERSION},
            )
            v_samples.append(ms)
            v_status.append(st)
        refresh = s.refresh
        for _ in range(args.n):
            t0 = time.perf_counter()
            r = c.post("/api/v1/auth/token/refresh/", json={"refresh": refresh})
            r_samples.append((time.perf_counter() - t0) * 1000)
            r_status.append(r.status_code)
            if r.status_code == 200:
                refresh = r.json()["refresh"]
        results.append(summarise("POST /api/v1/auth/otp/verify/ (test no.)", v_samples, v_status))
        results.append(summarise("POST /api/v1/auth/token/refresh/", r_samples, r_status))

        # Address create + delete.
        c_samples, c_status, ids = [], [], []
        for i in range(args.n):
            t0 = time.perf_counter()
            r = c.post("/api/v1/addresses/", json={**ADDRESS, "house": f"QA perf {i}"}, headers=auth)
            c_samples.append((time.perf_counter() - t0) * 1000)
            c_status.append(r.status_code)
            if r.status_code == 201:
                ids.append(r.json()["id"])
        results.append(summarise("POST /api/v1/addresses/", c_samples, c_status))
        d_samples, d_status = [], []
        for address_id in ids:
            ms, st = timed(c, "DELETE", f"/api/v1/addresses/{address_id}/", headers=auth)
            d_samples.append(ms)
            d_status.append(st)
        if d_samples:
            results.append(summarise("DELETE /api/v1/addresses/{id}/", d_samples, d_status))

    # Concurrency bursts (<= 20 in flight).
    def burst(name: str, method: str, path: str, **kw) -> dict:
        def one(_):
            with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=60) as cc:
                return timed(cc, method, path, **kw)

        t0 = time.perf_counter()
        with ThreadPoolExecutor(args.burst) as pool:
            out = list(pool.map(one, range(args.burst)))
        wall = (time.perf_counter() - t0) * 1000
        res = summarise(f"BURST x{args.burst} {name}", [o[0] for o in out], [o[1] for o in out])
        res["wall_ms"] = round(wall, 1)
        return res

    results.append(burst("GET /api/v1/config/app/", "GET", "/api/v1/config/app/"))
    results.append(burst("GET /api/v1/me/", "GET", "/api/v1/me/", headers=auth))
    results.append(burst("GET /api/v1/addresses/", "GET", "/api/v1/addresses/", headers=auth))

    report = {
        "date": time.strftime("%Y-%m-%d %H:%M:%S %Z"),
        "base_url": BASE_URL,
        "db_connect_ms": {"p50": round(statistics.median(db_connect_ms), 1), "max": round(max(db_connect_ms), 1)},
        "db_select1_ms": {"p50": round(statistics.median(db_query_ms), 1), "max": round(max(db_query_ms), 1)},
        "results": results,
    }
    out = Path(__file__).resolve().parent.parent / "private" / "runs" / f"perf-{time.strftime('%H%M')}.json"
    out.write_text(json.dumps(report, indent=2))
    print(json.dumps(report["db_connect_ms"]), json.dumps(report["db_select1_ms"]))
    print(f"{'endpoint':52} {'n':>3} {'p50':>7} {'p95':>7} {'max':>7} 5xx statuses")
    for r in results:
        print(
            f"{r['endpoint']:52} {r['n']:>3} {r['p50_ms']:>7} {r['p95_ms']:>7} {r['max_ms']:>7} "
            f"{r['errors']:>3} {r['statuses']}" + (f" wall={r['wall_ms']}" if "wall_ms" in r else "")
        )
    print(f"saved {out}")


if __name__ == "__main__":
    main()
