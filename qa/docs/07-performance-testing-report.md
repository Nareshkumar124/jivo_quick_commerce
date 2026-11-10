# 07: Performance Testing Report

**Date:** 2026-11-02 16:21 IST (QA run 1) · **Build:** backend `4960527` · **Target:** QA instance `127.0.0.1:8004`:
- `runserver` (daphne, single process, `--noreload`), local settings
- shared **remote** PostgreSQL 16
- Redis 6380 DB 5

**Command:** `cd qa && uv run python tools/perf_baseline.py` (30 sequential calls per endpoint, plus bursts of 20 concurrent). Raw data: `qa/private/runs/perf-1621.json`.

> **Caveats.**
> - This is a development-server baseline, not load testing. Real load (Locust, 50 orders/min, 500 sessions, 09 §1) is Phase 8 on staging.
> - Timings are dominated by the **remote-DB network**. `CONN_MAX_AGE=0` opens a new DB connection on every request: connect p50 **98.9 ms** (max 345.8 ms), plus `SELECT 1` p50 **20.7 ms** per round trip from this host.

## Sequential (n = 30 each)
| Endpoint | p50 ms | p95 ms | max ms | 5xx | Statuses |
|---|---|---|---|---|---|
| GET /health/live | 4.7 | 15.0 | 15.4 | 0 | 200 |
| GET /health/ready | 140.9 | 1151.7 | 1224.7 | 0 | 200 |
| GET /api/v1/config/app/ | 11.7 | 32.8 | 80.6 | 0 | 200 |
| GET /api/v1/me/ | 136.4 | 280.7 | 468.2 | 0 | 200 |
| GET /api/v1/addresses/ | 143.9 | 218.7 | 5014.2 | **1** | 200, 500 |
| PATCH /api/v1/me/ | 168.3 | 215.4 | 217.4 | 0 | 200 |
| POST /auth/otp/request/ (test no.) | 168.5 | 181.5 | 187.1 | 0 | 200 |
| POST /auth/otp/verify/ (test no.) | 223.5 | 305.8 | 800.5 | 0 | 200 |
| POST /auth/token/refresh/ | 264.9 | 292.7 | 302.2 | 0 | 200 |
| POST /api/v1/addresses/ | 195.8 | 230.7 | 230.9 | 0 | 201 |
| DELETE /api/v1/addresses/{id}/ | 220.1 | 245.0 | 260.4 | 0 | 204 |

## Concurrency bursts (20 in flight)
| Burst | p50 ms | p95 ms | wall ms | 5xx |
|---|---|---|---|---|
| GET /config/app/ ×20 | 105.5 | 118.7 | 179.5 | 0 |
| GET /me/ ×20 | 209.1 | 253.0 | 309.3 | 0 |
| GET /addresses/ ×20 | 243.7 | 276.8 | 316.7 | 0 |

Earlier functional concurrency checks:
- 8 parallel address creates for an address-less user leave exactly one default (P1-TC-57). 10 parallel set-default calls sometimes leave **zero** defaults: BUG-0007, 1 of 8 trials.
- Token refresh under concurrency: see BUG-0003 (details private).

## Assessment against 09 §1
- **Read endpoints:** `me` and `addresses` have p95 of 219–281 ms, inside the p95 < 300 ms target, even with the remote DB and a new connection per request. `config/app` is served from cache (p95 33 ms).
- **`health/ready` p95 of 1.15 s:** it opens a fresh DB connection and a fresh Redis client on every probe. Acceptable for a probe, but load-balancer probe timeouts should allow for it.
- **One 500 in 330 requests** (GET /addresses/, 5014 ms): the DB connect hit its 5 s `connect_timeout` (`psycopg.errors.ConnectionTimeout`). The same symptom appeared 5 times during fuzzing and once on a readiness probe (OBS-01). This is environmental, but it shows the risk of no connection pooling against a remote DB.
  - **Recommendation (backend/ops):** pooling (pgbouncer or `CONN_MAX_AGE` > 0 with `CONN_HEALTH_CHECKS`) for staging and production.
  - **Re-measure on staging.**
- Query-count assertions (`django_assert_max_num_queries`) are a backend-suite concern from Phase 2 and are not measured here.

## Phase 3 stage 1 (2026-11-04)
No dedicated P3 latency baseline yet: re-run `tools/perf_baseline.py` with the P3 operations after the R2b merge. Observed while running the suites (remote shared DB, OBS-01 applies):
- the slowest server-side timings in the instance log: placement 0.3–0.6 s, verify about 0.5 s, webhook about 0.3–0.5 s
- 5-way and 6-way parallel bursts (P3-TC-43/44/52) completed without 5xx, deadlock or lock timeout

Real load (50 orders/min) belongs to Phase 8.

## Phase 4 stage 1 (2026-11-04)
Not measured: the P4 load-relevant paths are the console polls (TC-60), which are not merged. For reference only: a store action through the QA driver takes ~3 s, almost all of it Django start-up per process against the remote DB (~10 ms/query). That is not representative of the console.

## Phase 4 stage 2 (2026-11-04, `f744508`)
P4-TC-60, 20 sequential HTMX polls each against :8004 (remote DB): live-board columns (Ops) p50 253 ms, p95 278 ms; packing queues (Store Staff, GGN-01) p50 264 ms, p95 310 ms. Within the 10 s poll budget; not representative of production (remote DB, `runserver`). The fixed-query-count check is white-box (admin tests).

## QA stage 3 (2026-11-10, `efb3c3d`): real-time latency on the local stack
Not a load test (09 §1 load belongs to Phase 8 on staging). Findings while running P6:
- **OBS-S3-01:** `redis://localhost:6380` costs **2.04 s** per new connection on this Windows host (IPv6 `::1` tried first; Redis listens on IPv4 only); `127.0.0.1` costs 0.001 s. Before the switch each `publish_*` / `broadcast_ws` task took ~2–8 s; after, 0.14–0.2 s.
- **OBS-S3-02:** with 4 worker threads, `PREFETCH_MULTIPLIER=1` and `ACKS_LATE`, tasks reached the Windows worker in ~4 s bursts (cancel response → task received 5.8 s), while a raw broker probe takes 1–2 ms. With 16 threads: P6-TC-11 cancel → `order.status` on the socket within 3 s ✅; offer.new within 3 s of `offered_at` ✅ (P6-TC-21).
- These are local-environment effects. Measure the 09 §1 targets (offer < 3 s, store alert < 3 s, location → map < 5 s) on staging (prefork workers, Linux).
