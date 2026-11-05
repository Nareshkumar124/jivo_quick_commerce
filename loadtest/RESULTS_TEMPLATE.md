# Load test results: <profile> on <environment>, <date>

Copy this file for each gate run and fill it in from `results/<run>/summary.md`. Attach it to the
Phase 8 gate (`docs/10-testing-strategy.md` §5).

## 1. Run

| Item | Value |
|---|---|
| Date and time (IST) | |
| Run by | |
| Target host | |
| Profile and options | e.g. `target`, `--riders 40` |
| Backend commit (`git rev-parse --short HEAD` on the deployed build) | |
| Load generator (machine, network path to the target) | |
| Result folder | `results/<UTC time>-<profile>/` |

## 2. Environment under test

| Item | Value |
|---|---|
| Web: instances × workers, CPU and RAM | |
| Celery worker / beat | |
| PostgreSQL: size, version, connection limit, pool settings (`POSTGRES_POOL_*`) | |
| Redis | |
| Settings changed for the run (`ORDERS_CREATE_RATE`, `PAYMENTS_RATE`, `OTP_TEST_NUMBERS`, `LOADTEST_DATA_ALLOWED`) | |
| Payment gateway (Razorpay test mode: ONLINE checkouts are abandoned) | |
| Data: store, stock floor, number of load-test customers and riders seeded | |

## 3. Thresholds (from `summary.md`)

| Check | Limit | Measured | Pass |
|---|---|---|---|
| Serviceability p95 | < 150 ms | | |
| Home p95 | < 300 ms | | |
| Catalog (categories, products, product page, search) p95, worst | < 300 ms | | |
| Cart read p95 | < 300 ms | | |
| Order placement p95 | < 800 ms | | |
| Other writes p95, worst | < 800 ms | | |
| Rider locations / heartbeat p95 | < 800 ms | | |
| Error rate, overall | ≤ 1% | | |
| Journeys aborted | 0 | | |
| Orders/min during the hold | ≥ 45 | | |
| Peak concurrent sessions reached | 500 | | |

**Exit code:** `0` / `1`. **Verdict:** PASS / FAIL.

## 4. Endpoint table

Paste the "Endpoints" table from `summary.md`.

## 5. Server-side observations

- CPU and memory of web and worker at peak:
- DB: active connections, slow queries (`pg_stat_statements` top 5), lock waits:
- Redis: memory, ops/s:
- Celery queue length during and after the run:
- Errors in Sentry or in the logs during the window:

## 6. Not covered by this run

- Offer delivery to the rider in < 3 s, rider location to the customer map in < 5 s, and the
  store new-order alert in < 3 s (09 §1). These are end-to-end timings over FCM and WebSocket,
  and the HTTP harness does not measure them.
- Paid ONLINE orders on staging. The Razorpay test checkout cannot be scripted, so ONLINE
  orders are created and then abandoned.
- Riders accepting offers and delivering. Riders stay idle by design, so no stock is committed.

## 7. Clean-up

| Step | Done |
|---|---|
| Celery queue drained | |
| `loadtest_cleanup` dry run reviewed | |
| `loadtest_cleanup --yes` (kept rows listed and resolved) | |
| Rate limits restored, `LOADTEST_DATA_ALLOWED=false` | |

## 8. Follow-ups

| Finding | Owner | Ticket |
|---|---|---|
| | | |
