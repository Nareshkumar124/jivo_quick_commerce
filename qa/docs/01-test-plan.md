# 01: Test Plan

**Owner:** qa-engineer · **Created:** 2026-11-02 (QA run 1) · **Covers:** Phases 0–4 (Phase 4 plan added 2026-11-04, §8); extended every phase.

## 1. Scope
| In scope (run 1) | Out of scope (run 1), with the reason |
|---|---|
| Backend API P0/P1: health, schema/docs, error envelope, OTP auth, JWT, me, devices, account deletion, addresses, `config/app`, 426/503 guard (negative cases), Redis-outage behaviour | Phase 2 stores and catalog: work in progress on the main tree, not released |
| Security: OTP abuse limits, token handling, IDOR, mass assignment, enumeration, PII in responses and logs, deploy checks, secrets, dependencies | Positive 426/503 cases: they need `AppConfig` changes on the shared DB (forbidden) |
| Staff: session login, axes lockout (non-existent usernames), role groups, Customers block/unblock | The per-role admin page matrix (05 §3): the admin UI is being reworked; QA run 2 |
| DB: read-only constraint, hashing, orphan, type and retention checks | Running Flutter, devices or the emulator: SDK lock shared with the app agents |
| Light performance baseline (≤ 20 concurrent) | Load testing (Locust, 50 orders/min, 500 sessions): Phase 8 on staging |
| Mobile: static review of the P1 code in `customer_app`, `rider_app`, `jivo_core` | Re-running the dev agents' suites (backend pytest needs `test_jivo_quick_commerce`, which the backend agent was using) |

## 2. Approach
- **Independent and black-box.** QA tests the released commit, not the developers' claims. The backend under test is a clean `git archive` export of the commit (`/tmp/jivo-qa-<sha>/`, with `backend/.env` symlinked, never copied), so uncommitted work in the main tree never leaks into the result.
- **Own instance:** `127.0.0.1:8004` via `qa/tools/instance.sh start <profile> <commit>`:
  - Redis 6380 DB 5–7, QA fixed-OTP numbers `+919000000101…105`, non-test numbers `+9199999000xx` for limit tests
  - console SMS backend, and no Celery worker on the QA broker DB, so no SMS is ever sent
  - **Profiles:**
    - `local`: the role-definition command
    - `staging`: DEBUG off, docs staff-only, throwaway key
    - `redis-down`: Redis URLs point at a closed port
    - `daylimit`: 10-minute OTP cap raised so the daily cap is reachable
- **Automation:** `qa/tests/` (pytest + httpx; a standalone uv project with pinned dependencies).
  - Every response is validated against `backend/openapi/schema.yaml` in strict mode (`additionalProperties: false`), so undocumented fields fail.
  - schemathesis fuzzes the safe operations at a low example count.
  - Known open bugs are `xfail(strict=True)`, so a fix shows up as XPASS and prompts verification.
- **Database:** read-only SQL (`read_only=True` session), aggregates only, credentials from `backend/.env`, never printed.
- **Rate-limit state:** each limit test clears only `jqc:rl:*` keys in the QA Redis DB 5 before and after.

## 3. Environments
| Env | Use | Status |
|---|---|---|
| QA instance 8004 (local / staging / redis-down / daylimit profiles), shared remote PostgreSQL 16 | Run 1 execution | ✅ used |
| Staging deployment (D-05) | Formal gate execution (10 §5) | ⬜ does not exist yet |
| Devices per 10 §4 (low-end Android 10/11, Xiaomi/Realme, recent Samsung/Pixel, iPhones) | Mobile cases | ⬜ not used this run (no devices allowed) |
| Browsers (Chrome primary, Firefox, Edge) | Admin / Ops Console | ⬜ QA run 2 |

## 4. Entry and exit criteria (aligned with 10 §5.1/§5.2)
**Entry per phase:**
- the previous phase is signed off, or its exceptions are written down
- the phase's contract is exported (`schema.yaml`)
- a released commit is available to QA
- test data is seeded (`seed_demo` on staging)

**Exit per phase:**
1. CI green.
2. All phase cases executed on staging, with 100% of Pri P0/P1 cases passed and ≥ 95% of all cases.
3. The regression smoke set (🔥, all previous phases) passes.
4. No open P0/P1 bugs.
5. No unauthorised access, data corruption, duplicate financial transaction or crash in the major workflows.
6. Docs updated.
7. Demo done and sign-off recorded.

