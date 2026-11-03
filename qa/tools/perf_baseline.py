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
from qa_support import (  # noqa: E402
    instance_db,
    APP_HEADERS,
    BASE_URL,
    QA_PHONES,
    STORE_HEADERS,
    TEST_OTP,
    bearer,
    clear_catalog_cache,
    db_connect,
)

# Phase 2 read endpoints (09 §1: serviceability p95 < 150 ms; catalog reads p95 < 300 ms).
P2_PLANS = [
    ("GET /api/v1/serviceability/ (inside)", "/api/v1/serviceability/", {"params": {"lat": 28.471, "lng": 77.044}}),
    ("GET /api/v1/serviceability/ (outside)", "/api/v1/serviceability/", {"params": {"lat": 19.076, "lng": 72.8777}}),
    ("GET /api/v1/home/", "/api/v1/home/", {"headers": STORE_HEADERS}),
    ("GET /api/v1/categories/", "/api/v1/categories/", {"headers": STORE_HEADERS}),
    ("GET /api/v1/products/", "/api/v1/products/", {"headers": STORE_HEADERS}),
    ("GET /api/v1/products/?sort=price_asc&category=edible-oils", "/api/v1/products/", {"headers": STORE_HEADERS, "params": {"sort": "price_asc", "category": "edible-oils"}}),
    ("GET /api/v1/products/{slug}/", "/api/v1/products/jivo-cold-pressed-canola-oil/", {"headers": STORE_HEADERS}),
    ("GET /api/v1/search/?q=oil", "/api/v1/search/", {"headers": STORE_HEADERS, "params": {"q": "oil"}}),
    ("GET /api/v1/search/suggest/?q=can", "/api/v1/search/suggest/", {"headers": STORE_HEADERS, "params": {"q": "can"}}),
    ("GET /api/v1/collections/bestsellers/", "/api/v1/collections/bestsellers/", {"headers": STORE_HEADERS}),
]


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
    ap.add_argument("--p2-only", action="store_true", help="only the Phase 2 endpoints")
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
        # Phase 2: cold (catalog cache and store snapshot cleared before each call; builds from
        # the DB) and warm (served from the per-store Redis cache: no DB query when warm).
        for name, path, kw in P2_PLANS:
            cold, cold_st = [], []
            for _ in range(min(args.n, 10)):
                clear_catalog_cache()
                ms, st = timed(c, "GET", path, **kw)
                cold.append(ms)
                cold_st.append(st)
            results.append(summarise(f"COLD {name}", cold, cold_st))
            c.get(path, **kw)
            warm, warm_st = [], []
            for _ in range(args.n):
                ms, st = timed(c, "GET", path, **kw)
                warm.append(ms)
                warm_st.append(st)
            results.append(summarise(f"WARM {name}", warm, warm_st))
        if args.p2_only:
            plans = []
        else:
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
    def burst(name: str, method: str, path: str, warm: bool = False, **kw) -> dict:
        if warm:  # one request first, so the burst measures cache hits (not a stampede)
            with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=60) as cc:
                cc.request(method, path, **kw)

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
    results.append(burst("GET /api/v1/serviceability/ (warm)", "GET", "/api/v1/serviceability/", warm=True, params={"lat": 28.471, "lng": 77.044}))
    results.append(burst("GET /api/v1/home/ (warm)", "GET", "/api/v1/home/", warm=True, headers=STORE_HEADERS))
    results.append(burst("GET /api/v1/products/ (warm)", "GET", "/api/v1/products/", warm=True, headers=STORE_HEADERS))
    results.append(burst("GET /api/v1/search/?q=oil (warm)", "GET", "/api/v1/search/", warm=True, headers=STORE_HEADERS, params={"q": "oil"}))
    # Cold start: the cache was just invalidated and 20 requests arrive at once (cache stampede:
    # every request misses and rebuilds the body; there is no single-flight on a miss).
    for label, path, extra in [
        ("GET /api/v1/home/", "/api/v1/home/", {}),
        ("GET /api/v1/products/", "/api/v1/products/", {}),
        ("GET /api/v1/products/{slug}/", "/api/v1/products/jivo-cold-pressed-canola-oil/", {}),
    ]:
        clear_catalog_cache()
        results.append(burst(f"{label} (cold start, stampede)", "GET", path, headers=STORE_HEADERS, **extra))

    from qa_support import instance_commit, instance_db

    report = {
        "date": time.strftime("%Y-%m-%d %H:%M:%S %Z"),
        "commit": instance_commit(),
        "db": instance_db(),
        "base_url": BASE_URL,
        "db_connect_ms": {"p50": round(statistics.median(db_connect_ms), 1), "max": round(max(db_connect_ms), 1)},
        "db_select1_ms": {"p50": round(statistics.median(db_query_ms), 1), "max": round(max(db_query_ms), 1)},
        "results": results,
    }
    out = Path(__file__).resolve().parent.parent / "private" / "runs" / f"perf-{instance_db()}-{time.strftime('%H%M')}.json"
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
