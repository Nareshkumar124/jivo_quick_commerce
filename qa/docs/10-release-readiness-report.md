# 10: Release Readiness Report

**Latest verdicts:** "Run 2 on main (2026-11-16, after the DL-76 migrations)" at the end of this file. Earlier sections are kept as history.

**Date:** 2026-11-02 (QA run 1) · **Build:** backend commit `4960527` (released P0+P1). The apps were statically reviewed at the same commit · **Gate rules:** `docs/10-testing-strategy.md` §5.2.

## Phase 0: Foundation. Verdict: **Not ready (gate incomplete)**
The backend criteria are met. The app build, the generated client and CI were not verified by QA: P0-TC-21/22 are Pri P1 and ⏭, P0-TC-23 is ⬜, and 21/25 (84%) is below the 95% gate.

| §5.2 criterion | Result |
|---|---|
| CI green (lint, tests, coverage, migrations, schema) | ⬜ Not verified by QA. The dev agents report 318 backend tests passing at 99% coverage. QA did not re-run the backend suite: its test DB name is hard-set and was in use by the backend agent. |
| Phase cases on staging: 100% of P0/P1-priority cases passed, ≥ 95% of all | 21/25 ✅. ❌ P0-TC-08b (BUG-0001, Pri P2). ⏭ P0-TC-21/22 (apps build, generated client; no Flutter this run). ⬜ P0-TC-23 (CI status). Run on a QA instance (local + staging-like settings), **not on a staging deployment**, which does not exist yet. |
| Smoke set | ✅ P0-TC-01, 02, 04, 12 pass |
| No open P0/P1 bugs | ✅ none (BUG-0001 is P3) |
| Unauthorised access / data corruption / crash in major workflows | None found |

## Phase 1: Auth & users. Verdict: **Not ready**

Context (not part of the verdict): no P0/P1-severity bugs are open, and the backend core flows are verified black-box.

**Why Not ready:**
1. **No P0/P1-severity bugs are open.** But 5 Pri-P0/P1 test cases fail on three Medium (P2) bugs:
   - P1-TC-04, P1-TC-13 and P1-TC-14b on BUG-0002 (non-ASCII numeric input)
   - P1-TC-24c on BUG-0003 (refresh-token single use; details private)
   - P1-TC-57 on BUG-0007 (a concurrent set-default race can leave zero default addresses)

   §5.2 requires 100% of P0/P1-priority cases to pass, so these bugs must be fixed, or the cases explicitly waived by the PM, before sign-off.
2. **Pass rate:** 78/105 (74%) of all P1 cases pass, below the ≥ 95% gate, mainly because 13 mobile device cases are ⬜ (not run: no devices this run) and 6 are ⏭.
3. **Deferred positive cases:**
   - 426 force-update and 503 maintenance (P1-TC-61/62): `AppConfig` may not be changed on the shared DB.
   - The admin role matrix (P1-TC-67): admin UI in flux.
   - Anonymisation after 30 days (P1-TC-46).
4. **Human gate steps still pending** (§5, §8): deployment to staging plus `seed_demo`, QA execution there, the regression smoke set on staging, a stakeholder demo and sign-off.

**What QA verified independently (black-box, commit `4960527`):**
- OTP sign-in: hashing, 5 attempts, single use, supersede, app/purpose isolation, per-phone (10 min / day) and per-IP limits, XFF spoofing ignored, fail-closed on Redis loss.
- Token rotation, revocation, logout, deletion revoke-all, forged/tampered/expired tokens.
- Profile and email rules (no enumeration, no mass assignment), devices.
- Account deletion with restore during the grace period.
- Addresses CRUD, default invariants (BUG-0007 race under concurrent set-default), soft delete.
- **IDOR → 404** on all four address object operations.
- `config/app` and the no-426 rules, staff session login, axes lockout, role groups, block/unblock.
- DB constraints and hashing (read-only SQL), PII in responses and logs.
- `check --deploy`, a secrets scan, pip-audit and schemathesis fuzzing.

183 automated cases passed on the local profile (final regression run: 181 passed, 1 BUG-0007 race, 1 remote-DB timeout) and 177 on DEBUG-off staging settings. Every 5xx seen was traced to remote-DB connect timeouts (OBS-01), except BUG-0001.

**Conditions to reach "Ready":**
- Fix BUG-0002, BUG-0003 and BUG-0007, or get a PM waiver.
- Run P1-TC-61/62 on a QA-owned or staging config.
- Run P1-TC-67 in QA run 2.
- Execute the device cases P1-TC-80…92 on the device matrix (10 §4).
- Re-run the 🔥 smoke set on staging.

## Sign-off template status (10 §8)
```
Phase 1 sign-off
- Test run date:        2026-11-02 (QA run 1, pre-staging)
- Build / commit:       backend 4960527, customer_app n/a (static review only), rider_app n/a (static review only)
- Cases executed:       86 / 105   Passed: 78   Failed: 8   Deferred: 6   Not run: 13
- Open bugs:            P0: 0  P1: 0  P2: 3  P3: 4
- Demo given to:        pending (human step)
- Approved by:          pending
- Notes / deferrals:    P1-TC-61/62 (shared AppConfig), P1-TC-67 (admin rework), P1-TC-46 (time travel), device cases
```

## Phase 3: Cart, coupons, orders and payments. Interim verdict (stage 1, 2026-11-04): **Not ready (gate incomplete); backend API on track**
**Build:** `c2c153a` (`develop` with backend R2b and admin T-304 still WIP and unreviewed). This verdict is **interim** and must be re-run after the R2b and T-304 merges.

| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| 100% of P0/P1 cases passed, ≥ 95% of all | ❌ 56/64 (87.5%). No P0/P1 case **failed**. The ones not passed are ⏭/⬜: TC-26, 59–63, 64 |
| Smoke set | ✅ P0–P3 (72 + P3-TC-43) |
| No open P0/P1 bugs | ✅ Only BUG-0009 (P3 Low) is new |
| No unauthorised access, data corruption, duplicate financial transaction or crash in major flows | ✅ None found: IDOR, signatures, idempotency, races and SQL invariants all hold |

**To reach Ready:**
1. Merge R2b and re-run the full P3 suite plus `QA_SLOW=1` P3-TC-47.
2. Merge T-304 and run P3-TC-59/60, plus P3-TC-61 with a QA coupon.
3. Find a way to run P3-TC-62/63: a QA-owned DB/config or staging.
4. Run the customer-app device case P3-TC-64.
5. Run on staging, with CI evidence.
6. Fix BUG-0009 (optional for the gate: P3).