## 5. Risks
| Risk | Mitigation |
|---|---|
| Shared remote DB: writes are visible to everyone; intermittent connect timeouts (OBS-01) | QA writes only through the API/admin, with QA test accounts. Read-only SQL. Retry once before filing a 5xx; check the log for `ConnectionTimeout`. |
| Main tree in flux (Phase 2 WIP, unapplied migrations) | Test the exported released commit; never `migrate` |
| 426/503 and some admin behaviour cannot be exercised without changing shared config | Defer them (⏭) until a QA-owned DB or staging exists |
| No devices this run | Static review now; device cases ⬜ for the device run |
| Rate-limit counters and lockouts persist across runs | Clear only QA Redis DB 5 `jqc:rl:*`; lockouts use non-existent usernames |

## 6. Schedule
- **Run 1 (2026-11-02):** P0/P1 backend black-box, security, DB and performance; mobile static review; reports.
- **Run 2:** admin role matrix (P1-TC-67) after the admin rework; Phase 2 contract and behaviour; fix verification of BUG-0001…0006.
- **Device run:** P1-TC-80…92 on the 10 §4 matrix when the PM allows the emulator or devices.

## 7. Phase 3 (cart, coupons, orders, payments): stage 1, 2026-11-04
**Build under test:** `qa/phase-2` at `c2c153a`, which is `develop` (Phase 3 backend R2b WIP and admin T-304 WIP, both unreviewed) merged in. It runs from the QA worktree on a Windows host: no Docker, no `instance.sh` (it needs Linux `ss`/`git archive` to `/tmp`). The instance was started by hand with the role-definition environment: Redis 6380 DB 5–7, QA OTP numbers, `config.settings.local`, so the gateway is `FakeRazorpayGateway`, on `127.0.0.1:8004`, against the shared remote dev DB.

| In scope (stage 1) | Out of scope / deferred, with the reason |
|---|---|
| Cart API: bill vs an **independent 08 §6.2 oracle** (DB prices + `PricingConfig`), set-quantity semantics, MAX_QTY / STOCK guards, tip/instructions, address rules, X-Store-Id, IDOR | Admin Phase 3 screens and the 05 §3 P3 role rows (DL-46): T-304 still in progress. Re-run after the T-304 merge. |
| Coupons: FLAT / PERCENT / max_discount / category eligible-subtotal cap, min order, first-order-only, stops-applying, sheet ordering | Coupon usage exhaustion (per-user/total limits reached) and expired/not-started coupons: they need a QA-owned coupon, created via admin (T-304), because the demo coupons must not be used up |
| Placement T1/T2: COD + ONLINE, snapshot, reservation, Idempotency-Key replay/reuse/parallel, PRICE_CHANGED, guards, one unpaid order, COD limit | `COD_NOT_AVAILABLE` NOT_ALLOWED / COD_DISABLED: they need `User.cod_blocked` or a store setting (admin / shared config) |
| Payments: verify (signature, foreign gateway order, repeat), webhook (raw-body HMAC, event-id idempotency incl. parallel, order-insensitivity, wrong amount, payment.failed, malformed), retry-payment, T3a late capture, duplicate capture, refund settlement (QA Celery worker on DB 7) | `SERVICE_UNAVAILABLE` (gateway down): needs a failing gateway (not configurable without code) |
| T5 cancel; T4 expiry via the :8001 beat (slow, `QA_SLOW=1`); stock oversell race; verify/cancel race | Real Razorpay (test mode) keys: none on this host (D-05 / DevOps) |
| STORE_CLOSED (clock profile, read-only): prepared, see 03 | Customer-app Phase 3 screens on device: no device or emulator this run |
| Read-only DB invariants: money, stock, financial duplicates, history, coupon counts | Load tests: Phase 8 |

**Data hygiene on the shared DB:** COD orders and paid ONLINE orders stay `PLACED`, because Phase 3 has no T11/T12, so each keeps 1–2 units of a high-stock demo variant reserved. The list is in 03 §"Demo data consumed". Every ONLINE test order is cancelled (T5), which releases its stock and coupon hold. No demo coupon was redeemed: the only coupon placements were ONLINE orders that were cancelled or expired, so their holds were released.

**Stage 2 (2026-11-04, `f84482f`):** the admin cases (T-304), the QA-owned coupons (hidden `QAP3*`, made in admin as Super Admin) and the `cod_blocked` case (QA user E) moved into scope. Store COD-disabled stays out of scope, because the demo store is used for the user's phone COD test (PM). The instance runs with `SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend` because the dev settings now use Twilio (T-308).

