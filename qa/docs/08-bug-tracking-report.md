# 08: Bug Tracking Report

**Updated:** 2026-11-04 (Phase 3 QA stage 1). **Builds:** backend `4960527` (run 1), `0b801d1` (run 2: BUG-0008), `c2c153a` (P3 stage 1: BUG-0009).

Severity uses `docs/10-testing-strategy.md` §5.3, with the brief's equivalent in brackets: P0 Blocker = Critical · P1 Critical = High · P2 Major = Medium · P3/P4 = Low. Security bugs keep their exploit detail in `qa/private/` (gitignored) until fixed.

| ID | Title | Module | Severity | Priority | Owner agent | Status | Test / case |
|---|---|---|---|---|---|---|---|
| [BUG-0001](../bugs/BUG-0001.md) | Request body over 2.5 MB returns 500 SERVER_ERROR instead of a 4xx | backend: core error envelope | P3 Minor (Low) | P2 | django-backend-dev | Verified (run 2, `0b801d1`) | P0-TC-08b |
| [BUG-0002](../bugs/BUG-0002.md) | Numeric input validators accept non-ASCII characters (data integrity; security aspect private) | backend: accounts validators | P2 Major (Medium) | P1 | django-backend-dev | Verified (run 2, `0b801d1`) | P1-TC-04, 13, 14b, 52 |
| [BUG-0003](../bugs/BUG-0003.md) | The refresh-token single-use rule is not enforced in all conditions (security; details private) | backend: token refresh | P2 Major (Medium) | P2 | django-backend-dev | Verified (run 2, `0b801d1`) | P1-TC-24c |
| [BUG-0007](../bugs/BUG-0007.md) | Concurrent set-default calls can leave a user with no default address (all return 200 `is_default: true`) | backend: addresses service | P2 Major (Medium) | P3 | django-backend-dev | Verified (run 2, `0b801d1`) | P1-TC-57 |
| [BUG-0008](../bugs/BUG-0008.md) | An anonymous notify-me repeat returns data from an earlier lead (privacy; details private) | backend: serviceability notify-me | P3 Minor (Low) | P2 | django-backend-dev | Open (status as filed in run 2; not re-verified in P3 stage 1) | P2-TC-18 |
| [BUG-0009](../bugs/BUG-0009.md) | A signed webhook with an over-long payment id returns 500 instead of `ignored` (refund key overflow too) | backend: payments webhook | P3 Minor (Low) | P3 | django-backend-dev | Verified (stage 2, `f84482f`, fix `41f02f6`) | P3-TC-57 |
| [BUG-0004](../bugs/BUG-0004.md) | `addresses_list` returns 404 for an invalid page, but the contract doesn't document it | backend: OpenAPI contract | P3 Minor (Low) | P3 | django-backend-dev | Verified (run 2, `0b801d1`) | P1-TC-48, P1-TC-79 |
| [BUG-0005](../bugs/BUG-0005.md) | Production settings silently default to the console SMS backend, which logs OTP codes | backend: settings / checks | P3 Minor (Low) | P2 | django-backend-dev | Verified (run 2, `0b801d1`) | P1-TC-96 |
| [BUG-0006](../bugs/BUG-0006.md) | Staff session lasts a fixed 12 hours; the doc requires 8 hours, and 2 hours idle for admin roles | backend: settings (staff sessions) | P3 Minor (Low) | P3 | django-backend-dev | Open | P1-TC-95 |

