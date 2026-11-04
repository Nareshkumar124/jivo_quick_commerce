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
