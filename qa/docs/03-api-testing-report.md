# 03: API Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`, from a clean export · **Target:** QA instance `http://127.0.0.1:8004` · **Contract:** `backend/openapi/schema.yaml` @ `4960527` (17 operations).

## Commands
```bash
qa/tools/instance.sh start local 4960527
cd qa && uv run pytest -q -rfEsxX --deselect tests/test_fuzz_schemathesis.py
qa/tools/instance.sh start staging 4960527     # DEBUG off
QA_FORCE_ALL=1 uv run pytest -q --deselect tests/test_fuzz_schemathesis.py --deselect tests/test_p1_staff.py \
  -k "not tc04b and not tc10_api_docs_public and not tc11_served"
uv run pytest tests/test_fuzz_schemathesis.py   # local profile
```

## Results
| Run | Result (actual pytest summary) |
|---|---|
| Local profile, full suite (no fuzz) | `183 passed, 11 skipped, 13 deselected, 9 xfailed in 161.18s` |
| Local profile, final regression run (after the redaction fix) | `1 failed, 181 passed, 11 skipped, 13 deselected, 9 xfailed, 1 error in 207.81s`. The failure is P1-TC-57, an intermittent race: BUG-0007 (now xfail, non-strict). The error is P1-TC-48 setup, an httpx `ReadTimeout` while the remote DB timed out (OBS-01; passed in the two previous runs). |
| Staging profile (DEBUG off), profile-specific | `5 passed, 198 skipped` (P0-TC-01, 04, 10b; P1-TC-26c) |
| Staging profile, 🔥 smoke set | `20 passed, 1 error`. The error is P1-TC-64 admin login: Secure CSRF cookie over plain http, expected (admin is covered on local). |
| Staging profile, full API suite | `177 passed, 8 skipped, 22 deselected, 9 xfailed in 151.94s` |
| schemathesis (12 examples × 13 operations) | No app-caused 5xx. Findings: BUG-0004 (404 undocumented); local-only HTML 404 for non-integer ids (OBS-04). Every 500 reproduced as `psycopg ConnectionTimeout` against the remote DB (OBS-01) and returned 200/404/405 on manual retry. |

The 9 xfails are the open bugs: BUG-0001 ×1, BUG-0002 ×7, BUG-0003 ×1. Two of those guards (P1-TC-14b and P1-TC-24c) were then moved to the gitignored `qa/private/tests/`, because they are security-sensitive. P1-TC-57 is now an additional non-strict xfail for BUG-0007.

## Coverage per operation
| operationId | Cases | Status codes observed | Schema |
|---|---|---|---|
| `health_live` | P0-TC-01, 03 | 200, 405 | ✅ |
| `health_ready` | P0-TC-02, 03b | 200, 503 | ✅ |
| `auth_otp_request` | P1-TC-01…05, 14–20 | 200, 400, 415, 429, 503 | ✅ |
| `auth_otp_verify` | P1-TC-06…13, 17, 21–23 | 200, 400, 403, 429, 503, 500 (BUG-0001) | ✅ |
| `auth_token_refresh` | P1-TC-24…27 | 200, 400, 401 | ✅ |
| `auth_logout` | P1-TC-28…30 | 204, 400, 401 | ✅ |
| `me_retrieve` | P1-TC-33, 26, 31 | 200, 401 | ✅ strict |
| `me_update` | P1-TC-34…37 | 200, 400 | ✅ |
| `me_delete_account` | P1-TC-12, 42, 44 | 200, 400, 401 | ✅ |
| `me_device_register` | P1-TC-39…41 | 200, 400, 401 | ✅ |
| `config_app` | P1-TC-58, 59 | 200, 405, 406 | ✅ |
| `addresses_list` | P1-TC-48, 55, 73 | 200, 401, **404 (undocumented: BUG-0004)** | ✅ except 404 |
| `addresses_create` | P1-TC-47, 50–52, 56, 57 | 201, 400, 401 | ✅ |
| `addresses_retrieve` | P1-TC-49, 54, 55 | 200, 404, 401 | ✅ |
| `addresses_update` | P1-TC-49, 54, 55 | 200, 400, 404, 405 (PUT) | ✅ |
| `addresses_delete` | P1-TC-54, 55 | 204, 404 | ✅ |
| `addresses_set_default` | P1-TC-53…55, 57 | 200, 404 | ✅ (BUG-0007: a concurrent race returns a stale `is_default`) |

## Error envelope and codes (06 §6)
Every error response was checked for:
- the exact keys `{"error": {"code", "message", "details"}}`
- `details` an object
- `application/json`