**Open by severity (2026-11-04):** P0: 0 · P1: 0 · P2: 0 · P3: 2 (BUG-0006, BUG-0008; BUG-0008's residual fix landed in `41f02f6` but has not been re-verified by QA yet) · P4: 0. The statuses were synced with the bug files: run 2 verified BUG-0001…0005 and BUG-0007. Phase 3 stage 1 added BUG-0009, and stage 2 verified it.

Verified fixes: none yet (first run).

## Observations / to investigate (not filed as bugs)
| ID | Observation | Why not a bug / next step |
|---|---|---|
| OBS-01 | The remote shared PostgreSQL sometimes takes longer than the 5 s `connect_timeout` to accept a connection. Those requests return 500 `SERVER_ERROR` with `psycopg ConnectionTimeout` in the log: 5 of ~300 fuzz requests, 1 of ~330 perf requests, and 1 readiness probe. `CONN_MAX_AGE=0` opens a new DB connection on every request (connect p50 ≈ 99 ms, max 346 ms from this host). | An environmental risk of the shared remote DB, not P1 code. Recommendation for the backend and ops: connection pooling (pgbouncer, or `CONN_MAX_AGE` > 0 with health checks) on staging/production; consider 503 rather than 500 for DB-unavailable errors. Recheck on staging. |
| OBS-02 | An access token stays valid for up to 15 minutes after logout. | Matches 06 §2.1: logout only promises refresh revocation. A deleted or blocked account's access token *is* refused (verified). |
| OBS-03 | A JSON boolean `true` for `lat` is accepted as 1.0 (DRF `FloatField` coercion). | P4 type-strictness only; schema type is number. |
| OBS-04 | With `DEBUG=True` (local), unmatched `/api/` URLs and non-integer path ids return Django's HTML debug 404 instead of the JSON envelope. | By design: the doc says DEBUG off. Verified JSON with DEBUG off (staging profile, P0-TC-04). |
| OBS-05 | Mobile: no `--obfuscate --split-debug-info` release configuration found yet (09 §3.5). | Release prep (Phase 7/8). |
| OBS-06 | The JWT `app` claim is set and survives rotation, but nothing enforces it yet (a customer-app token works with `X-App-Name: rider`). | No rider-only endpoint exists in P1. Re-test when the Phase 5 rider endpoints ship (02 §6: "header and token claims decide which app context applies"). |
| OBS-07 | The local dev fallback `SECRET_KEY` (in the public repo's `config/settings/local.py`) signs the JWTs and OTP hashes of every server running local settings, including :8001. Anyone with the repo can mint tokens for any user id on such a server (verified on the QA instance, P1-TC-26b). | Dev-only by design; staging and production refuse it (P1-TC-26c). Keep :8001 bound to 127.0.0.1 or adb-reverse only; never expose a local-settings server on a network. |
| OBS-08 | A user without a name gets addresses with an empty `receiver_name`. | The app forces the complete-profile step first (03 §2.2). Confirm on device (P1-TC-84/89). |
| OBS-P3-01 (doc fixed in `41f02f6`) | 06 §2.6 says a capture of the wrong amount "is recorded nowhere and the order is not placed". The code (R2b) records it as a CAPTURED `Payment` and refunds it in full (`amount_mismatch`). The order's `amount_refunded` stays 0, so the money returned is visible only on the `Refund`. Duplicate-capture refunds behave the same way, and that is by design (DL-45: "without touching the order"). | The behaviour (refund) is the safer choice. The 06 wording should be aligned by the backend agent, and Finance should be told to read refunds from the `Refund` rows. Re-check after the R2b merge. |
| OBS-P3-02 | Lenient type coercion: `POST /cart/items/ {"quantity": "2"}` is accepted as 2. `expected_grand_total: "-0"` gives 409 PRICE_CHANGED rather than 400. | DRF coercion, like OBS-03. P4. |
| OBS-P3-03 | An `X-Razorpay-Event-Id` longer than 64 characters gets 400 "This header is required.", which is a misleading message (the header was sent). | P4 copy. The contract behaviour (400, nothing stored) is fine. |
| OBS-P3-04 | Refunds stay `REFUND_PENDING` until a Celery worker consumes the broker. The QA instance has no worker by default; a QA worker on DB 7 settled every queued refund to `REFUNDED` correctly. | Environment only. Recorded so that REFUND_PENDING on the QA instance is not mistaken for a defect. |
| OBS-P3-05 (2026-11-04, `9ed7ffc`) | Order 18 (a stage-1 QA order, PAYMENT_FAILED) had two separate late captures of ₹508. Each was refunded in full: two PROCESSED `late_capture` refunds, ₹1,016 in total. `amount_refunded` shows ₹508, because `record_refund_status` caps it at `grand_total` (`min(...)`). The money is correct: each charge was refunded once. Only the order-level total understates what went back. | By design today (one charge per order assumed). Raised for P4: with `amount_paid` arriving (backend R2, migration 0003), `amount_refunded` should be bounded by what was paid against the order, and Finance should reconcile from `Refund` rows. P4-TC-44/47 check it. |

## Phase 4 stage 1 (2026-11-04, `1b3552d`)
**No new bugs.** Every failure in the run was a QA test defect (fixed; listed in 03). Known open items not re-filed: OBS-P3-05, T-403c.

| ID | Observation | Why not a bug / next step |
|---|---|---|
| OBS-P4-01 | `manual_refund` keys each refund `manual:<order>:<n+1>`, so two submits make two refunds (each still capped by what is refundable). | No over-refund is possible, but a double click could refund twice. Check the console form's double-submit protection when admin P4 merges (TC-27/33). |
| OBS-P4-02 | Late-capture (P3) orders have `amount_paid` 0 and `amount_refunded` = the late capture (e.g. ₹190), so `amount_refunded > amount_paid` on 26 old orders. | Consistent with DL-45 (a late capture is not a sale). Finance should read refunds from `Refund` rows; QA's P4-TC-44 bound is now `max(grand_total, amount_paid)`. Suggest that 07 says so. |
| OBS-P4-03 | The :8001 beat (`sweep_placed_orders`, `sync_refund_status`) also acts on QA orders on the shared DB. | Environment only; all such actions are idempotent. |
| OBS-P4-04 | T8a recomputes fees from the store's **current** `PricingConfig` (capped at the order's fees). | It never raises the amount (cap); if the config is lowered the customer benefits. Confirm intent with D-10. |

## Phase 4 stage 2 (2026-11-04, `f744508`)
| ID | Title | Module | Severity | Priority | Owner agent | Status | Test / case |
|---|---|---|---|---|---|---|---|
| [BUG-0010](../bugs/BUG-0010.md) | The panel has no manual refund (full / partial) for Super Admin, Support and Finance | admin panel: Orders / Refunds | P2 Major (Medium) | P1 | admin-panel-dev | Open | P4-TC-32, 33, 40 |
| [BUG-0011](../bugs/BUG-0011.md) | Orders admin has no CSV export | admin panel: Orders | P3 Minor (Low) | P3 | admin-panel-dev | Open | P4-TC-40 |

**OBS-P4-01: resolved** (one-time token on the refund-retry form): the identical retry form posted twice makes one retry (TC-34c). The same protection must be on the manual refund form when BUG-0010 is built.

**Open by severity:** P0 0 · P1 0 · P2 1 (BUG-0010) · P3 3 (BUG-0006, BUG-0008, BUG-0011).
