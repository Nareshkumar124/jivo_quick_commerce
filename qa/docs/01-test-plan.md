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