| Code | Exercised by |
|---|---|
| `VALIDATION_ERROR` | ✅ field errors in `details`; malformed JSON |
| `OTP_INVALID`, `OTP_EXPIRED`, `OTP_RATE_LIMITED` | ✅ with `retry_after_seconds` and `Retry-After` |
| `AUTH_REQUIRED`, `TOKEN_INVALID` | ✅ |
| `PERMISSION_DENIED` | ✅ |
| `NOT_FOUND` | ✅ |
| `METHOD_NOT_ALLOWED`, `NOT_ACCEPTABLE`, `UNSUPPORTED_MEDIA_TYPE` | ✅ |
| `SERVICE_UNAVAILABLE` | ✅ |
| `SERVER_ERROR` | ✅ (no internals) |
| `APP_UPDATE_REQUIRED`, `MAINTENANCE` | ⏭ (shared `AppConfig`) |
| `RATE_LIMITED` | not used by any P1 endpoint (no generic DRF throttle configured) |

## Input validation summary
- **Covered:** missing fields, wrong types, enums, max lengths (every address field, name, email, `fcm_token`, reason, `terms_version`), regex fields, coordinates (range, NaN/Infinity/overflow strings, booleans), numeric strings, oversized bodies, Unicode digits.
- **Defects:** BUG-0001 (oversized body → 500) and BUG-0002 (non-ASCII numeric input). OBS-03: a boolean `lat` is coerced.


## Phase 3 stage 1 (2026-11-04)
**Build:** `qa/phase-2` at `c2c153a` (`git merge --no-ff develop`, clean; it contains Phase 3 backend R2b WIP and admin T-304 WIP). **Target:** QA instance `127.0.0.1:8004`, started by hand from the QA worktree on the Windows host. `instance.sh` needs Linux, so the same environment was set manually: `config.settings.local`, FakeRazorpayGateway, Redis 6380 DB 5/6/7, QA OTP numbers, shared remote DB. **Contract:** `backend/openapi/schema.yaml` @ `c2c153a`. Strict validation (`additionalProperties: false`) was applied to every P3 operation.

### Commands
```bash
# instance (bash, from .worktrees/qa/backend)
unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD
REDIS_URL=redis://localhost:6380/5 CHANNELS_REDIS_URL=redis://localhost:6380/6 CELERY_BROKER_URL=redis://localhost:6380/7 \
OTP_TEST_NUMBERS="+919000000101:123456,...105:123456" DJANGO_SETTINGS_MODULE=config.settings.local \
  uv run python manage.py runserver 127.0.0.1:8004 --noreload
cd qa
uv run pytest tests/test_p3_cart.py tests/test_p3_coupons.py tests/test_p3_orders.py tests/test_p3_payments.py \
  tests/test_p3_concurrency.py tests/test_p3_db.py -q -rfEsxX            # private/runs/p3-full-run2.txt
QA_SLOW=1 uv run pytest tests/test_p3_concurrency.py -k tc47              # T4 via the :8001 beat (~16 min)
uv run pytest -m smoke                                                    # P0-P3 smoke, private/runs/p3-smoke-run1.txt
# clock profile (store closed): QA_FAKE_NOW=2026-11-04T23:30:00+05:30 PYTHONPATH=qa/tools/clock, then
uv run pytest tests/test_p2_clock.py -k tc56
# refunds: a QA Celery worker on the QA broker only (DB 7), Windows needs --pool=solo
uv run celery -A config worker --pool=solo --without-heartbeat --without-mingle --without-gossip
```

### Results (actual pytest summaries)
| Run | Result |
|---|---|
| P3 full suite, run 1 | `3 failed, 55 passed, 2 skipped, 1 xfailed in 341.33s`. All 3 failures were **429 RATE_LIMITED** on QA user A: the suite itself placed more than 30 orders/hour (the limit is correct, P3-TC-46). Fixed in the QA fixtures, which now clear the QA throttle history per test (DB 5 only). |
| P3 full suite, run 2 (final) | `58 passed, 2 skipped, 1 xfailed in 603.13s` (skips: P3-TC-26 no data, P3-TC-47 slow; xfail: BUG-0009) |
| P3-TC-47 slow (QA_SLOW=1) | `1 failed, 1 error in 928.25s`: the 15-min access token expired while the test was polling (a test defect). The order was failed by the :8001 beat at the window end + 45 s, verified by SQL, and the remaining steps were run by script. All expectations held. The test is fixed. |
| Smoke set P0–P3 (except P3-TC-43, which was then running alone) | `72 passed, 1 skipped, 354 deselected in 316.38s` |
| P3-TC-43/44/45 after the fixture fix | `3 passed` |
| Clock profile P3-TC-56 | `1 passed` (and the P2 clock cases: `2 passed, 1 skipped`) |
| QA worker on DB 7 | 21 `process_refund` tasks: all `processed`, 0 errors. Every REFUNDED order has `amount_refunded = grand_total`. |

