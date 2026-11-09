# 01: Test Plan

**Owner:** qa-engineer · **Created:** 2026-11-02 (QA run 1) · **Covers:** Phases 0–5 (Phase 4 plan added 2026-11-04, §8; Phase 5 plan added 2026-11-05, §9); extended every phase.

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

### 8.7 QA-only second store QA-02 (created 2026-11-04 for P4 stage 2, user-approved via the PM)
Created on the shared DB **through the Django admin as Super Admin on :8004** (no direct writes): `qa/private/p4s2/create_qa02.py`, `qa02_pricing_stock.py`.
- **DarkStore id 2**, code `QA-02`, name "QA-02 (test)", Jaipur (Rajasthan, 302001), location 26.9124, 75.7873; service area a ~4 km × 4.4 km box (75.77–75.81 E, 26.89–26.93 N). It does **not** intersect GGN-01's (Gurugram) area (`ST_Intersects` = false). Active, accepting orders, **auto-accept on** (P4-TC-36), invoice prefix `QA02`, timings 00:00–23:59 every day.
- PricingConfig: the defaults (min 99, delivery 25 below 299, small cart 15 below 149, COD up to 2000).
- Stock (admin "Stock inward", reason "QA-02 test stock (QA only)"): 10 each of JV-SUN-1L, JV-CAN-CP-1L, JV-FLAX-250, JV-WG-PW-10S.
- Staff access: none. The seeded Store Manager / Store Staff stay GGN-01-only, which is what P4-TC-30 needs; global roles (Super, Ops, Support, Finance) see it through `stores_for`.
- Checked black-box: serviceability at the Jaipur point → store 2, open; GGN-01's point → still store 1; a point outside both → not serviceable. `/products/` with `X-Store-Id: 2` lists 4 products.
- Rules: only QA customers (+9190000001xx) order there; QA addresses there use Jaipur coordinates.

### 8.8 Stage 2 execution note (2026-11-04, `f744508`)
Console cases run through the real pages (`qa/tests/test_p4_console.py`, `p4_console.Ops`: HTMX headers + CSRF). QA-02 (store id 2) used for TC-30/36/12. The QA worker is started detached (`nohup`) by `p4_support.start_worker`, because a worker started as a child of pytest dies with the run on Windows.

## 9. Phase 5 (riders and delivery): plan, 2026-11-05 (stage 1: test design only)
**Inputs:** 08 §2 (T8, T8a, T9, T10, T11–T14), §3 (delivery-task states), §5 (dispatch), §6.1, §6.4, §9; 06 §3 (rider API and its slice 5.1/5.2/5.3 contract notes), §4.3, §5, §6; 05 §1.4, §1.5, §2 (Riders, Rider earnings & payouts), §3; 04 §2–§3; 09 §1, §3.2, §3.3, §3.6, §4 (Rider KYC, DPDP); DL-54, DL-56, DL-57, DL-58, DL-59.

**Builds read:**
- `develop` at `4fdea44`, merged into `qa/phase-2` (fast-forward). Slices 5.1 and 5.2 are live there; the 5.3/5.4 operations answer 503.
- Slice 5.3 on `backend/phase-5` at `fd1490c`, read-only: `schema.yaml`, `apps/delivery/services/{dispatch,tasks,presenters}.py`, `orders/store_ops.receive_return`, settings and the doc diffs.
- Slice 5.4 (COD UPI QR, cash ledger and deposits, earnings, payouts, history, ops unlock/assign/unassign/retry/receive-return screens) is being built. Its cases are written against the docs and the 5.3 notes and will be re-bound to its contract when it lands.

**Nothing was executed in stage 1.** Every P5 case is ⬜.

