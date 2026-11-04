# 05: Integration Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`.

| Integration | How tested | Result |
|---|---|---|
| API ↔ PostgreSQL (shared remote) | Every API test; read-only SQL cross-checks of the API's effects (OTP rows and supersede, token outstanding/blacklist, devices, addresses, terms consent, block flag) | ✅. OBS-01: intermittent DB connect timeouts (> 5 s) surface as 500. |
| API ↔ Redis (cache, rate limits) | Rate-limit counters observed in QA Redis DB 5 (hashed keys, TTLs); `config/app` cache | ✅ |
| Redis outage | `redis-down` profile: `config/app` from DB; OTP fail-closed 503; test numbers, me, refresh, logout and addresses keep working; `/health/ready` 503 | ✅ (4 passed) |
| API ↔ Celery broker / SMS | `send_otp_sms` is queued on commit to the QA broker (DB 7); with no worker, nothing is sent (by design for QA). Console backend masks the phone in its log line. | ⚠ Delivery not exercised (no worker, no real gateway: D-02). BUG-0005: production default backend. |
| API ↔ Django Admin (shared auth, Customers proxy) | Block/unblock through the admin action changes what the API allows (verify 403, refresh 401, access 401) | ✅ |
| Contract ↔ implementation | Served schema = committed `schema.yaml`; every response validated against it; schemathesis | ✅ except BUG-0004 |
| Contract ↔ generated Dart client (`packages/jivo_api`) | n/a (Flutter) | ⏭ No Flutter this run |
| Apps ↔ API (E2E login flow) | n/a | ⏭ The apps' `integration_test` suites were not re-run; device run pending |
| Production settings ↔ environment | `check --deploy` with production settings; production refuses `OTP_TEST_NUMBERS` | ✅ |

## Phase 3 stage 1 (2026-11-04, `c2c153a`)
| Integration | Result | Evidence |
|---|---|---|
| API → `compute_bill` → order snapshot (cart bill = order bill) | ✅ | P3-TC-20/21; SQL identities over all orders (P3-TC-48) |
| Placement → inventory reservation (`select_for_update`, variant-id order) under a 5-way race | ✅ | P3-TC-43: one 201, four 409, reserved ≤ on_hand |
| Verify ↔ webhook ↔ expiry job deciding a capture once (order-insensitive) | ✅ | P3-TC-36/38/52/53; SQL P3-TC-50 |
| :8001 Celery beat `expire_unpaid_orders` → T4 on an order placed through :8004 (same DB) | ✅ | Order 18: PAYMENT_FAILED at window end + 45 s, history actor `system` |
| `transaction.on_commit` → Celery `process_refund` / `order_event` (QA worker on broker DB 7, `--pool=solo`) | ✅ | 21 refunds processed, 0 errors, `amount_refunded` correct; events logged |
| FakeRazorpayGateway signature algorithm = Razorpay's (06 worked example) | ✅ | P3-TC-32 |
| Real Razorpay (test mode) | ⏭ | No keys on this host (D-05) |
| Customer app ↔ API (checkout, pay, retry, cancel) | ⬜ | Device run |

**Clock note:** row timestamps written by the app host run about 35 s ahead of the DB server's `now()`. This is harmless, because the expiry logic compares app-written timestamps only, but SQL checks must not mix `now()` with app timestamps.

## Phase 3 refund re-check (2026-11-04, `9ed7ffc`, T-310)
- **Webhook and Celery task ordering** (the integration this fix targets): P3-TC-65…69, run with a QA worker that the tests start themselves (DB 7), so the "webhook before the task records the id" race is reproduced deterministically:
  - no receipt: 503, then processed on retry
  - with a receipt: processed at once, and the task skips
  - another payment: ignored
  - `refund.failed`: stays FAILED
  - past the window: ignored

  All ✅.
- The :8001 beat (`expire_unpaid_orders`) and the QA instance share the DB: P3-TC-47 ✅ (`948.52s`).

## Phase 4 stage 1 (2026-11-04, `1b3552d`)
| Integration | Result | Evidence |
|---|---|---|
| Store service (driver) → shared DB → :8004 customer API (timeline, bill, refunds) | ✅ | TC-19/20/22 |
| Order refund → `process_refund` on the QA broker → fake gateway → `settle()` → customer `payment_status` | ✅ | 31 cleanup refunds + every P4 refund PROCESSED |
| `refund.failed` webhook (receipt match) → FAILED → ops retry → worker | ✅ | TC-34 |
| `sync_refund_status` + redelivered tasks → one gateway refund (advisory lock + receipt lookup) | ✅ | TC-35 |
| Domain events after commit → QA worker (`Order event order.accepted/cancelled: order <id>`, once each) | ✅ | TC-48 |
| Acceptance SLA alert once per order (Redis key) | ✅ | TC-37 (the :8001 beat sweep may alert first through its own Redis; accepted as `already`) |
| Ops Console → services | ⏭ | admin P4 not merged |

## Phase 4 stage 2 (2026-11-04, `f744508`)
| Integration | Result | Evidence |
|---|---|---|
| Ops Console → `order_actions` → `store_ops` services → customer API | ✅ | TC-19c/20c/22c |
| Refunds admin action + one-time token → `retry_refund` → worker | ✅ | TC-34c |
| PLACED event → `schedule_acceptance` → `auto_accept_order` (QA worker) on QA-02 | ✅ | TC-36 |
| Accepting switch → `set_accepting_orders` → serviceability | ✅ | TC-39 (QA-02) |