### Coverage per P3 operation
| operationId | Cases | Status codes observed | Schema |
|---|---|---|---|
| `cart_retrieve` | TC-01…03, 08, 09, 11 | 200, 400, 401, 404 | ✅ |
| `cart_update` | TC-07, 08 | 200, 400, 422 | ✅ |
| `cart_clear` | TC-07 | 200 | ✅ |
| `cart_items_add` | TC-04, 05, 06 | 200, 400, 401, 409, 422 | ✅ |
| `cart_items_update` / `cart_items_delete` | TC-04, 10 | 200, 400, 404 | ✅ |
| `cart_coupons_list` | TC-18, 19 | 200, 400, 401 | ✅ |
| `cart_coupon_apply` / `cart_coupon_remove` | TC-12…17, 55 | 200, 400, 401, 422 | ✅ |
| `orders_create` | TC-20…28, 43, 44, 46, 54, 56 | 200, 201, 400, 409, 422, 429 | ✅ |
| `orders_list` / `orders_retrieve` | TC-20, 29, 30 | 200, 400, 401, 404 | ✅ |
| `orders_cancel` | TC-21, 29, 31, 38, 53 | 200, 400, 404, 409 | ✅ |
| `orders_retry_payment` | TC-29, 39, 40 | 200, 400, 404, 409 | ✅ |
| `payments_razorpay_verify` | TC-29, 33, 34, 38, 39, 53 | 200, 400, 401, 404, 409 | ✅ |
| `payments_razorpay_webhook` | TC-35…38, 41, 42, 52, 57, 58 | 200, 400, **500 (BUG-0009)** | ✅ (except BUG-0009) |

Not observed: 503 `SERVICE_UNAVAILABLE` (gateway down, P3-TC-63 ⏭), 426/503 maintenance (shared AppConfig).

### Error codes exercised (06 §6)
`VALIDATION_ERROR`, `AUTH_REQUIRED`, `NOT_FOUND`, `STORE_NOT_FOUND`, `NOT_SERVICEABLE`, `STORE_CLOSED`, `STOCK_UNAVAILABLE`, `MAX_QTY_EXCEEDED`, `COUPON_INVALID`, `COUPON_NOT_ELIGIBLE` (MIN_ORDER_VALUE, NO_ELIGIBLE_ITEMS, FIRST_ORDER_ONLY), `COD_NOT_AVAILABLE` (ABOVE_LIMIT), `PRICE_CHANGED`, `PAYMENT_VERIFICATION_FAILED`, `INVALID_STATE_TRANSITION` ({status}, {pending_order_id}), `RATE_LIMITED`. Every one was checked against the exact envelope `{error: {code, message, details}}`. **Not yet exercised:** `MIN_ORDER_NOT_MET` as a placement error (no data), `COUPON_EXPIRED`, `COUPON_USAGE_EXCEEDED`, `SERVICE_UNAVAILABLE`.

### Demo data consumed on the shared dev DB (no destructive changes)
- QA users `+9190000001{01..05}` now own 87 orders: 0 PAYMENT_PENDING, the others CANCELLED, PAYMENT_FAILED or PLACED.
- Phase 3 has no T11/T12, so the PLACED ones still reserve demo stock:
  - variant 1 (Canola 1 L): 4 units (COD)
  - variant 2 (Canola 2 L): 1 unit
  - variant 13 (Sunflower 1 L): 16 units (paid ONLINE)
- Store GGN-01 still has variant 1 at 40/9 (`on_hand/reserved`; the 5 reserved before the run had no reservation rows), variant 13 at 40/16, and variant 6 (the oversell race item) at 2/0, unchanged.
- No demo coupon redemption remains HELD or APPLIED.
- These orders can be cancelled through T11/T12 when Phase 4 ships, or by Super Admin. All QA addresses were soft-deleted and all QA carts emptied.

## Phase 3 stage 2 (2026-11-04)
**Build:** `qa/phase-2` at `f84482f`, i.e. `develop` `a2b0762` merged in (clean merge). It contains the R2b review fixes (`41f02f6`: BUG-0009, OBS-P3-01, the `process_refund` locking), admin T-304 and Twilio SMS (T-308). The instance was started as in stage 1, plus **`SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend`**, so no real SMS can be sent: the instance log has 0 Twilio lines.

