# Jivo Quick Commerce load test (Phase 8, T-812)

A Locust harness that replays the customer and rider apps against a **staging** backend and
checks the `docs/09-nfr-security-compliance.md` §1 targets: 50 orders/min and 500 concurrent
app sessions, serviceability p95 < 150 ms, reads p95 < 300 ms and order placement p95 < 800 ms.
The CLI exits non-zero when a threshold is breached, so it can gate a release.

This is its own uv project (Python 3.13, `locust==2.47.0`), separate from `backend/uv.lock`.

```bash
cd loadtest
uv sync
uv run pytest                      # unit tests: flows against a fake API, safety, thresholds
uv run jivo-loadtest profiles      # what each profile does, and the thresholds
```

## Safety: where it may run

- `--host` is **required**. There is no default target.
- The host must be listed exactly in **`LOADTEST_ALLOWED_HOSTS`** (comma-separated `host` or
  `host:port`; a bare host means the scheme's default port). Without that variable, nothing runs.
- Loopback hosts on ports **8000, 8001 and 8004** are always refused, even when listed. :8001
  is the PM's develop server on the shared dev DB, and :8004 is QA's instance.
- Host names are normalised before any check:
  - lower case, with a trailing `.` removed (`localhost.:8001` is `localhost:8001`);
  - IPv4 shorthand rewritten through `inet_aton` (`127.1`, `2130706433` and `0x7f000001` are
    all `127.0.0.1`).
- A host *name* must resolve, and none of its addresses may be loopback. `localtest.me`,
  `*.nip.io` names pointing at 127.0.0.1 and similar are refused, and so is a name that does not
  resolve. For a throwaway local server, use the IP address itself (`127.0.0.1:8005`).
- The same checks run inside `locustfile.py`, so `locust -f locustfile.py ...` is refused too.
  The check happens before any user starts, and the exit code is 2.
- Distributed Locust (`--processes`, master/worker) is refused: each buyer and rider owns one
  phone number, which a single process guarantees.
- **Never point it at production or at the shared remote dev DB.** The backend's data commands
  refuse production on their own (see below), but the HTTP traffic does not know where it lands.

## Test data

| What | Range / tag | Created by | Removed by |
|---|---|---|---|
| Customers (buyers) | `+919000000200` to `+919000000299` (`+9190000002xx`), name `Loadtest 2xx`, address labelled `loadtest` | `manage.py loadtest_seed` | `manage.py loadtest_cleanup` |
| Riders | `+919000000300` to `+919000000399` (`+9190000003xx`), name `Loadtest 3xx`, ACTIVE bicycle riders with home store `--store` | `loadtest_seed --riders N --approver <staff email>` | `loadtest_cleanup` (ends an open shift, deletes the profile, KYC files and history) |
| Stock top-ups | ledger reason `loadtest: seed top-up` (INWARD) | `loadtest_seed --stock-floor N` | reversed by `loadtest_cleanup` (AUDIT_ADJUSTMENT, `loadtest: cleanup reversal`) |
| Orders, payments, refunds, OTP requests | belong to the load-test customers | the run | `loadtest_cleanup` |

**Only tagged accounts are touched.** A load-test account is in one of the two ranges *and* is
named exactly `Loadtest NNN` (its last three digits). Staff and superusers are never touched.
Neither is a customer-range account with a rider profile, or any account with another name.
Seeding refuses such an account. Cleanup leaves it and its orders alone, and lists it as "kept".

Both commands are **refused unless the backend has `LOADTEST_DATA_ALLOWED=true`**, and they are
always refused in production. Production settings also refuse to start with that variable set,
and the system check `loadtest.E001` catches it. Turn the variable on only while you prepare or
clean up a run.

`loadtest_cleanup` is a dry run unless you pass `--yes`. It cancels open load-test orders through
the normal order service (T5 / T11), which releases their stock reservations, then deletes the
orders with their payments and refunds, then the customers and their OTP requests, and finally
reverses the seed's stock top-ups. Anything it cannot remove safely is **kept and listed**, and
you can re-run it:
- an order whose refund is still in flight (wait for the Celery worker, then re-run);
- an order whose stock was committed (SALE ledger rows). The ledger is append-only.
- an order with an invoice, or any other protected row (for example a support ticket).

## Running on staging

1. **Backend settings** (staging env file, then restart web and worker):
   - **Razorpay test keys only**: an `rzp_test_...` `RAZORPAY_KEY_ID` with its test secret and
     test webhook secret. Never run a load test against live keys. Staging refuses the fake
     gateway (`payments.E001`), so ONLINE checkouts create real Razorpay test-mode orders.
   - `LOADTEST_DATA_ALLOWED=true`
   - `OTP_TEST_NUMBERS`: add the load-test numbers. Get them with
     `uv run jivo-loadtest otp-env --riders 40` (customers plus riders), or with
     `manage.py loadtest_seed --print-otp-env`, which keeps the numbers already configured.
     Fixed-OTP numbers send no SMS and skip the OTP send limits.
   - `ORDERS_CREATE_RATE=120/hour` and `PAYMENTS_RATE=240/hour` for the test window. The
     defaults (30 and 60 per user per hour) are exactly what 100 buyers need at 50 orders/min,
     so any jitter would show up as 429s. Restore them afterwards.
   - Check the P5 rider limits (location and heartbeat rates) against the rider cadence below.
2. **Seed** on the staging backend:
   ```bash
   uv run python manage.py loadtest_seed --store GGN-01 --stock-floor 5000 \
     --riders 40 --approver ops@jivo.test
   ```
   The riders are registered, given generated document images, fake numbers and bank details,
   and approved through the normal KYC services. `--approver` must be an active staff user who
   may review riders at the store (Ops, for example), and the KYC audit log names them. The
   document images go to the private bucket, and cleanup deletes them.
   It creates 100 customers with a default address at the store point. Pass `--lat/--lng` for
   another point; the command warns when that point is outside the store's area. It also tops
   every sellable stock row up to 5000 free units. The store must be **open** during the run.
3. **Smoke** (60 s, 10 sessions) to prove everything is wired:
   ```bash
   export LOADTEST_ALLOWED_HOSTS=staging-api.example.com
   uv run jivo-loadtest run --host https://staging-api.example.com --profile smoke
   ```
4. **The gate**: `--profile target` (about 20 minutes) and optionally `--profile ramp` (13 minutes,
   a step ramp that shows where latency starts to climb). Use `--dry-run` first to see the plan.
5. **Clean up**: wait for the Celery queue to drain, then run `manage.py loadtest_cleanup`, read
   the dry run, then `manage.py loadtest_cleanup --yes`. **Cleanup cancels open orders through
   the normal order service, so a paid ONLINE order is refunded.** With Razorpay test keys that
   is a test-mode refund. The harness never pays on staging, but a load-test order someone paid
   by hand would be refunded. Such orders stay "kept" until the refund settles, and a re-run then
   removes them. Restore the rate limits and set
   `LOADTEST_DATA_ALLOWED=false`.
6. **Report**: fill in `RESULTS_TEMPLATE.md` from the run folder, then attach it to the phase gate.

Each run writes `results/<UTC time>-<profile>/` (gitignored): `summary.md`, `summary.json` and
Locust's `report.html`.

## What the sessions do

| Session | Count (target) | Journey |
|---|---|---|
| Buyer | 100, one per customer phone | OTP login (once, with token refresh at 13 min), address, serviceability, home, categories, product list, product page, search suggest and search, clear the cart, add 1 to 3 items, change a quantity, set the address, read the bill, place the order with the cart's own `grand_total`, then pay, poll the order 3 times plus the active list, and cancel 30% of orders. One order per buyer every 120 s, so 50 orders/min in total. |
| Rider | 40, one per rider phone | OTP login (`app: rider`), `GET /rider/me/` (must be ACTIVE), shift start at the store point, then every server-given idle interval a GPS batch (one point per sample period, a small walk within about 500 m of the store), an offer poll, and a heartbeat about once a minute. Riders **never accept offers**, so load-test orders never reach pickup and no stock is committed. The shift ends when the session stops. |
| Browser | the rest (360) | Anonymous: app config, serviceability, home, categories, a product list, a product page and a search, every 5 to 15 s. |

Payments: 30% of checkouts are ONLINE. Against a server with the **fake gateway** (local and test
only), the flow signs and verifies the payment the way `docs/06` §2.6 describes. **Staging uses
Razorpay test mode, where the fake gateway is refused (payments.E001)**, and a script cannot pay
a real checkout. There, an ONLINE order is created, which exercises the Razorpay order call, and
then abandoned and cancelled (T5). It counts as `online: abandoned (real gateway)`, not as a
placed order. COD orders cover placement throughput.

Options: `--online-share`, `--cancel-share`, `--riders N` (0 to disable), `--lat/--lng`, `--otp`
and `--app-version`. Each also has a `LOADTEST_*` environment variable (see
`jivo_loadtest/config.py`).

### Riders

The rider journey uses the Phase 5 contract (`/rider/me/`, `/rider/shift/start/`,
`/rider/locations/`, `/rider/offers/current/`, `/rider/heartbeat/` and `/rider/shift/end/`). The
riders must be seeded ACTIVE (step 2) and listed in `OTP_TEST_NUMBERS`. A rider that is not ACTIVE
is recorded as a failed `rider shift` journey. Shift start checks the 2 km geofence around the
home store, so keep `--lat/--lng` near the store. Use `--riders 0` against a server without P5.

## Pass/fail thresholds

Defined in `jivo_loadtest/thresholds.py`. All of them are checked at the end of the run.

| Check | Limit | Source |
|---|---|---|
| `GET /serviceability/` p95 | 150 ms | 09 §1 |
| Every other GET (home, catalog, search, cart, orders, rider offers and profile) p95 | 300 ms | 09 §1, read endpoints (applied to every read) |
| `POST /orders/` p95 | 800 ms | 09 §1, order placement |
| Every other write (OTP, cart, verify, cancel, rider shift, locations, heartbeat) p95 | 800 ms | derived: held to the placement target |
| Error rate, overall and per endpoint | at most 1% | derived (09 §1 names no number) |
| Journeys that could not continue (`JOURNEY` rows: login, serviceability, checkout blocked, rider shift) | none | derived |
| Orders/min during the hold (`target` only) | at least 45 (90% of 50) | 09 §1 "without degradation" |

Exit codes: 0 means every threshold passed, 1 means at least one was breached (listed in the
output and in `summary.md`), and 2 means the run was refused before it started.

## Running a throwaway local server (smoke only)

Never point this harness at :8001 or at the shared dev DB. For a local smoke, run a separate
server on its own database and Redis DB. This is how T-812 was checked:

```bash
# 1. Create and migrate a separate test database (the backend's test settings only accept
#    test_jivo_quick_commerce*), pytest-style; pyproject's --reuse-db keeps it:
cd backend
POSTGRES_TEST_DB=test_jivo_quick_commerce_loadtest TEST_REDIS_DB=10 \
  uv run pytest apps/loadtest --create-db --no-cov -q
# 2. Point a local-settings server at it, with Redis DB 10 for cache, channels and broker:
export POSTGRES_DB=test_jivo_quick_commerce_loadtest REDIS_URL=redis://127.0.0.1:6380/10 \
  CHANNELS_REDIS_URL=redis://127.0.0.1:6380/10 CELERY_BROKER_URL=redis://127.0.0.1:6380/10 \
  LOADTEST_DATA_ALLOWED=true OTP_TEST_NUMBERS="$(cd ../loadtest && uv run jivo-loadtest otp-env --riders 3)"
uv run python manage.py seed_demo && uv run python manage.py loadtest_seed --store GGN-01 \n  --stock-floor 2000 --riders 3 --approver ops@jivo.test
uv run python manage.py runserver 127.0.0.1:8005 --noreload
# 3. In another shell:
cd loadtest && LOADTEST_ALLOWED_HOSTS=127.0.0.1:8005 \
  uv run jivo-loadtest run --host http://127.0.0.1:8005 --profile smoke
```

Latencies from such a run (single-process DEBUG `runserver`, remote DB at about 10 ms per query)
say nothing about staging capacity. They only prove that the flows work.
