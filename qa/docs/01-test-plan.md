# 01: Test Plan

**Owner:** qa-engineer · **Created:** 2026-11-02 (QA run 1) · **Covers:** Phase 0 and Phase 1; extended every phase.

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