| Run | Result (actual pytest summary) |
|---|---|
| P3 full suite (stage-1 files) | `1 failed, 58 passed, 2 skipped in 598.75s`. The single failure is **XPASS(strict) of BUG-0009**, which is the cue that the fix landed; it was verified and the marker removed. Re-run: `1 passed`. |
| Admin + coupons + COD (`test_p3_admin.py`, new) and P3-TC-57 | `9 passed in 133.40s` (the first attempt had 1 test-logic error in P3-TC-61b: with both limits reached the server reports `total`; the test was reordered to check `per_user` first) |
| P3-TC-43 oversell race | `1 passed` |
| `QA_SLOW=1` P3-TC-47 (T4 via the :8001 beat + late capture) | `1 passed in 969.11s` |
| Smoke P0–P3 (now including P3-TC-59) | `73 passed, 1 skipped in 319.59s` |
| DB invariants (P3-TC-48…51), after the QA worker settled refunds | `4 passed` |
| QA Celery worker on broker DB 7 | 28/28 refunds `PROCESSED`; every REFUNDED order has `amount_refunded = grand_total` |

**Refund cases** (P3-TC-37/38/39/47/58 and worker settlement): they pass on this build. Per the PM, mark them **"re-check after the refund fix run"** (webhook race and idempotency lookup).

**Test-isolation note:** running `-m smoke` while `QA_SLOW` P3-TC-47 runs breaks P3-TC-47, because P1 smoke cases use QA user D too. Run the slow case alone.

**QA data added on the shared DB:**
- 47 more QA orders, 134 in total, none unpaid.
- PLACED QA orders reserve: variant 1 ×6, variant 2 ×1, variant 13 ×24.
- 7 hidden QA coupons `QAP3*`, all switched off.
- QA user E's `cod_blocked` was set and reset (0 users blocked now).
- The demo store's COD setting was never touched.

## Phase 3 refund re-check (T-310, 2026-11-04)
**Build:** `qa/phase-2` at `9ed7ffc` = `git merge --no-ff develop` (develop `dff62d5`: refund webhook receipt fallback, bounded 503 within `REFUND_WEBHOOK_RETRY_WINDOW_SECONDS`, lookup before every refund POST, FAILED never back to PENDING, `count=100`). **Target:** QA instance `127.0.0.1:8004`, started by hand from `.worktrees/qa/backend` (`config.settings.local`, `SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend`, Redis 6380 DB 5/6/7, QA OTP numbers, shared remote DB). QA Celery worker on DB 7 only (`--pool=solo`). Both stopped at the end; :8001 untouched.

### Commands
```bash
uv run pytest tests/test_p3_payments.py -q                         # private/runs/p3r-payments.txt
QA_SLOW=1 uv run pytest tests/test_p3_concurrency.py -k tc47 -q     # private/runs/p3r-tc47.txt (T4 via the :8001 beat)
# external worker stopped; these tests start and kill their own QA worker:
uv run pytest tests/test_p3_refunds.py -q                          # private/runs/p3r-refunds-run1.txt
# instance restarted with REFUND_WEBHOOK_RETRY_WINDOW_SECONDS=20 (profile marker refundwindow):
uv run pytest tests/test_p3_refunds.py -k tc69 -q                   # private/runs/p3r-refundwindow.txt
# instance back on local:
uv run pytest -m smoke -q                                           # private/runs/p3r-smoke.txt
uv run pytest tests/test_p4_*.py -q                                 # private/runs/p4-plan-run1.txt
```

### Results (actual pytest summaries)
| Run | Result |
|---|---|
| P3 payments (TC-32…42, 57, 58) with the QA worker | `13 passed in 134.58s` |
| P3-TC-47 slow | `1 passed, 7 deselected in 948.52s`; its late-capture refund PROCESSED, order REFUNDED, `amount_refunded = grand_total` |
| Refund settlement (SQL after the runs) | Every refund of the run PROCESSED with a gateway id (amount_mismatch, duplicate_capture, late_capture); late-capture orders REFUNDED once; 0 duplicate keys, 0 duplicate gateway ids, 0 payments refunded above their capture, 0 PENDING after draining (16 PROCESSED + 1 FAILED, the deliberate P3-TC-68) |
| New refund-ordering tests P3-TC-65…68 | `4 passed, 1 skipped in 128.85s` (the skip is TC-69, profile-only) |
| P3-TC-69 on the `refundwindow` profile | `1 passed in 63.09s`; the instance log has the "pending past the retry window: ignored" warning once |
| Smoke P0–P4 (🔥) | `77 passed, 13 skipped, 393 deselected in 408.76s` (skips: 12 P4 stubs awaiting R2, 1 staging-profile case) |
| P4 files on develop | `5 passed, 38 skipped in 35.17s` |
| Instance log | 0 × 500, 0 tracebacks |