## 8. Phase 4 (order processing and store ops): plan, 2026-11-04 (QA T-416)
**Inputs:** `docs/development-phase.md` §3 Phase 4; 08 T6–T8a, T11, T12, §6.1, §6.3, §6.4, §7, §9; 05 §1.2, §1.3, §2 (Orders, Payments & refunds, Audit log), §3; 06 §2.6 and §5; 03 §2.5, §2.10; DL-50. **Contract:** backend P4 R1, the interim `schema.yaml` in the `backend/phase-4` worktree (read-only). **Behaviour:** backend R2 and the admin P4 screens are not merged yet. The test cases are P4-TC-01…60 in 02; automation is in `qa/tests/test_p4_*.py`.

### 8.1 Scope
| In scope | Out of scope / deferred, with the reason |
|---|---|
| Customer API: P4 `Order` fields (timeline, cancellation, refunds, `amount_refunded`, `can_download_invoice`, `quantity_unavailable`), customer cancel T11 in PLACED/ACCEPTED and its refusal from PACKING on (08 §7), reorder, invoice guards, list after cancel | Invoice content and signed links (P4-TC-16/17/57): they need a DELIVERED order, which needs the P5 rider flow, unless the backend gives QA another way to reach DELIVERED |
| Store ops: accept (T6), start packing (T7), mark packed (T8, pickup code), item unavailable (T8a, §6.3 oracle), staff cancel (T12), auto-accept and the acceptance-SLA alert, through the Ops Console and the Orders admin | The rider half of T8 ("notify the rider") and T9 onward: Phase 5 |
| Refunds: T11/T12 full refunds, T8a difference refunds, manual refunds with the Support limit, retry of FAILED refunds, `sync_refund_status`, and the webhook-ordering checks carried from P3 (P3-TC-65…69) | Real Razorpay test mode: no keys on this host (D-05) |
| 05 §3 role matrix for the P4 rows (live board, packing console, cancel, refund, audit log) × 7 roles, store scoping, CSRF, audit log | Cross-store scoping on the shared DB: only GGN-01 exists. It needs a QA-owned store (admin, Super Admin) or staging. GGN-01's settings are never changed (the user's phone test uses it) |
| Money and stock invariants (read-only SQL), concurrency (parallel cancels, cancel vs start packing) | Load: Phase 8 |
| Customer app P4 screens and the S4-B cancel integration test | Rider P4 lookahead (earnings, ledger, history against fakes): no P5 contract yet; QA checks it in Phase 5 |
| Carry-overs from P3 (DL-50): P4-TC-49 (₹45 sachet below the ₹99 minimum, needs `seed_demo` by the PM) and P4-TC-50 (`FAKE_GATEWAY_DOWN` on a QA `gwdown` instance profile) | |

### 8.2 Approach and environment
- QA instance `127.0.0.1:8004` from the QA worktree after `git merge --no-ff develop`. `instance.sh` needs Linux, so it is started by hand with the same environment: `config.settings.local`, `SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend`, Redis 6380 DB 5/6/7, QA OTP numbers `+9190000001xx`. A QA Celery worker consumes only DB 7 (`--pool=solo` on Windows). QA does **not** run `celery beat`: the :8001 beat already serves the shared DB, and a second beat would run every periodic job twice.
- Extra instance profiles (environment only, no code): `gwdown` (`FAKE_GATEWAY_DOWN=1`, P4-TC-50), `cancelplaced` (`CUSTOMER_CANCEL_UNTIL=PLACED`, P4-TC-10), `refundwindow` (`REFUND_WEBHOOK_RETRY_WINDOW_SECONDS=20`, P3-TC-69), and short timers for P4-TC-35/37 (`REFUND_STUCK_MINUTES`, `STORE_ACCEPTANCE_SLA_SECONDS`).
- Staff cases log in with the seeded role accounts (password from the environment, never printed; one attempt per login). Console actions are posted with the CSRF token, like a browser. Staff only ever act on QA customers' orders (users A–E).
- **Hygiene on the shared DB:** P4 finally lets QA cancel PLACED orders (T11). Every QA COD or paid order is cancelled at the end of its test, and the PLACED QA orders left by Phase 3 (03 "Demo data consumed") are cancelled once R2 is merged, which releases their reservations.
- Every P4 response is validated strictly against the merged `schema.yaml`. The T8a bill is checked against the independent oracle, never the server's numbers.
- Execution order after the R2 merge: smoke (🔥 P0–P4) → customer API → store ops and refunds → role matrix → SQL invariants → concurrency → profiles (gwdown, cancelplaced, timers) → device and E2E with the PM → mini-UAT.

