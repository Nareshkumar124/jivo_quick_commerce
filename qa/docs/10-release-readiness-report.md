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