**Observed:** a 503 carries the `SERVICE_UNAVAILABLE` envelope and leaves no `PaymentWebhookEvent` row, so the gateway's retry with the same event id is processed, not answered `duplicate`. New observation OBS-P3-05 (08): `amount_refunded` is capped at `grand_total` when an order had two separately refunded late captures.

## Phase 4 stage 1 (2026-11-04, T-416)
**Build:** `qa/phase-2` at `1b3552d` = `git merge --no-ff develop` (develop `74f47d1`: backend P4 R2 T-411/412 + customer P4 T-414; admin P4 **not** merged). **Target:** QA instance `127.0.0.1:8004` started by hand from `.worktrees/qa/backend` (`config.settings.local`, `SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend`, Redis 6380 DB 5/6/7, QA OTP numbers, shared remote DB with the 4 P4 migrations applied by the PM; `seed_demo` run by the PM). QA Celery worker on DB 7 only (`--pool=solo`), no QA beat (the :8001 beat serves the shared DB). Both stopped at the end; :8001 untouched. **Date:** 2026-11-04.

**Store and ops actions** (T6/T7/T8/T8a/T12, manual refund, retry, `sync_refund_status`, SLA alert) were driven through the **backend services** (`apps.orders.store_ops`, `apps.payments.order_refunds`) by `qa/tools/store_ops_driver.py`, run in the QA worktree backend with the QA environment, as the seeded staff users, because the Ops Console (admin P4) is not merged. The driver refuses any order that is not a QA customer's. Console pages, HTMX, CSRF and hidden-button checks stay ⏭.

### Commands
```bash
cd qa
uv run pytest tests/test_p4_orders.py -q -rfEsxX          # private/runs/p4s1-orders-run1.txt, run2 (fixes), p4s1-tc12b.txt
uv run pytest tests/test_p4_store_ops.py -q -rfEsxX       # private/runs/p4s1-storeops-run1.txt
uv run pytest tests/test_p4_refund_worker.py -q           # stops/starts the QA worker; p4s1-refundworker-run2.txt
uv run pytest tests/test_p4_carryover.py tests/test_p4_db.py tests/test_p3_db.py
# profiles (environment only): FAKE_GATEWAY_DOWN=True -> p4s1-gwdown.txt ; CUSTOMER_CANCEL_UNTIL=PLACED -> p4s1-cancelplaced.txt
uv run pytest -m smoke                                    # p4s1-smoke-run2.txt
```

### Results (actual pytest summaries)
| Run | Result |
|---|---|
| P4 customer API, run 1 | `3 failed, 16 passed, 2 skipped in 298.51s`: all 3 were QA test defects (cart line shape `variant.id`; the driver's error mapping). Fixed |
| Re-run of the 3 | `3 passed in 86.63s`; TC-09 race outcomes `['cancelled', 'packing', 'packing']` |
| TC-12b (OUT_OF_STOCK / LIMITED_STOCK) | `1 passed in 37.58s` |
| P4 store ops | `1 failed, 20 passed, 6 skipped in 783.72s`: TC-26 expected `REDEEMED`, which is not a state (07: APPLIED). QA wording error; corrected, `1 passed` |
| Refund worker (TC-34/35) | run 1: 2 failed (the QA worker-stop helper did not find the process; fixed) · run 2 `2 passed in 107.38s` |
| `gwdown` profile (TC-50) | `2 passed, 1 skipped`: ONLINE placement 503 `SERVICE_UNAVAILABLE`, nothing created; COD 201; retry-payment 503; verify 503 and the order stays `PAYMENT_PENDING` |
| `cancelplaced` profile (TC-10) | `1 passed in 38.94s` |
| TC-49 (₹45 sachet) | passed: 422 `MIN_ORDER_NOT_MET`, COD and ONLINE, nothing created |
| SQL (P3 + P4 db) | `8 passed in 11.52s` (final, after cleanup) |

Invoice: `GET /orders/{id}/invoice/` is 409 `INVALID_STATE_TRANSITION {status}` before DELIVERED (TC-15 ✅) and 404 for another user (TC-14 ✅). The 503 for the missing WeasyPrint libraries on this host is only reachable for a DELIVERED order: not exercised (no QA DELIVERED order before P5; the seeded DELIVERED order belongs to the user's test account and was not touched).

Every P4 response was validated strictly against `schema.yaml` @ `1b3552d` (`orders_retrieve`, `orders_cancel`, `orders_list`, `orders_reorder`): no contract drift.
