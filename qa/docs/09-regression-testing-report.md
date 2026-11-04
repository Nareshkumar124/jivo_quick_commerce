# 09: Regression Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`.

This is the first QA run, so it establishes the regression baseline.

## Smoke set (🔥)
The smoke set is marked with `@pytest.mark.smoke` in `qa/tests/`. Run it with `uv run pytest -m smoke`.

| Phase | 🔥 cases | Automated | Result |
|---|---|---|---|
| P0 | P0-TC-01, 02, 04, 12 | ✅ | ✅ local and staging |
| P1 (backend) | P1-TC-01, 06, 08, 14, 21, 24, 28, 33, 39, 42/43, 47, 53, 55, 58, 60, 64 | ✅ | ✅ local (all, in every run). Staging: 20 passed, plus 1 expected error (P1-TC-64 admin login needs HTTPS cookies on staging settings). |
| P1 (apps) | P1-TC-80, 82, 85, 87, 89, 91 | ❌ (device) | ⬜ not run (no devices this run) |

## Known-bug guards
Open bugs are encoded as `xfail(strict=True)`. When a fix lands, the test turns into XPASS(strict), the suite fails, and the case must be re-verified and the marker removed.
- BUG-0001: `test_p0_tc08b`
- BUG-0002: 6 parametrised cases (P1-TC-04, 13, 52), plus a private guard (P1-TC-14b)
- BUG-0003: a private guard (P1-TC-24c)

The private guards live in `qa/private/tests/` (gitignored, security-sensitive) and run with `uv run pytest private/tests`. Move them back to `qa/tests/` once the bugs are fixed.
- BUG-0007: `test_p1_tc57` (non-strict: intermittent race)

## Fixes verified
None yet: there are no fixes to verify in run 1.

## Final regression run (2026-11-02)
`1 failed, 181 passed, 11 skipped, 13 deselected, 9 xfailed, 1 error in 207.81s`:
- the failure was the BUG-0007 race (new bug, filed)
- the error was a remote-DB timeout during a fixture (OBS-01)

The smoke set was unaffected.

## Next regression run
- **Phase 2 gate:** re-run the full `qa/tests` suite (P0/P1 regression), the smoke set on staging, and the fix verification for BUG-0001…0007.
- The suite is re-runnable: `qa/tools/instance.sh start local <commit>`, then `uv run pytest`. Counters are cleared automatically in QA Redis DB 5 only.

## Phase 3 stage 1 (2026-11-04, `c2c153a`)
- **Smoke P0–P3:** `72 passed, 1 skipped` (the skip is P0-TC-04, staging profile only). P3-TC-43 was run separately: ✅.
- **New P3 🔥 cases:** P3-TC-01, 02, 09, 10, 12, 20, 21, 22, 24, 27, 29, 33, 34, 35, 36, 38, 43, 44, 48, 49, 50.
- **New known-bug guard:** BUG-0009, `test_p3_tc57` (`xfail(strict=True)`).
- **Full P0–P2 regression:** not re-run in this stage; only the smoke set was. Run the whole suite after the R2b/T-304 merges.
- **Re-run after the R2b merge:** the full P3 suite, `QA_SLOW=1` P3-TC-47, the BUG-0009 fix check, and a P3 perf baseline.
- **Re-run after the T-304 merge:** P3-TC-59/60, plus P3-TC-61 using a QA-owned coupon created in admin.

## Phase 3 stage 2 (2026-11-04, `f84482f`)
- **Smoke P0–P3:** `73 passed, 1 skipped`, plus P3-TC-43 `1 passed`. P3-TC-59 joined the 🔥 set.
- **Fixes verified:** BUG-0009; its guard is now a normal assertion.
- **Full P0–P2 regression:** not re-run (smoke only). Run it at the phase gate on staging.
- **Pending:**
  - re-check the refund cases after the refund fix run
  - P3-TC-64 on the user's phone
  - re-verify BUG-0008 (residual fix in `41f02f6`)

## Phase 3 refund re-check (2026-11-04, `9ed7ffc`, T-310)
- **Smoke P0–P4:** `77 passed, 13 skipped` (12 P4 stubs awaiting R2, 1 staging-profile case). New 🔥 cases: P4-TC-44 and 45 (SQL money and stock invariants), both pass on develop.
- **Affected area re-run:** the P3 payments suite (`13 passed`), P3-TC-47 slow (`1 passed`), the new refund-ordering cases P3-TC-65…69 (all pass).
- **Full P0–P2 regression:** not re-run (smoke only). Run it at the phase gate on staging.
- **Still pending:** P3-TC-64 on the user's phone; re-verify BUG-0008 (residual fix in `41f02f6`).