### 9.1 Scope
| In scope | Out of scope / deferred, with the reason |
|---|---|
| 5.1 KYC and onboarding: register, documents (type, size, magic bytes, EXIF, masking, private storage), bank details, rider-status access rules, Riders admin review actions, DPDP erasure of a rider | Real Aadhaar/PAN verification services: none in v1 (D-14) |
| 5.2 shifts, location batches, heartbeat, auto-offline, presence by server receipt time, force offline, rate limits | Background location on real devices (OEM battery killers, Play declaration): device run only, with the PM |
| 5.3 dispatch (candidates, ranking, offers, accept/reject/expiry, give-up and resume, races), pickup code and T9 stock commit, arrival geofences, delivery OTP and its 5-try lock, T10 (prepaid, COD cash), T13 and its refunds, T14 receive return, manual assign/unassign/retry, cancellation during dispatch | FCM push and the rider WebSocket (`/ws/v1/rider/`): D-19 and P6. Offers are checked by polling; push and socket messages only as recorded `Notification` rows or ops-alert log lines |
| 5.4 COD UPI QR, cash ledger and deposits, earnings, payouts, task history, ops unlock, day-end COD report | Payout settlement through a bank: Finance records payouts by hand in v1 |
| IDOR for every rider object (offers, tasks, documents, failure photos, ledger, earnings, history, payouts) and for customer tracking | Masked/proxy calling (DL-56): no provider chosen |
| 05 §3 role matrix for every rider, dispatch, cash and payout action, plus CSRF and audit | Load (50 orders/min, many riders): Phase 8 on staging |
| Customer tracking and OTP visibility (DL-56); P4 carry-overs that need DELIVERED (P4-TC-16/17/57 → P5-TC-77) | |
| Read-only SQL invariants for tasks, offers, the cash ledger and stock | |

### 9.2 Approach and environment
- **QA instance.** `127.0.0.1:8004` runs from the QA worktree after `git merge develop`, with the role-definition environment (Redis 6380 DB 5/6/7, QA OTP numbers, console SMS).
  - A **QA Celery worker on DB 7** runs the `expire_offer`/`dispatch_order` countdowns, refunds and invoices. QA does not run beat.
  - Once 5.3 is on develop and :8001 is restarted, the :8001 beat's `delivery.dispatch_sweep` (every 15 s) also acts on QA tasks, because the DB is shared. Tests must accept either process expiring an offer.
- **Isolation through QA-02** (store id 2, Jaipur, auto-accept on, DL-57).
  - Every Phase 5 order is placed at QA-02 by QA customers, and the QA riders have QA-02 as home store.
  - So dispatch never offers a QA order to a rider of the user or the other agents (all GGN-01), and never offers a real order to a QA rider. Nothing is changed on GGN-01.
- **Accounts.**
  - Customers: A (owner) and B (IDOR) shop at QA-02 with a Jaipur address about 1.9 km from the store (26.9250, 75.8000).
  - Riders: R1 = QA user C and R2 = QA user D.
  - Staff: the seeded role accounts (password from the environment, never printed).
  - KYC: a rider is moved through review by the Riders admin (Super Admin/Ops). Until the 5.4 console pages exist, `qa/tools/rider_ops_driver.py` calls the same services as a seeded staff user. It refuses any rider or order that is not a QA number's.
- **Positions are sent by the client** (lat/lng in the request). Geofence and ranking cases use computed offsets from the QA-02 pin (`p5_support.offset`). Real GPS is a device-run concern.
- **Timers.** The smoke set uses the default timers (30 s offers, 10 min not-reachable wait, 10 min auto-offline). Long waits use environment-only instance profiles:
  - `dispatchfast`: `OFFER_TIMEOUT_SECONDS=10`, `DISPATCH_TIMEOUT_SECONDS=60`, `DISPATCH_UNASSIGNED_PAUSE_SECONDS=15`, `DISPATCH_RETRY_SECONDS=5`
  - `riderclock`: `RIDER_NOT_REACHABLE_WAIT_SECONDS=20`, `RIDER_RECENT_TASK_SECONDS=60`
  - `triggerplaced`: `DISPATCH_TRIGGER=PLACED`

  The :8001 beat runs with the defaults, so profile cases check only what the QA worker's countdowns decide.
