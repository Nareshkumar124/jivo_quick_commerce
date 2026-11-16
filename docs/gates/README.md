# Phase gate sign-off pack (Phases 0–7)

**Prepared:** 2026-11-16 by the PM session · **Code checked:** `main` at `8e42ec0` (2026-11-10), `develop` at `14d638f` (one docs-only commit ahead of `main`).

This folder helps you, the owner, sign off each finished phase. There is one page per phase (`P0.md` … `P7.md`). Each page shows:
- what was built and where the code is;
- what the testers (QA) checked and what they found;
- what is still missing;
- an empty box for your decision.

**No phase is signed off yet.** There are no `phase-N-done` tags, and the sign-off log in `docs/plan/00-roadmap.md` is empty.

## Summary

| Phase | What it is | QA test result (latest) | Open bugs | Phone tests still owed | What is left before you can sign | Ready to sign? |
|---|---|---|---|---|---|---|
| **P0** | Foundation (servers, tools, auto-checks) | 22 of 25 pass (88%); QA said "Not ready" | None | 2 (both apps build and start) | QA to record the app-build and auto-check results; fix the auto-checks; demo | Nearly: paperwork only |
| **P1** | Login, profile, addresses, staff roles | 85 of 105 pass (81%) after bug re-checks; QA said "Not ready" (before the fixes) | 1 small (BUG-0006, fixed, partly re-checked) | 12 (login, profile, addresses, rider login) | Phone tests; 4 skipped test cases; QA re-run and new verdict; fix auto-checks; demo | No |
| **P2** | Stores, catalog, stock, home, search | No QA case list or verdict (QA run 2 stopped part-way) | None | Not defined yet | QA to write and run the Phase 2 case list; give a verdict; fix auto-checks; demo | No |
| **P3** | Cart, checkout, payments | 67 of 67 pass (2 cases moved to P4 and passed there); QA said "Ready for sign-off" | None | None (passed on your phone 2026-11-04) | Fix the auto-checks (CI is red); demo; your sign-off | **Yes, after CI is fixed and a demo** |
| **P4** | Store order handling, refunds, invoices | 49 of 60 pass (82%) after bug re-checks; last QA verdict "Not ready" | None | 6 (orders list, order detail, cancel, reorder, cancel test, full COD order) | Phone tests; invoice tests (need a delivered order); store-staff trial; new QA verdict; CI; demo | No |
| **P5** | Riders and delivery | 105 of 132 pass (80%); QA said "Not ready" | 1 small (BUG-0013) | 4 (rider sign-up, going online, customer tracking, full delivery run) | 21 test cases not yet run (5 high priority); phone tests; rider trial; CI; demo | No |
| **P6** | Live tracking and notifications | 47 of 59 pass (80%); QA said "Not ready" | 1 medium (BUG-0021) + 2 small (BUG-0020, BUG-0022). Fixes for 0021 and 0022 are in the code but not re-checked | 2 (app with no internet connection) | QA to re-check the two fixes; fix BUG-0020; 9 skipped cases; phone tests; Firebase for real push (D-19); CI; demo | No |
| **P7** | Dashboard, reports, support, ratings | 34 of 38 pass (89%); QA said "Ready" for the backend | None | 3 (rate an order, support ticket with photo, rider help pages) | QA test of the new admin screens; phone tests; decide on Jivo staff login (SSO, D-04); CI; demo | No |

Notes on the counts:
- **"After bug re-checks"** means a bug was fixed and QA proved the fix in its bug report, but QA has not yet updated the test-case table (`qa/docs/02-test-case-repository.md`). Each phase page shows both numbers. QA should update the table before you sign.
- The bug summary in `qa/docs/08-bug-tracking-report.md` (2026-11-10) still lists BUG-0006, 0008, 0010 and 0011 as open. Their own bug files say they were fixed and verified on 2026-11-09. This pack goes by the bug files. QA should sync the summary.

## Things that affect every phase

| Item | State | Evidence |
|---|---|---|
| **Automatic checks (CI)** | **Red** on the current code. On `main` `8e42ec0` (2026-11-10), the app checks pass, but the backend checks fail (the "Env example lists every variable" and "Django system check" steps) and the infra checks fail (the PowerShell restore-script test). The backend check has failed on every `main` push since `4960527`. | GitHub Actions runs 42794639132 (backend), 42794638985 (infra), 42794639150 (mobile) |
| **Testing on the staging server** | **Not done.** Every QA run so far used QA's own test copy on the dev PC (`127.0.0.1:8004`), not a staging deployment. The `jqc.jivo.in` test server is live, but QA has not run a phase there. For Phase 3 you already agreed that staging can come later (DL-50). You can choose the same for the other phases. | `qa/docs/10-release-readiness-report.md`; DL-50 |
| **Smoke tests** (quick re-check that old features still work) | **Passed on the QA test copy.** 138 passed, 0 failed (2026-11-10, build `efb3c3d`), covering P0–P4, P6 and P7. The P5 smoke cases passed inside the full P5 runs. Not yet run on staging. | `qa/docs/09-regression-testing-report.md`, stage 3 |
| **Demo** | **None given or recorded** for any phase. | Roadmap sign-off log is empty |
| **Per-phase plan files** | **Missing.** `docs/plan/phase-N-*.md` (task list, demo script) were never written. QA's test-case file stands in for them. | `docs/plan/00-roadmap.md` |
| **High-severity bugs** (P0 or P1) | **None open** in any phase. | Bug files in `qa/bugs/` |

## Suggested order
1. **Get the automatic checks green** (DevOps and backend). Every phase needs this.
2. **Sign off P3.** It is the only phase where QA said ready and nothing else is owed except CI and a demo.
3. **P0 and P1:** QA updates the counts and records the app builds; you do the P1 phone tests (about 30 minutes).
4. **P7, then P4, then P2:** small QA runs plus phone tests.
5. **P5 and P6:** QA finishes the remaining cases and re-checks the bug fixes; then the rider phone run.

## How to sign a phase
1. Read the phase page. Look at **"What is left"**.
2. Decide: **Approve**, **Approve with conditions** (write the conditions, for example "staging run later"), or **Not approved**.
3. Fill in the **Owner decision** box at the bottom of the page (name, date, decision), or tell the PM and the PM will fill it in for you.
4. The PM then records it in the roadmap sign-off log and tags the code `phase-N-done`.

## Words used in this pack
- **QA:** the independent tester agent. It tests the system from outside, like a user would.
- **Test case:** one written check, for example "a wrong OTP is refused". Each has an ID like `P3-TC-12`.
- **Priority P0/P1:** the most important test cases. The rule is that all of them must pass.
- **Bug severity:** P0 Blocker, P1 Critical (both block sign-off), P2 Major, P3 Minor, P4 Trivial (do not block).
- **CI:** the automatic checks GitHub runs on every code change (code style, tests, build).
- **Staging:** a copy of the real system on a server, used for final testing.
- **Phone test:** a test only a person with the app on a phone can do.
- **Mini-UAT:** a short trial by real users (store staff in P4, riders in P5).