### Phase 3 update (stage 2, 2026-11-04, `f84482f`): verdict **Ready for sign-off on the QA instance, conditional; formal gate pending**
| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| 100% of P0/P1 cases passed, ≥ 95% of all | **61/64 = 95.3%** ✅ ≥ 95%. All **P0** cases passed except P3-TC-64 (the user's device test). Two **P1** cases are ⏭: P3-TC-26 (no data) and P3-TC-63 (fault injection) |
| Smoke set | ✅ 73 + P3-TC-43 |
| No open P0/P1 bugs | ✅ (open: BUG-0006 and BUG-0008, both P3) |
| No unauthorised access, data corruption, duplicate financial transaction or crash | ✅ None found |

**Conditions before sign-off:**
1. Re-check the refund cases (P3-TC-37/38/39/47/58 and worker settlement) after the refund fix run.
2. Get a pass on P3-TC-64 from the user's phone test.
3. Decide on the two ⏭ P1 cases: accept them as deferred, or seed a variant below ₹99 and add a gateway-down switch for the fake gateway.
4. CI evidence and a staging run (D-05) for the formal gate.

### Phase 3 update (refund re-check, 2026-11-04, `9ed7ffc`, T-310): verdict **Ready for sign-off on the QA instance; formal gate pending (device test, CI, staging)**
Condition 1 of stage 2 (the refund re-check) is **met**. The refund fixes in develop `dff62d5` hold black-box.

| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| 100% of P0/P1 cases passed, ≥ 95% of all | **66/69 = 95.7%** ✅. Every P0 case passed except P3-TC-64 (the user's device test). The two P1 ⏭ cases, P3-TC-26 and 63, moved to Phase 4 as P4-TC-49/50 (DL-50), so they no longer block P3 |
| Smoke set | ✅ `77 passed` (P0–P4 🔥; the P4 stubs skip) |
| No open P0/P1 bugs | ✅ (open: BUG-0006 and BUG-0008, both P3; no new bug in this run) |
| No unauthorised access, data corruption, duplicate financial transaction or crash | ✅ No duplicate or excess refund anywhere in the DB (P4-TC-44); the webhook-before-task race settles exactly once (P3-TC-65/66); FAILED is never reopened (P3-TC-68); the 503 is bounded (P3-TC-69) |

**Remaining before sign-off:**
1. P3-TC-64 on the user's phone (PM).
2. CI evidence and a staging run (D-05) for the formal gate.
3. Optional: re-verify BUG-0008 (P3).

## Phase 4: Order processing and store ops. Interim verdict (stage 1, 2026-11-04, `1b3552d`): **Not ready (gate incomplete); backend P4 on track**
| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| 100% of P0/P1 cases passed, ≥ 95% of all | ❌ 37/60 fully passed (62%). **No case failed.** The cases not passed are console cases (admin P4 not merged), device cases, cases needing a second or auto-accept store, and DELIVERED-only invoice cases |
| Smoke set | ✅ P0–P4: 89 passed; P3-TC-50 green after the oracle update (no product defect) |
| No open P0/P1 bugs | ✅ (no new bugs; open: BUG-0006 and BUG-0008, both P3) |
| No unauthorised access, data corruption, duplicate financial transaction or crash | ✅ IDOR 404s; roles enforced in the services; T8a = oracle; refunds never above what was paid; FAILED/retry/sync never double-refund; reservations released, no stock movement before pickup |

**To reach Ready:** (1) merge admin P4 and run TC-31/38–43/60 plus the console versions of TC-19–21, 27, 32, 33 and 41; (2) a QA-owned second store (or staging) for TC-30/36 and the NOT_AVAILABLE part of TC-12; (3) a device run for TC-51–54, 56 and 58; (4) the mini-UAT (01 §8.5); (5) the invoice cases TC-16/17/57 in P5 (DELIVERED); (6) CI evidence and staging.

### Phase 4 update (stage 2, 2026-11-04, `f744508`): verdict **Not ready**
| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| 100% of P0/P1 cases passed, ≥ 95% of all | ❌ 46/60 = 77%. Not passed: TC-32/33 (P0) and TC-40 (P1) fail on BUG-0010/0011; device cases TC-51–54, 56, 58 (P0/P1) ⬜; invoice cases TC-16/17/57 and TC-55 ⏭ (need DELIVERED, P5) |
| Smoke set | ✅ 98 passed (P0–P4) |
| No open P0/P1 bugs | ✅ (open: BUG-0010 P2, BUG-0011 P3, BUG-0006/0008 P3) |
| No unauthorised access, data corruption, duplicate financial transaction or crash | ✅ Role matrix and store scoping hold server-side; CSRF enforced; no double refund (retry token, T8a double post, sync); stock and money invariants hold |

**To reach Ready:** (1) fix BUG-0010 (manual refund form with a one-time token) and re-run TC-32/33/40; BUG-0011 can be accepted as P3 or fixed; (2) device run TC-51–54, 56, 58; (3) the store-staff mini-UAT (01 §8.5); (4) decide whether the invoice cases (TC-16/17/57, TC-55) move to P5 like DL-50 did; (5) CI evidence and staging.

## Phase 5: Riders and delivery. Interim verdict (stage 1, 2026-11-05, `4fdea44`): **Not ready (not executed)**
Stage 1 was test design only. The plan is `01-test-plan.md` §9 and the 132 cases are P5-TC-01…132 in `02`. **No case has been executed**, so none counts toward the gate.

| §5.2 criterion | Result |
|---|---|
| CI green | ⬜ Not verified by QA |
| Phase cases: 100% of Pri P0/P1 passed, ≥ 95% of all | ⬜ 0/132 executed (127 ⬜, 5 ⏭: device run and P6) |
| Smoke set (🔥, 27 P5 cases + P0–P4) | ⬜ |
| No open P0/P1 bugs | No P5 bugs filed (nothing executed) |
| Unauthorised access / data corruption / crash in major workflows | ⬜ Not tested |

**Blocking entry items:**
- slice 5.3 (`backend/phase-5` `fd1490c`) is not merged
- migration `delivery.0002` is not applied to the shared DB
- slice 5.4 is not built
- the QA requests in `01` §9.4 are open: extra QA numbers, a QA-02 store manager, a QA-02 stock top-up
- 23 doc ambiguities (A1–A23, `01` §9.6) need PM/Jivo answers. A3 (how ops resolve a locked delivery OTP) and A4 (the missing 05 §3 rows) affect P0 cases

## Phases 5, 6 and 7: QA stage 2 (2026-11-09, develop `efb3c3d`, QA instance :8004): **partial run, stopped for a PC shutdown**
**Environment:** QA worktree `qa/phase-2` with develop `efb3c3d` merged (not committed), `127.0.0.1:8004` (`config.settings.local`, Redis 6380 DB 5/6/7, QA OTP numbers `+919000000101…110`), QA Celery worker on DB 7 (threads pool, 4), shared remote DB. The P5 skip gate was removed (slice 5.3/5.4 on develop). PM-approved QA set-up done: numbers 106–110 (instance env only), QA-02 Store Manager `qa02.manager@jivo.test` (created through the admin as Super Admin; Store Manager group, QA-02 access only), P4 QA-02 shopper moved from user D to user B. QA-02 stock top-up was not needed (JV-SUN-1L 67, JV-FLAX-250 110 on hand).

**What ran:**
- P5: `uv run pytest tests/test_p5_*.py` stopped after **148 of 226** tests: 122 passed, 18 skipped, 3 xfail (known bugs), **5 failed** (`test_p5_cash`: TC-88 ×2, TC-89 ×2, TC-93). The failure details were not printed before the stop (pytest prints them at the end), so their cause is **not analysed** and no bug is filed. Per case: **52 ✅, 4 ❌** (TC-88, 89, 93; TC-16 = BUG-0013), the rest not reached (files `test_p5_kyc` tail, `ops`, `security`, `shift`, `task_flow` were partly or not run in this session; the 2026-11-06 runs in `private/runs/p5-final-*` passed most of them on an earlier build).
- P6: TC-13 (deleted user's token → 4401) ✅. The T-612 suite (`test_p6_t612.py`, incl. new TC-59 polling-fallback parity) and the T-611 regression were **not run** this session. BUG-0020 (TC-50) confirmed still in the code (static check); TC-50 now `xfail(strict)`.
- P7: rider-free subset `uv run pytest tests/test_p7.py -k "<18 cases>"` → **30 passed, 0 failed** after one test-side fix (TC-15 accepted only SigV4 URLs; local MinIO signs SigV2 with a 600 s `Expires`). Cases ✅: TC-10, 11, 12, 15–22, 24–27, 32 (dashboard roles and store scope), 35, 36 (support SLA). Not run: ratings (TC-01–08), TC-13/14, TC-22b, TC-23 (DL-65 oracle), TC-30, dashboard KPIs/alerts/charts (TC-31, 33, 34).
- No 500 or traceback in the instance or worker log during 30 min of P5 traffic.

| Phase | Verdict | Why |
|---|---|---|
| **5** | **Not ready (gate incomplete)** | 5 P5 tests failed (COD UPI QR TC-88/89, unlock TC-93), cause not yet analysed; 78 tests not run this session; BUG-0013 (P3) open; device cases P5-TC-19, 33, 124, 131 pending. No P0/P1 bug open (BUG-0012 verified). |
| **6** | **Not ready (gate incomplete)** | T-612 cases (TC-14–16, 21–26, 34, 58, 59) not run this session; BUG-0020 (P3) open; device cases TC-17, TC-57 pending; profile cases TC-09, 20, 32, 33, 44 still ⏭. |
| **7** | **Not ready (gate incomplete)** | Executed P7 cases all pass (18/18), but ratings, DL-65 sales oracle, dashboard KPIs/alerts, erasure not yet run; admin P7 screens not merged (TC-40); device cases TC-37–39 pending. No P7 bug found so far. |

**Open bugs by severity:** P0 0 · P1 0 · P2 1 (BUG-0010) · P3 5 (BUG-0006, 0008, 0011, 0013, 0020). **No new bug filed in this session.**

**Observation (performance, local only):** each `realtime.broadcast_ws` / `publish_*` task takes a flat ~2 s in the QA worker (an order event fans out in 6–8 s). Against 09 §1 (offer < 3 s, location → map < 5 s) this needs a check on staging; on this machine it may be the remote DB or the Windows Redis channel layer. Not filed.

**Next session, in order:**
1. Start the instance (`bash qa/private/qa_instance.sh start local`) and worker; check R1/R2 are offline with 0 cash (`cleanup_rider` now deposits leftover cash, which caused "no offer within 25 s" failures earlier: R1 had reached ₹4,560 of ₹5,000).
2. `uv run pytest tests/test_p5_cash.py -k "tc88 or tc89 or tc93" -rfE` and analyse the 5 failures; file bugs if real.
3. Finish P5: `test_p5_kyc.py` (rest), `test_p5_ops.py` (incl. new SMQ case), `test_p5_security.py`, `test_p5_shift.py`, `test_p5_task_flow.py`, `test_p5_final.py`, `test_p5_db.py`; then timer profiles (`dispatchfast`, `riderclock`, `triggerplaced`).
4. P6: `uv run pytest tests/test_p6_ws.py tests/test_p6_t612.py`.
5. P7: the remaining `tests/test_p7.py` cases (ratings, TC-22b, 23, 30, 31, 33, 34).
6. 🔥 smoke P0–P7, then update 03–09.

## Phases 5, 6 and 7: QA stage 3 (2026-11-10, develop `efb3c3d` in QA worktree `b87eb5f`, QA instance :8004)
**Environment:** as in stage 2, with three changes:
- Redis URLs moved from `localhost` to `127.0.0.1` in the instance, the worker and the drivers (OBS-S3-01: `localhost` costs 2 s per new connection on this host).
- QA worker at 16 threads (`QA_WORKER_CONCURRENCY=16`; OBS-S3-02).
- MinIO and Mailpit were stopped at the start and were started through `infra/scripts/windows/dev-services.ps1`.

Backend code for delivery, realtime and orders is unchanged on develop `3f6fc42`. Admin P7 merged there (`6f92706`) but is not in the QA build.

**What ran (all output in `qa/private/runs/s3-*`):**
| Run | Result |
|---|---|
| `pytest tests/test_p5_cash.py -k "tc88 or tc89 or tc93" -rfE` | **6 passed** (the stage 2 failures were R1's cash at ₹4,560 of ₹5,000, so COD offers were skipped by DL-61b; no bug) |
| `test_p5_kyc.py` | 44 passed, 18 skipped, 3 xfailed, 2 failed (TC-14, TC-20: MinIO down). After restarting MinIO: **2 passed**. The 18 skipped + TC-01 run on a fresh rider (`QA_P5_KYC_PHONE=+919000000107`, `QA_P5_KYC2_PHONE=+919000000106`): **19 passed** |
| `test_p5_security.py` | first try 5 failed (R2 left with a rejected document by the TC-14 failure); after the repair, **24 passed** |
| `test_p5_shift.py` / `ops` / `task_flow` / `final` / `db` | **12 / 26 / 38 (+1 skip, riderclock) / 5 / 3 passed** |
| TC-79 on the `riderclock` profile | **1 passed** |
| `test_p6_ws.py` | **48 passed, 17 skipped** (profile/device stubs), **2 xfailed** (BUG-0020) |
| `test_p6_t612.py` | **6 passed, 2 xfailed** (BUG-0021 TC-59, BUG-0022 TC-14). Every other check in those two tests passes |
| `test_p7.py` rest (ratings TC-01…08, TC-13, 14, 22b, 23, 30, 31, 33, 34) | 22 passed, 2 failed (test defects); rerun **2 passed** |
| No 500 or traceback in the instance log; the worker log has no task errors (only the intended `qa.probe_latency` unregistered-task probes) | ✅ |
| 🔥 smoke P0–P4 + P6 + P7 (`-m smoke`, P5 files excluded: run in full above) | 109 passed, 2 failed, 27 errors (QA throttle state and 2 stale P1 oracles; see 09) → rerun of the 29: **29 passed**. Total **138 passed, 1 skipped, 2 xfailed (BUG-0021/0022)** |

**Test defects fixed (QA suite only):**
- P6-TC-40 oracle (`/rate` link, api-requests #55)
- P6-TC-31 (`task.status` on the ops feed)
- P6-TC-14 order race (B's order took R1's offer slot)
- P6-TC-14 leak filter (B's own ETAs)
- P6-TC-23 (expired the offer before `expires_at`)
- P6-TC-59 (`task.updated` is not sent for the rider's own actions, 06 §4.2)
- P5-TC-05 (`r1` fixture name)
- P7-TC-23 (`bill.grand_total`)
- P7-TC-07 (the customer-token oracle went beyond 06; OBS-06)

**Case status (`02`):**
| Phase | ✅ | ❌ | ⬜ | ⏭ | P0/P1 passed |
|---|---|---|---|---|---|
| 5 (132) | 105 | 1 (TC-16, BUG-0013) | 21 | 5 | 103 / 129 |
| 6 (59) | 47 | 3 (TC-14 BUG-0022, TC-50 BUG-0020, TC-59 BUG-0021) | 0 | 9 | 45 / 57 |
| 7 (38) | 34 | 0 | 0 | 4 (device ×3, TC-40 admin screens) | 33 / 37 |

**New bugs:** BUG-0021 (P2 Major, owner django-backend-dev): T9 pickup sends no `order.status` OUT_FOR_DELIVERY on the order socket or the ops feed. BUG-0022 (P3 Minor, django-backend-dev): `rider.location` heading always null. **No P0/P1 bug open.**

| Phase | Verdict | Why |
|---|---|---|
| **5** | **Not ready (gate incomplete)** | Every automated P5 case passes on the QA instance: no unauthorised access (IDOR TC-104…109 ✅), no stock or cash corruption (TC-66, 98, 128 SQL ✅), no duplicate payment (TC-90 ✅). But 21 cases have no execution yet, including P0 TC-12 (admin approval UI), TC-42 / 45 (accept races), TC-51 (T8a during a task) and TC-110 (signed links). The device cases (TC-19, 33, 124, 131) are with the PM. BUG-0013 (P3) is open. |
| **6** | **Not ready** | BUG-0021 (P2) breaks the live status at the hand-over: the customer's open order screen is not told OUT_FOR_DELIVERY (the push and SMS with the OTP still go). P0 cases TC-14 and TC-59 fail on BUG-0022 / BUG-0021, and TC-50 on BUG-0020. Device cases TC-17 and TC-57 are pending; profile cases TC-09, 20, 32, 33, 44 are ⏭. The 3 s live-latency targets (TC-11) pass only with the worker tuned (OBS-S3-02); confirm on staging. |
| **7** | **Ready for sign-off on the QA instance for the backend; formal gate pending** | 34/34 executable cases pass (ratings, support, reports incl. the DL-65 SQL oracle, dashboard KPIs/alerts/charts, erasure). Open: TC-40 (admin P7 screens: merged in develop `6f92706`, not yet tested by QA) and device cases TC-37–39. |

**For the PM:**
1. Send BUG-0021 and BUG-0022 to django-backend-dev. Both are one-line fixes with a test.
2. **OBS-S3-01: the :8001 stack and `docs/dev-environment.md` should use `redis://127.0.0.1:6380`.** Otherwise every live event on the user's phone pays about 2 s per Redis connection.
3. OBS-06: decide whether REST `/rider/*` must refuse a customer-app token (06 is silent).
4. The QA build needs develop `3f6fc42` merged for TC-40.

**Next QA session:** merge develop into the QA worktree; P7-TC-40; the remaining P5 ⬜ cases (P0 first: TC-12, 42, 45, 51, 110); the P6 profile cases; verify BUG-0021/0022 when fixed.

## Phases 5, 6 and 7: QA stage 4 (2026-11-10, develop f8db671)
**Build and environment:**
- QA worktree `qa/stage-4` at develop `f8db671`. It contains the admin P7 merge `6f92706` and the BUG-0021/0022 fix `ca8e69c`. The unmerged fixes in the `backend`, `backend2`, `backend3` and `admin` worktrees (BUG-0013, BUG-0020, P4 carry-overs, catalog loader) are **not** in this build and were not verified.
- **New Windows PC.** QA instance `127.0.0.1:8004`, run in place from the worktree's clean `backend/` (`qa/tools/instance.sh` now supports Windows: `netstat` + `taskkill`, no `.env` copy). Redis `127.0.0.1:6380` DBs 5/6/7 only, MinIO `127.0.0.1:9000`, shared remote DB (read-only SQL from QA).
- QA Celery worker (threads, 16) and a **separate QA beat** (`qa/private/qa_celery.sh`, gitignored), both on the QA broker DB 7. The beat uses celery's file scheduler, so it never writes the shared DB's django-celery-beat tables.
- Mailpit is not installed (no email case was in scope). Port 8001 (another project) was never touched.
- Profiles used: `local`, `s4timers` (new: dispatchfast timers + a 40 s auto-accept delay + a 20 s acceptance SLA), `triggerplaced` (+ the 40 s delay), `wsrecheck` (5 s socket re-checks), `shortsession`.
- Everything was stopped at the end of the session.

**What ran (outputs in `qa/private/runs/s4-*`):**
| Run | Command (from `qa/`) | Result |
|---|---|---|
| BUG-0021 / BUG-0022 re-check | `uv run pytest tests/test_p6_t612.py -k "tc14 or tc59 or tc34"` | **3 passed** (both bugs **Verified**) |
| P7-TC-40, admin P7 screens | `uv run pytest tests/test_p7_console.py` | 4 passed + 1 test defect (API field `from_support`), rerun **3 passed**, then **1 passed** (XSS probe). **8/8 sub-cases pass** |
| P5 P0 cases | `uv run pytest tests/test_p5_stage4.py` | TC-12 **passed**. TC-45, TC-51, TC-110 **passed** (TC-51 and TC-110 after two test fixes: rider pushes are keyed by `task_id`; the old PC's KYC files are not in this MinIO, OBS-S4-01). TC-42 **xfailed**: BUG-0023, new. TC-42b **xfailed**: BUG-0023 |
| P5 P1/P2 rest (local) | `uv run pytest tests/test_p5_stage4b.py tests/test_p6_stage4.py -k "not tc09 and not tc20 and not tc32"` | 10 passed, 1 skipped (TC-77: invoice 503, no GTK runtime), 3 failed. TC-58: oracle mixed in the old PC's morning orders. TC-18: test shift point outside the geofence. TC-117: BUG-0024, new. Rerun: **2 passed** (TC-58, TC-18), TC-117 **xfailed** (BUG-0024) |
| `s4timers` | `uv run pytest tests/test_p5_stage4_profiles.py -k "tc38a or tc47"` | **2 passed**. TC-47 rerun with R1 kept fresh: **1 passed** (DL-61 (e) confirmed) |
| `triggerplaced` | `-k tc38b` | **1 passed** |
| `wsrecheck` | `uv run pytest tests/test_p6_stage4.py -k "tc20 or tc32"` | **2 passed** |
| P6-TC-09 | real 15 min token expiry on an open socket | **1 passed** |
| `shortsession` (BUG-0006) | `uv run pytest tests/test_p1_staff_session.py -k tc95b` | **1 passed**. BUG-0006 **Verified** |
| P5 SQL invariants after the session | `uv run pytest tests/test_p5_db.py` | **3 passed** (QA-02 stock, cash ledger, task/order consistency) |
| 🔥 smoke P0–P7 | `uv run pytest -m smoke` (local) | Not recorded (the session ended before the result was written; noted 2026-11-16) |
| Logs | instance and worker logs of the session | No 500. The only 5xx were 2 invoice 503s (documented degradation). The tracebacks in the log are the 403 `PermissionDenied` refusals of the role tests. Worker ERROR lines are the SLA alerts of old PLACED orders in the shared DB (by design) |

**Case status (`02`, totals table "QA stage 4"):**
| Phase | Cases | ✅ | ❌ | ⬜ | ⏭ | Pri P0/P1 passed | All passed |
|---|---|---|---|---|---|---|---|
| 5 | 133 (+ TC-42b) | 121 | 4: TC-16 (BUG-0013), TC-42 and TC-42b (BUG-0023), TC-117 (BUG-0024) | 2: TC-50 (b), TC-92 | 6: device TC-19, 33, 124, 131; TC-77 (no GTK runtime on this PC); TC-132 (P6/D-19) | 118 / 129 | 91.0 % |
| 6 | 59 | 53 | 1: TC-50 (BUG-0020) | 0 | 5: device TC-17, 57; TC-44 (no fault-injection backend); TC-45, 54 (config review) | 51 / 57 | 89.8 % |
| 7 | 38 | 35 | 0 | 0 | 3: device TC-37–39 | 34 / 37 | 92.1 % |

**Bugs:**
- **Verified:** BUG-0021 (P2, OUT_FOR_DELIVERY on the order socket and the ops feed); BUG-0022 (P3, heading); BUG-0006 (P3, staff session idle/absolute timeline).
- **New:**
  - **BUG-0023** (P3 Minor / Low, owner `django-backend-dev`): a late accept after the server processed the offer expiry answers 409 `OFFER_TAKEN` ("taken by another rider") instead of `OFFER_EXPIRED` when no other rider took the task. The race itself is safe in 10/10 trials.
  - **BUG-0024** (P2 Major / Medium, owner `admin-panel-dev`): a Store Manager gets 403 on the admin "Change cash limit" action for their own store's riders, although DL-61 (a) and the service allow it. Ops and Super Admin are the workaround.
- **Still open, fix not in this build:** BUG-0013 (P3), BUG-0020 (P3).
- **Open by severity:** P0 0 · P1 0 · P2 1 (BUG-0024) · P3 3 (BUG-0013, BUG-0020, BUG-0023). No P0/P1 bug is open.

**What the P0 cases showed:**
- **No unauthorised access.** Role matrices hold server-side for every role:
  - the dashboard, reports (index, page, CSV, export download), support console and ratings admin (P7-TC-40);
  - force offline, cash limit and unlock OTP (P5-TC-117; the only deviation is the too-strict BUG-0024);
  - the admin rider approval pages (P5-TC-12).
- **Store scoping:** the GGN-01 manager never sees QA-02 numbers, tickets, ratings, alerts or riders. Signed links only work as issued and expire (P5-TC-110). Customer text is escaped in the console (P7-TC-40g).
- **No duplicate money or stock corruption:**
  - T8a during a task: COD due = oracle, the old amount is refused, one unit is committed (P5-TC-51).
  - Day-end cash report = SQL (P5-TC-97).
  - Races: accept ‖ expiry never leaves ASSIGNED + EXPIRED (TC-42); manual assign ‖ accept binds exactly one rider (TC-45).
- **No crash:** no 500 in the session.

| Phase | Verdict | Why |
|---|---|---|
| **5** | **Not ready** | 1. Pri P0 TC-42 fails on BUG-0023 (P3: wrong 409 code, safe state) and P0 TC-16 on BUG-0013 (P3, fix not merged). §5.2 needs 100 % of P0/P1 cases: fix both, or the PM waives them as P3. 2. P1 TC-117 fails on BUG-0024 (P2). 3. TC-92 and TC-50 (b) were not run. 4. The device cases (TC-19, 33, 124, 131) are with the PM. 5. TC-77 needs a host with the GTK runtime (staging). All P5 money, stock, IDOR and race invariants hold. |
| **6** | **Not ready (gate incomplete)** | BUG-0021 and BUG-0022 are verified, and every executable P6 case passes except TC-50 (BUG-0020, P3, fix not in this build). Open: device cases TC-17 and TC-57; TC-44 (no fault-injection backend); config reviews TC-45 and TC-54. 89.8 % < 95 %. |
| **7** | **Ready for sign-off on the QA instance (backend + admin console); formal gate pending** | 35/35 executable cases pass, including P7-TC-40 (all 8 console sub-cases). No P7 bug is open. Remaining: device cases TC-37–39 (PM) and the staging run. |

**For the PM:**
1. Send **BUG-0023** to django-backend-dev (one check reordered, plus a test) and **BUG-0024** to admin-panel-dev (the cash-limit action needs its own rider lookup).
2. Merge the BUG-0013 and BUG-0020 fixes, then QA re-verifies P5-TC-16 and P6-TC-50 (both are xfail-strict guards, so they turn XPASS).
3. **OBS-S4-01:** this PC's MinIO has no files for KYC rows uploaded on the old PC. R1/R2 photo and document links answer 404 here. Re-upload, or copy the bucket, before device tests that show rider photos.
4. **OBS-S4-02:** invoices need WeasyPrint's GTK runtime on this PC (or test them on staging).
5. QA data changes this stage (QA numbers only):
   - QA F (+919000000106) is now an **ACTIVE rider at QA-02** (P5-TC-12 approved it through the admin).
   - QA H (+919000000108) was registered, then deleted and anonymised (P5-TC-18). Its 4 KYC documents were purged by the guarded driver op, which refuses to run if any non-QA rider is due.
   - QA G (+919000000107) re-uploaded PHOTO and PAN (still PENDING_KYC).

**Next QA session:** P5-TC-92 and TC-50 (b); re-verify BUG-0013, BUG-0020, BUG-0023 and BUG-0024 when merged; device cases with the PM; staging.

## Fresh verdicts P0–P7 on main (2026-11-16, main `f6ed556`, worktree `qa/main`)
**Build and environment:** main `f6ed556` (contains the stage-4 QA work and the BUG-0013 / BUG-0020 fixes). QA instance `127.0.0.1:8004`, run in place from the worktree's clean `backend/` (`qa/tools/instance.sh`), profiles `local`, `clock`, `redis-down`, plus `local` with `QA_EXTRA_ENV="DISPATCH_RETRY_SECONDS=300 DISPATCH_TIMEOUT_SECONDS=900 COD_QR_EXPIRY_SECONDS=20"` for the new P5 cases. Redis `127.0.0.1:6380` DBs 5/6/7, MinIO `127.0.0.1:9000`, shared remote DB (read-only SQL from QA). Port 8001 and jqc.jivo.in were never touched. The instance was stopped at the end.

**Blocker found at the start (OBS-M-01, reported to the PM mid-run):** the shared DB lacks six main migrations (`catalog` 0004–0006, `promotions` 0002, `referrals` 0001, `stores` 0005). On main, home, products, search, suggest, collections, the cart and every order flow answer **500**, as do the admin banner, inventory and stock-movement pages. This is an environment state, not a product bug, and QA may not migrate. **Consequence: P3–P7 could not be regression-tested on main, and every P2 catalog case and P5-TC-50 (b) / TC-92 are blocked.**

**What ran (outputs in `qa/private/runs/m1-*`):**
| Run | Command (from `qa/`) | Result |
|---|---|---|
| BUG-0013 / BUG-0020 re-check | `uv run pytest tests/test_p5_kyc.py -k tc16` / `tests/test_p6_ws.py -k tc50` | 4 strict xfails turned **XPASS**; markers removed, rerun **5 passed, 1 skipped**. Both bugs **Verified** |
| P5-TC-50 (b), P5-TC-92 (new `tests/test_p5_main.py`) | `QA_EXTRA_ENV=… uv run pytest tests/test_p5_main.py` | **5 errors at set-up**: `DELETE /api/v1/cart/ -> 500` (OBS-M-01). Not executed |
| P0 + P1 | `uv run pytest tests/test_p0_foundation.py tests/test_p1_*.py` | 178 passed, 9 skipped (profile cases), **18 failed**: all test-side (address_write throttle, Windows path, `cp1252` read of the schema, 3 stale oracles after T-219 / T-814 M2, user C is now rider R1). After the fixes: **31/31 passed**. Net: **196 passed, 0 failed, 9 skipped** |
| P2 serviceability, DB, security | `uv run pytest tests/test_p2_serviceability.py tests/test_p2_db.py tests/test_p2_security.py` | 81 passed, 8 failed → after the per-store grid fix to TC-03: **82 passed, 7 failed** (all 7 on the 500s of OBS-M-01) |
| P2 catalog | `uv run pytest tests/test_p2_catalog.py` | **16 passed, 27 failed, 1 skipped**: every failure is a 500 of OBS-M-01 (categories, the 404 and validation sub-cases pass) |
| P2 new cases | `uv run pytest tests/test_p2_main.py` | TC-08 ✅, TC-52 ✅ (61st request 429); TC-53 role matrix: **every refusal correct**, allowed banner/inventory/movement pages 500; TC-54 blocked (adjust page 500) |
| P2 `clock` | `QA_FAKE_NOW=…T23:30 … -k tc09`; `…T22:59:15 … -k tc11` | TC-09 blocked (home 500); **TC-11 passed** |
| P2 `redis-down` | `uv run pytest tests/test_profile_redis_down.py` | 4 passed (P0-TC-03b, P1-TC-63/63b/63c); P2-TC-12b blocked (home 500) |
| 🔥 smoke P0–P7 | `QA_WORKER_CONCURRENCY=16 uv run pytest -m smoke` | **94 passed, 20 failed, 64 errors, 3 skipped, 1 xfailed** (14 min). Every error (set-up of P3–P7 order flows: `DELETE /cart/` 500) and 19 of the 20 failures are OBS-M-01. The 20th, P6-TC-29 [Catalog Manager → 4403], was a QA helper defect: the server now closes with 4403 before the client's first frame, and `ops_close_code` raised on the send. Fixed; rerun **7/7 passed**. P0/P1 smoke: all pass. The xfail is a known-bug guard (not itemised: the run used `-rfs`) |
| Logs | instance logs of the session | The only 500s are the `ProgrammingError`s of OBS-M-01. No other traceback |

**Test changes (QA suite only, no product code):** `conftest.py` clears the T-814 per-IP scopes before each test (`keep_throttles` marker opts out); P2-TC-03 grid per store; P0-TC-11 and `qa_support.schema()` read the schema as UTF-8; P1-TC-26b finds `local.py` in place on Windows; P1-TC-24c expects T-814 M2 (reuse revokes the family); P1-TC-60 expects 403 `APP_HEADER_MISMATCH` (T-219); P1-TC-37 takes user C's rider status from the DB; BUG-0013 / BUG-0020 guards are plain asserts. New: `test_p2_main.py` (P2-TC-08, 52, 53, 54), `test_p5_main.py` (P5-TC-50 b, 92 a–d).

**Record sync:** `02`, `08` and this report now agree with the bug files: BUG-0001…0012, 0021, 0022 Verified (earlier runs); BUG-0013 and BUG-0020 Verified today; BUG-0023 and BUG-0024 Open (fixes in progress, PM). The ❌ rows still pointing at verified bugs (P0-TC-08b, P1-TC-04/13/14b/24c/52/57/96, P4-TC-32/33/40) are ✅. P3-TC-64 is ✅ from the user's phone run on 2026-11-04 (T-306, PM; not executed by QA). The stage-4 `SMOKE_*` placeholders in 09/10 were never filled and are marked "not recorded".

**Case status (`02`, after this session):**
| Phase | Cases | ✅ | ◐ | ❌ | ⬜ | ⏭ | Pri P0/P1 passed | All passed | Last regression on this build |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 25 | 22 | 0 | 0 | 1 (TC-23 CI) | 2 (TC-21/22 apps build, client) | 16 / 19 | 88.0 % | ✅ main `f6ed556` |
| 1 | 105 | 86 | 0 | 0 | 13 (device) | 6 (TC-45, 46, 61, 62, 67, 93) | 81 / 98 | 81.9 % | ✅ main `f6ed556` |
| 2 | 57 | 26 | 3 | 0 | 26 (19 blocked by OBS-M-01, 2 not automated, 5 device) | 2 (TC-12, 22) | 25 / 54 | 45.6 % | partial on main (blocked) |
| 3 | 69 | 67 | 0 | 0 | 0 | 2 (TC-26, 63 → P4 by DL-50) | 65 / 67 | 97.1 % | `9ed7ffc`; **blocked on main** |
| 4 | 60 | 49 | 1 (TC-60) | 0 | 7 (device) | 3 (TC-16, 17, 57) | 47 / 56 | 81.7 % | `f744508`; **blocked on main** |
| 5 | 133 | 122 | 0 | 3 (TC-42, 42b BUG-0023; TC-117 BUG-0024) | 2 (TC-50 b, 92: blocked) | 6 | 119 / 129 | 91.7 % | `f8db671`; **blocked on main** |
| 6 | 59 | 54 | 0 | 0 | 0 | 5 (device TC-17, 57; TC-44, 45, 54) | 52 / 57 | 91.5 % | `f8db671` (TC-50 on main) |
| 7 | 38 | 35 | 0 | 0 | 0 | 3 (device TC-37–39) | 34 / 37 | 92.1 % | `f8db671`; **blocked on main** |

**Open bugs:** P0 0 · P1 0 · P2 1 (BUG-0024) · P3 1 (BUG-0023). **New bugs this session:** none.

| Phase | Verdict | Why |
|---|---|---|
| **0** | **Not ready (gate incomplete)** | Backend criteria met and re-passed on main; no open bug. Not passed: P0-TC-21/22 (app build and generated client: Flutter not run by QA) and P0-TC-23 (CI evidence). 88 % < 95 %. |
| **1** | **Not ready (gate incomplete)** | No ❌ any more: every bug-linked case passes on main (BUG-0002/0003/0005/0007 re-checked). Not passed: 13 device cases (P1-TC-80…92), P1-TC-61/62 (426 and 503 need a QA-owned `AppConfig`), P1-TC-67 (the admin role-matrix test is still a skip stub), P1-TC-46 (30-day anonymisation). 81.9 %. |
| **2** | **Not ready (blocked)** | No product defect found, and no unauthorised access (TC-44, every TC-53 refusal) or stock/money corruption (TC-45–47 SQL). But 19 cases, including 9 Pri P0 🔥 catalog cases (TC-21, 23, 26–28, 30, 31) and the stock-adjustment case TC-54, are blocked by OBS-M-01. Device cases TC-58–62 are with the PM. 45.6 %. |
| **3** | **Not ready on main** (was Ready for sign-off on the QA instance at `9ed7ffc`) | 97.1 % with every P0 case passed, P3-TC-64 included. But §5.2 needs the smoke set to pass on the build under gate, and on main the cart and checkout answer 500 (OBS-M-01). Re-run the P3 smoke and the payment/refund files after the migrations. |
| **4** | **Not ready** | Device cases TC-51–54, 56, 58 (four P0) are ⬜; TC-16/17/57 still need a DELIVERED order with a working invoice host (OBS-S4-02). Not regression-tested on main (OBS-M-01). |
| **5** | **Not ready** | P0 TC-42 fails on BUG-0023 (P3, safe state, wrong code) and P1 TC-117 on BUG-0024 (P2); both are being fixed. TC-50 (b) and TC-92 are written but blocked. Device cases TC-19, 33, 124, 131 and TC-77 (GTK runtime) remain. BUG-0013 is now Verified (TC-16 ✅). |
| **6** | **Not ready (gate incomplete)** | BUG-0020 is Verified, so every executable P6 case passes (54/54). Remaining: device TC-17 and TC-57 (both P0), TC-44 (no fault-injection backend), TC-45/54 (config reviews). 91.5 % < 95 %. The order-socket regression on main needs order flows (OBS-M-01). |
| **7** | **Not ready on main** (Ready for sign-off on the QA instance at `f8db671`, backend + console) | 35/35 executable cases pass, no P7 bug. But main was not regression-tested (orders blocked by OBS-M-01), and device cases TC-37–39 remain. |

**For the PM:**
1. **Apply the six main migrations to the shared DB** (shared-db-migrate, with the user's approval). Until then any :8001 from main answers 500 on the catalog and the cart, on the phone too. Then send QA back: P2 blocked cases (TC-21, 23–34, 37–39, 41b, 53, 54, 09/10, 12b, 55), P5-TC-50 (b) and 92, and the P3–P7 smoke and order flows on main.
2. BUG-0023 / BUG-0024 / DL-74: QA re-tests after your follow-up (P5-TC-42, 42b, 117; the rider API refusing a customer-app token).
3. Doc question: 05 §3 has no row for the notify-me leads screen (P2-TC-57).
4. OBS-M-03 (expired COD QR credit accepted in code, not reproduced): P5-TC-92c will decide once unblocked.

**Device cases still owed (PM, phone):** P1-TC-80…92 (13); P2-TC-58–62 (5, new); P4-TC-51–54, 56, 58 (6); P5-TC-19, 33, 124, 131 (4); P6-TC-17, 57 (2); P7-TC-37–39 (3). Also P0-TC-21/22 (app builds and the generated client, any Flutter-capable run).

## Run 2 on main (2026-11-16, after the DL-76 migrations; QA worktree `e50426c` = main `f6ed556` code)
**Environment:** as in run 1. The six migrations were applied to the shared DB by the PM with the user's approval (DL-76); `showmigrations` shows none pending.

| Run | Command (from `qa/`) | Result |
|---|---|---|
| P5-TC-50 (b), TC-92 | `QA_EXTRA_ENV="DISPATCH_RETRY_SECONDS=300 DISPATCH_TIMEOUT_SECONDS=900 COD_QR_EXPIRY_SECONDS=20" uv run pytest tests/test_p5_main.py` | **4 passed, 1 failed.** TC-50 (b) ✅ (offer 3.3 s after packing, retry still 3 min away). TC-92 a, b, d ✅. **TC-92c ❌ → BUG-0025** (new; OBS-M-03 confirmed) |
| All P2 suites (local) | `uv run pytest tests/test_p2_serviceability.py tests/test_p2_db.py tests/test_p2_security.py tests/test_p2_catalog.py tests/test_p2_main.py` | **136 passed, 2 failed, 1 skipped.** TC-38: the image fetch 404s because this PC's MinIO lacks the files (OBS-M-05, environment). TC-57: Store Manager 403 against the PM default (OBS-M-04, decision) |
| P2 `clock` TC-09/10 | `QA_FAKE_NOW=2026-11-16T23:30:00+05:30` | **1 passed** |
| `redis-down` (TC-12b + P0/P1) | `uv run pytest tests/test_profile_redis_down.py` | **5 passed** |
| P3–P7 suites | `uv run pytest tests/test_p3_*.py … tests/test_p7*.py` | **Not completed: stopped by Claude Code because the PC ran critically low on memory** (about 50 min in, around 14:30). The pipe buffered the output, so **no per-test results exist**, and none are claimed. From the instance log of the run (13:40–14:30, 14,700 lines): one 500 (`POST /orders/`, `psycopg.OperationalError: server closed the connection unexpectedly`, a shared-DB connection drop, OBS-01 class); every other traceback is a 403 the role tests expect. Not restarted, following the memory guard |
| 🔥 smoke P0–P7 | — | **Not run in run 2** (memory, as above). Run 1's smoke was blocked by OBS-M-01 for P3–P7 |

**New bug:** [BUG-0025](../bugs/BUG-0025.md) (P3 Minor / Low, django-backend-dev): a payment on an expired, unreplaced COD UPI QR is accepted as PAID instead of being refunded (08 T10, 06 §2 slice 5.4). No money is lost; the risk is a customer who pays cash after seeing "expired" and then also by UPI. **Open:** P0 0 · P1 0 · P2 1 (BUG-0024) · P3 2 (BUG-0023, BUG-0025).

**Case status changes:**
- P2 run 2: **46/57 (80.7 %)**, Pri P0/P1 45/54; ❌ 1 (TC-57, PM default); ◐ 2 (TC-38, 55); ⬜ 6 (TC-56 not automated; TC-58–62 device); ⏭ 2.
- P5: TC-50 ✅; TC-92 ❌ (BUG-0025); now 123/133 = 92.5 %.

| Phase | Verdict (run 2) | Why |
|---|---|---|
| **0** | **Not ready (gate incomplete)** | Unchanged: TC-21/22 (Flutter build and generated client) and TC-23 (CI) |
| **1** | **Not ready (gate incomplete)** | Unchanged: 13 device cases; TC-61/62 (QA-owned AppConfig); TC-67 stub; TC-46 |
| **2** | **Not ready (gate incomplete)** | No product defect: catalog, home, search, stock never exact, money as 2-dp strings, the admin role matrix and stock adjustment all pass on main. Remaining: device TC-58–62 (three P0), TC-56 (CSV) not automated, TC-57 needs the leads-role decision (OBS-M-04), TC-38's image fetch on staging, TC-55 tier pricing without tier data. 80.7 % < 95 % |
| **3** | **Not ready on main** | The P3 suites were in the killed run: no result on main. Last good result: `9ed7ffc`, 97.1 % |
| **4** | **Not ready** | Device cases; not regression-tested on main (killed run) |
| **5** | **Not ready** | BUG-0023, BUG-0024 (in progress) and new BUG-0025 (TC-92); device cases; full suite on main not completed |
| **6** | **Not ready (gate incomplete)** | Device TC-17, 57; TC-44, 45, 54; full suite on main not completed |
| **7** | **Not ready on main** | Device TC-37–39; full suite on main not completed |

**Still owed on main (needs a relaunch when memory allows, PM's call):** the P3–P7 suites and the 🔥 smoke set. Suggestion: one phase per run, with `QA_WORKER_CONCURRENCY=4`, and output written straight to the file (no pipe) so a stop keeps the partial result.