- **Oracles** (never the server's own numbers):
  - 08 §6.1 stock table: read-only SQL before and after T9 and T14
  - 08 §6.4 with the D-10 defaults for T13 refunds: everything refundable, minus the delivery fee on customer fault
  - rider pay `30.00 + 5.00 × distance_km` (D-16 default), computed by QA
  - the ledger's `balance_after` chain, recomputed by QA
- **Every response** is validated strictly against the merged `schema.yaml`. Races use ≤ 20 parallel requests, on the QA instance only.
- **Automation:** `qa/tests/test_p5_*.py`, with helpers in `p5_support.py`. The slice 5.3 cases are marked `p5_53` and skip themselves until both hold:
  1. commit `fd1490c` is an ancestor of the commit under test
  2. table `delivery_deliveryoffer` exists in the shared DB (migration `delivery.0002` applied by the PM)

  `QA_P5_53=1` forces them.

### 9.3 Entry and exit criteria (10 §5)
- **Entry, stage 2 (5.3):**
  - `backend/phase-5` reviewed and merged into develop
  - `delivery.0002` applied to the shared DB by the PM (it is not in the DL-58 approval, which named `delivery 0001`)
  - the extra QA numbers and the QA-02 store manager (9.4)
  - QA-02 stock topped up
- **Entry, stage 3 (5.4):**
  - 5.4 backend and admin merged
  - schema re-exported with the UPI QR, ledger, earnings, payouts and history shapes
  - the fake gateway's QR-payment simulation documented (as 06 §2.6 does for checkout)
- **Exit:**
  - 100% of Pri P0/P1 P5 cases passed (or waived in writing by the PM), and ≥ 95% of all
  - 🔥 smoke P0–P5 green
  - no open P0/P1 bugs
  - no unauthorised access, stock or cash-ledger corruption, duplicate refund or duplicate cash entry, and no crash in offer → accept → pickup → deliver/fail → return
  - the rider device run (P5-TC-131) done by the PM on the phone

### 9.4 Dependencies and requests to the PM
1. **Apply `delivery.0002`** to the shared DB after the 5.3 merge (user approval). Until then every 5.3 case is blocked.
2. **Five more QA fixed-OTP numbers**, `+919000000106…110`, on the QA instance only (QA's own environment variable; nothing shared changes). They are for:
   - a third rider (ranking with three candidates)
   - a PENDING_KYC rider and a REJECTED rider
   - a rider to anonymise (P5-TC-18)
   - a COD-refusal customer (P5-TC-82, which COD-blocks the user)

   Without them, those cases run on users C/D and are undone afterwards, or stay ⏭.
3. **A QA-only Store Manager account scoped to QA-02**, created by QA as Super Admin through the admin (as QA-02 itself was). The seeded Store Manager stays GGN-01-only for the negative "other store" cases. It covers the "own store" ✔ cells of Manual dispatch and Cash deposit (P5-TC-95, 113, 114).
4. **QA-02 stock top-up** through the admin "Stock inward" (QA only, reason "QA-02 P5 stock"). Each delivered order consumes stock: about 40 units each of JV-SUN-1L and JV-FLAX-250.
5. **The 5.4 Ops Console URLs** (assign, unassign, retry, unlock, deposit, receive return, payouts). Until then QA drives those actions through the services and re-runs the console-facing cases when the pages merge.
6. **QA user D** was P4's QA-02 shopper (`test_p4_console.qa02_shop`) and becomes rider R2. In stage 2 QA moves that P4 fixture to user B, so a rider is never offered their own order (ambiguity A10).

### 9.5 Risks
| Risk | Mitigation |
|---|---|
| The :8001 beat (defaults) and the QA worker (profile timers) both act on QA tasks through the shared DB | Assert outcomes, not which process produced them. Timer cases use `dispatchfast` margins wider than the 15 s sweep, or assert only that the state changed within a bound |
| A QA rider left online with a stale ping, or a task left open, blocks later runs | Fixtures end shifts, finish or fail their tasks and receive returns in teardown; `p5_support.reset_rider` runs before each case |
| QA-02 stock runs down (T9 commits stock) | Top-up request (9.4 item 4); TC-66 checks for negative stock |
| Remote-DB latency inflates the offer latency (09 §1, < 3 s) and location → map (< 5 s) timings | Reported as local indications only; real numbers in Phase 8 on staging |
| Push and sockets are no-ops until D-19/P6 | Check the recorded `Notification` rows and ops-alert log lines; device push in the P6 run |
| Rider location is client-reported, so geofences can be spoofed | Out of reach for black-box tests. `is_mocked` flagging is checked (TC-26) and the residual risk goes in the security report |

### 9.6 Doc ambiguities found during design (to raise through the PM)
| # | Where | Ambiguity | QA's working assumption |
|---|---|---|---|
| A1 | 08 §3 vs 06 §3 (5.3 notes) | The task diagram has `FAILED → RETURNING`. 5.3 moves the task straight to `RETURNING` (`failed_at` set), so `FAILED` is never observable, though it is still in `DeliveryTaskStatusEnum` | The implementation note wins; the 08 §3 diagram should be updated |
| A2 | 08 T14 | The guard "Rider is at the store" has no server check (no rider geofence or confirmation). T14 says "Store staff", but the permission is `orders.process_order`, which Ops and Super Admin also hold | Staff confirm presence by doing the action; any packing-console role may receive a return |
| A3 | 08 T13, 06 §3 | T13 "or ops marks it" has no ops service in 5.3 or in the 5.4 list. A delivery whose OTP is locked "only ops can resolve", but the resolution is not defined (unlock and retry, an ops-marked failure, or an ops-confirmed delivery) | Ops unlock (5.4) is the only path; ops-marked failure stays untested until it is specified |
| A4 | 05 §3 | No matrix rows for force offline, OTP/pickup unlock, set cash limit, retry dispatch or receive return. Cash deposit has no ✔ for Ops/Dispatch | Force offline and cash limit = the Rider approval roles (SA, Ops); unlock and retry = the Manual dispatch roles; receive return = the Packing console roles; Ops may **not** record deposits |
| A5 | 04 §2.3/§2.7 vs 08 §5 | 04: prepaid-only "at or above the limit". 08: a COD offer needs `cash_in_hand + grand_total ≤ cash_limit`. So a rider below the limit is silently skipped for large COD orders without seeing the banner, and an ops manual assign answers 422 with no override | The 08 rule for dispatch, the 04 rule for `prepaid_only` and the banner; no ops override |
| A6 | 08 §5.2 | "Longest idle time": 5.3 measures it from the end of the rider's last task (else the approval time), not from going online | As implemented; confirm the fairness intent |
| A7 | DL-56 vs 08 §9 | The OTP is on `track` only while OUT_FOR_DELIVERY, but T9 also sends it by push (+SMS), and the inbox keeps the notification text. No rule says to blank it after delivery | The OTP is allowed in the owner's T9 push, SMS and inbox; QA flags it if it stays readable after DELIVERED |
| A8 | 09 §3.2 vs 04 §2.8 | The customer's phone and address are "hidden again 1 hour after task completion". `recent_task` (10 min) shows neither, but the 5.4 history ("store→drop") is not specified | History shows at most the drop locality, never the phone or the full address |
| A9 | 06 track, 08 §9 | Whether the customer sees the rider's live location while ASSIGNED/AT_STORE, before pickup | Location and name from ASSIGNED; phone and OTP only while OUT_FOR_DELIVERY |
| A10 | 08 §5.1 | A user who is both a customer and an ACTIVE rider of the same store can be offered their own order | Should be excluded; an observation until decided |
| A11 | 04 §5 note | The pickup-code alphabet and case. 5.3 compares case-insensitively and accepts the QR `JQC1:<order_number>:<code>`; the QR format is "to confirm" | Case-insensitive; the QR format of 06 §3 |
| A12 | 04 §2.6 vs 06 §6 | Is the 5th wrong delivery OTP a 400 `DELIVERY_OTP_INVALID` with 0 left, or a 423? (5.3 answers 423 on the 5th.) Does a malformed OTP (letters, wrong length) use an attempt? | 423 on the 5th; malformed input is 400 `VALIDATION_ERROR` and uses no attempt |
| A13 | 08 T13, 04 §2.6 | `call_attempts` is reported by the client and cannot be verified. The 10-minute wait runs from arrival at the customer (5.3), not from the first call | As implemented; the residual risk is recorded |
| A14 | 08 §6.4 | T13 reason OTHER is refunded in full (5.3), though it may be the customer's fault. 08 says repeated refusals "flag the user for COD block"; 5.3 blocks automatically after 2 | The D-10 defaults as implemented (⚠ Jivo) |
| A15 | 08 §5.1/§5.6 | After UNASSIGNED the auto-retry "resumes until ops assigns manually", but candidates exclude riders "already offered this task", and 5.3 keeps that exclusion across rounds. A store whose riders all missed the offer never gets a new offer, so only ops can assign | The doc literally; QA records the behaviour (P5-TC-47) and asks whether a new round should re-admit riders |
| A16 | 08 T10, 04 §2.8, D-16 | Earnings for failed, returned and cancelled-after-arrival tasks; whether the whole tip goes to the rider; the tip on a refunded failed ONLINE order | No earnings unless DELIVERED; the tip goes fully to the rider; a refunded tip earns nothing |
| A17 | 04 §2.6, 06 §3 | UPI QR: the `payment_status` after a UPI-collected COD order (COD_COLLECTED or PAID); whether a repeated `cod-qr` returns the same QR; what happens to a QR that expires unpaid or whose task is failed, and to a payment that reaches it late | The same open QR on repeat; an expired or cancelled QR refunds any late payment |
| A18 | 06 §3 (#25) | Ops reject a document of an ACTIVE rider who is **online**: forced offline, or kept online and still dispatched? | The rider may finish the current task but gets no new offers |
| A19 | 04 §2.3 vs 06 §3 | 04 still says auto-offline after 10 min with no "location heartbeat". 06 (#42) keeps a rider online through a `rider_heartbeat` if the last point is ≤ 30 min old | 06 |
| A20 | 04 §2.5/§2.6 | Geofence "~200 m". 5.3 adds the reported accuracy, up to 50 m (`RIDER_GEOFENCE_MAX_ACCURACY_SLACK_M`), so the effective radius is up to 250 m | 06 and the settings |
| A21 | 09 §1 | "Offer delivery < 3 s" cannot be measured without FCM/WS (D-19, P6) | P5 measures dispatch decision → offer row (server side); end to end in P6 |
| A22 | 08 §7 | A customer may cancel in ACCEPTED while a rider is already ASSIGNED or AT_STORE (the default trigger is ACCEPTED). No rule on rider compensation | No earnings; the task is CANCELLED |
| A23 | 08 §5 step 4 | "All other pending offers withdrawn" on accept, but v1 offers a task to one rider at a time | Only the manual-assign path withdraws other offers |

### 9.7 Schedule
- **Stage 1 (2026-11-05, this run):** this plan, 132 cases (02 "Phase 5") and the 5.3 automation scaffold (`test_p5_*.py`, `p5_support.py`, `tools/rider_ops_driver.py`). Nothing executed.
- **Stage 2 (after the 5.3 merge and `delivery.0002`):**
  1. 🔥 smoke P0–P4
  2. the 5.1/5.2 cases (already live)
  3. the 5.3 automation, IDOR, tracking, SQL invariants and races
  4. the timer profiles
- **Stage 3 (after 5.4):** COD UPI QR, ledger, deposits, earnings, payouts, history, the ops screens and the role matrix through the console; regression of 5.3.
- **Device run (PM):** P5-TC-19, 33, 124 and 131 on the user's phone.

## 10. Phase 6 (real-time and notifications): plan, 2026-11-06 (prep while T-612/613/614 are in progress)
**Contract read:** develop `8f87d7b` (T-611 merged: `f08c329`, `b5591c7`, `21428a2`): 06 §4 (sockets, close codes, abuse limits, message shapes), 06 §2.7 inbox, 06 §5 jobs, 08 §8 ETA, 08 §9 notifications per transition, 07 (Notification, retention), 09 (DPDP, DLT). Code inspected: `apps/realtime` (consumers, auth, limits, groups, routing, services) and `apps/notifications` (catalog, services, tasks, views).

### 10.1 Scope
| Task | What QA tests | When |
|---|---|---|
| T-611 (on develop) | Order socket auth (first message or subprotocol; never the URL), close codes 4400/4401/4404/4408/4429/1009, snapshot and live `order.status`; ops live feed (session, Origin, role matrix, store scope, no customer data); inbox list/read/read-all, scoping and IDOR; 08 §9 event→channel matrix, DLT rule, no OTP at rest or in the inbox; purge/sweep jobs scheduled; abuse limits; no JWT in server logs | Now (P6 stage 1) |
| T-612 | Rider socket events `offer.new` (< 3 s), `offer.withdrawn` (EXPIRED/TAKEN/ORDER_CANCELLED/REASSIGNED), `task.updated`, cash updates; customer `rider.location` and `order.eta` (08 §8); ops `rider.location`/`rider.status`/alerts | When T-612 merges (cases ⏭ until then) |
| T-613 / T-614 | App behaviour: tracking over WS with polling fallback and reconnect, inbox screens, FCM adapter; rider app socket with polling/FCM fallback | Device run (PM, user's phone) |

Out of scope: real FCM (D-19, push backend disabled/console), real SMS delivery (no DLT ids locally), load testing of sockets (Phase 8 on staging).

### 10.2 Approach and environment
- Black-box `qa/tests/test_p6_ws.py` with the `websockets` client (pinned 15.0.1) against the QA instance `127.0.0.1:8004` (runserver with `daphne` first in `INSTALLED_APPS`, so it serves ASGI and WebSockets), Redis DBs 5–7, the QA Celery worker on DB 7 (order events fan out through `broadcast_ws`).
- Users: QA customers A/B/E (`+9190000001{01,02,05}`), QA rider R1 (`…103`) only to open its socket (no rider-state changes outside the P5 harness), seeded staff for the ops feed. Orders for live-event cases are placed at the QA-only store QA-02 and cancelled by the test.
- Database: read-only SQL for the notification matrix, OTP-at-rest and the beat schedule. Purge jobs are never run on the shared DB (they delete rows); their behaviour is covered by the backend's tests, QA checks the schedule and retention read-only.
- Timers: auth timeout (10 s) runs live; token expiry, ops re-check (300 s) and rider re-check (60 s) need short-timer instance profiles (`shorttoken`, `wsrecheck`) and run in stage 2.

### 10.3 Entry and exit criteria (10 §5)
- **Entry:** T-611 on develop and migrations `notifications.0001` applied (true at `8f87d7b`); for stage 2, T-612 merged.
- **Exit:** no open P0/P1 bug; 100% of P0/P1 P6 cases passed and ≥ 95% overall; the P6 🔥 set plus the P5 🔥 regression set pass; no socket that reveals another user's order, rider or store data; no OTP or JWT in logs, the inbox or at rest; offer latency < 3 s (T-612); device run of T-613/T-614 done by the PM.

### 10.4 Risks
- Live-event cases depend on the QA Celery worker; a dead worker looks like a missing event (the harness starts it and the case reports a worker problem separately).
- Socket leases live in Redis DB 5 for 20 minutes; a crashed test could hold slots and give false 4429s, so the suite clears `ws:sockets:*` in DB 5 first.
- Shared DB latency (~10 ms/query) inflates event latency measurements; the < 3 s offer target is measured end to end and recorded with that caveat.
- Doc ambiguities to raise: (P6-A1) the coordinator brief lists `offer.expired` and `cash.updated`, but 06 §4 has only `offer.withdrawn` with reason EXPIRED and no cash message; (P6-A2) 06 §4 lists only DISPATCH/… alerts, not when `rider.status` is sent; (P6-A3) the order socket does not check the token's `app` claim (a rider-app token of the owner can open the order socket); harmless, but unspecified.