### 8.3 Entry and exit criteria (10 §5)
- **Entry:** backend R2 and admin P4 merged into develop and reviewed; schema re-exported; `seed_demo` run by the PM (the ₹45 sachet); a QA-owned second store, or staging, for P4-TC-30/36.
- **Exit:** 100% of Pri P0/P1 P4 cases passed (or waived by the PM in writing) and ≥ 95% of all; the 🔥 smoke set P0–P4 green; no open P0/P1 bugs; no unauthorised access, data corruption, duplicate refund or crash in accept → pack → cancel → refund; the store-staff mini-UAT (8.5) done, with its findings triaged.

### 8.4 Risks
| Risk | Mitigation |
|---|---|
| Single shared store: staff actions on GGN-01 are visible on the user's phone and on :8001 | Only QA customers' orders are touched; no store setting is changed on GGN-01; a second store for the scoping and auto-accept cases |
| Refund settlement depends on a worker | A QA worker on DB 7 for the run; the refund-ordering tests start their own worker, so the race is deterministic |
| Invoices need DELIVERED (P5) | Deferred (⏭) with the reason; ask the backend whether a P4 test path to DELIVERED exists |
| WeasyPrint/Pango may be missing on this Windows host (dev-environment.md) | Expect 503 `SERVICE_UNAVAILABLE` for rendering here; render checks on staging |
| The HTMX console is not in the OpenAPI schema | Bind the stubs to the console after the admin R2 merge, from the templates' real form fields, never guessed |

### 8.5 Store-staff mini-UAT script for the packing console (10 §7, gate extra)
**Participants:** 1 store manager and 2 store staff (Jivo's, or the PM standing in until D-22 names them), on the pilot hardware (D-22: tablet or desktop, Chrome) with sound on. QA observes and times; the PM places the orders from the customer app. **Environment:** staging, or the :8001 dev server with the PM's consent; store GGN-01; seeded catalogue. Record each step as Pass / Fail / Comment, with the time taken.

| # | Who | Task | Pass when |
|---|---|---|---|
| UAT-P4-01 | Staff | Log in with your own staff account and open your store's packing console | Only your store is shown; done in under a minute without help |
| UAT-P4-02 | PM → Staff | A new COD order arrives | Sound and a browser notification within 10 s; the order shows an acceptance countdown |
| UAT-P4-03 | Staff | Accept it before the countdown ends | Status "Accepted"; the customer's app shows "Order confirmed" |
| UAT-P4-04 | Staff | Start packing; tick every line on the pick list | Product, variant, quantity (and rack, if configured) are readable at arm's length on the tablet |
| UAT-P4-05 | Staff | Mark packed; print the slip and bag label | The slip shows order number, 4-character code, QR and item count, and prints on the store printer |
| UAT-P4-06 | PM → Staff | Second order (ONLINE, 2 units of one item): mark 1 unit unavailable, then pack | The console shows the new total; the customer gets the update with the refund amount; staff understand what happened |
| UAT-P4-07 | PM → Staff | Third order: every item unavailable | The order is cancelled automatically and leaves the queue |
| UAT-P4-08 | Manager | Cancel an accepted order with a reason | A reason is required; the customer sees the cancellation and refund info |
| UAT-P4-09 | Staff | Try to cancel an order, or to open another store's console | Not offered, or refused (05 §3) |
| UAT-P4-10 | Manager | Switch "Accepting orders" off, try to order from the app, switch it back on | The app shows the store closed while it is off; orders work again afterwards |
| UAT-P4-11 | Staff | Let an order wait past the acceptance SLA (60 s) | The re-alert fires; ops see the breach on the live board |
| UAT-P4-12 | All | Peak: 5 orders within 2 minutes | The queue order is clear, nothing is lost, average acceptance time under 60 s |
| UAT-P4-13 | All | Short questionnaire: what was confusing, what is missing, would you use it on a shift | Feedback logged; the PM triages each item as bug, change request or training |

**Mini-UAT exit:** UAT-P4-01…12 pass, or each failure is filed (bug or change request) and accepted by the PM.

### 8.6 Stage 1 execution note (2026-11-04, `1b3552d`)
Executed everything that does not need the Ops Console. Store actions were driven through the backend services (`qa/tools/store_ops_driver.py`) because admin P4 is not merged; the stage-2 run repeats the console-facing cases through the real pages. Profiles used: `local`, `gwdown`, `cancelplaced` (environment only). On Windows the instance is controlled by `qa/private/qa_instance.sh` (it kills only the PID on 8004).
