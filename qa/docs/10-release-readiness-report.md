# 10: Release Readiness Report

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
