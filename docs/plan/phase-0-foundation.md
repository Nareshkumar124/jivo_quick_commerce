# Phase 0: Foundation

**Status summary (as of 2026-11-14)**
1. **Build:** done. Phase 0 was pushed in `4960527` (roadmap: built 2026-11-02, gate not passed).
2. **QA:** run 1 on 2026-11-02 gave 21 of 25 cases passed. Verdict: **Not ready (gate incomplete)**. QA did not check the app builds, the generated client or CI.
3. **Bugs:** none open. BUG-0001 (the only fail) was fixed in `96a2117` and verified in QA run 2.
4. **Gate:** open. No formal gate on staging, no demo, no sign-off (H-11 is "Not Started").
5. **Staging:** `jqc.jivo.in` is now live with HTTPS (`9e10f01`, `c339294`). Staging shows only water products since 2026-11-11 (other categories hidden on purpose). This does not matter for Phase 0.

**Goal:** the local stack runs, CI is green, and the schema to `jivo_api` pipeline works end to end (`development-phase.md` §3).

**Needs (decisions):** D-05 hosting, D-06 package IDs, D-13 generate the client (decided, DL-05), D-18 GitHub, D-19 Firebase + Sentry, D-23 unfold (decided). See "Open questions".

Sources: `docs/development-phase.md` §3, `docs/plan/00-roadmap.md`, `docs/task-tracker.md`, `docs/decision-log.md`, `qa/docs/02-test-case-repository.md`, `qa/docs/10-release-readiness-report.md`.

---

## 1. Scope

| Area | What Phase 0 delivers |
|---|---|
| **Backend** | Project skeleton (split settings, Celery, beat, Channels). `apps/core` (error envelope, pagination, client-info middleware). `apps/accounts` with the custom `User` and the reserved `auth_id`. `/health/live`, `/health/ready`. drf-spectacular at `/api/schema/` and `/api/docs/`. Local stack files, Dockerfile, `uv` with pinned versions. ruff and pytest config, a `seed_demo` skeleton, backend CI. A stub `GET /api/v1/config/app/` to prove the pipeline. |
| **Admin panel** | django-unfold admin installed and reachable at `/admin/` (login page only; real screens start in Phase 1). |
| **Customer app** | Scaffold run (R0) that also created the shared `packages/jivo_core` and `packages/jivo_api`. `jivo_core` basics (theme tokens, dio client with the client-info headers, flavors, error mapping, analytics wrapper). `customer_app` with flavors `dev` / `staging` / `prod`, router and l10n. Flutter CI. The D-13 spike and `packages/tool/generate_api.sh`. |
| **Rider app** | `rider_app` skeleton (flavors, bootstrap, router, l10n). Risk spike: Android foreground service with background location and a full-screen notification. |
| **Layout change** | At the user's request the apps moved from a `mobile/` pub workspace to top-level `customer_app/`, `rider_app/` and `packages/` with path dependencies (DL-04). |

---

## 2. Task checklist

The task tracker has **no Phase 0 rows**. These tasks come from `development-phase.md` §3. A `[x]` means the work is in the Phase 0 push `4960527` (roadmap: built), unless another hash is shown. QA verification is noted where it is missing.

**Backend**
- [x] Project skeleton: split settings, Celery, beat, Channels wiring (`4960527`)
- [x] `apps/core`: error envelope, pagination, client-info middleware (`4960527`)
- [x] `apps/accounts` custom `User` with `auth_id` in the first migration (`4960527`)
- [x] `/health/live` and `/health/ready` (`4960527`; P0-TC-01/02 pass)
- [x] drf-spectacular `/api/schema/` and `/api/docs/` (`4960527`; P0-TC-10/11 pass)
- [x] Local stack: compose file, env examples, Dockerfile, pinned `uv` versions (`4960527`; P0-TC-20 pass)
- [x] ruff and pytest config, `seed_demo` skeleton (`4960527`)
- [x] Backend CI: Postgres + PostGIS and Redis services, ruff, `makemigrations --check`, schema diff (`4960527`; QA did not check CI)
- [x] First contract: `GET /api/v1/config/app/` stub (`4960527`; final version came in Phase 1)

**Admin panel**
- [x] django-unfold admin installed (`4960527`; P0-TC-18 pass)

**Customer app**
- [x] R0 scaffold: `jivo_core` and `jivo_api` packages (`4960527`; moved to top-level folders, DL-04)
- [x] `jivo_core` basics and `customer_app` flavors, router, l10n (`4960527`)
- [x] Flutter CI (`4960527`; QA did not check CI)
- [x] D-13 spike, `generate_api.sh`, compiling `jivo_api` (`4960527`, DL-05; QA did not check, P0-TC-22 deferred)

**Rider app**
- [x] `rider_app` skeleton (`4960527`)
- [ ] Risk spike report on the foreground service and full-screen notification. No report found in the sources (a foreground location service later landed in P5, T-515, `305942b`, `130b42a`).

**DevOps and human steps**
- [x] Staging server `jqc.jivo.in` with HTTPS (T-220, `9e10f01`, `c339294`)
- [x] Secret and dependency scanning in CI (T-231, `5a48518`; extra, not in the original scope)
- [ ] Formal gate for P0 and P1: staging run, demo, sign-off (H-11, Not Started)
- [ ] Jivo long-lead items: DLT, Razorpay, Play and Apple accounts, domains (SMS/DLT is H-06, Not Started)

**Count: 17 done / 20 total.**

---

## 3. Test cases

Full steps and expected results: [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (section "Phase 0"). Key: 🔥 smoke case. Layer: BE backend, ADM admin, CUS/RID apps. Status is from QA run 1 (2026-11-02, a QA instance with staging-like settings, not a deployed staging) unless noted.

| ID | Title | Pri | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P0-TC-01 🔥 | `GET /health/live` | P0 | BE | ✅ local + staging | |
| P0-TC-02 🔥 | `GET /health/ready` | P0 | BE | ✅ | |
| P0-TC-03 | Health probes ignore auth, never throttled | P1 | BE | ✅ | |
| P0-TC-03b | Redis down gives 503, no driver text | P1 | BE | ✅ | |
| P0-TC-04 🔥 | Unknown URLs give a JSON 404 (DEBUG off) | P1 | BE | ✅ staging | |
| P0-TC-05 | Wrong HTTP method gives 405 envelope | P1 | BE | ✅ | |
| P0-TC-06 | Wrong content type gives 415 | P1 | BE | ✅ | |
| P0-TC-07 | `Accept: application/xml` gives 406 | P2 | BE | ✅ | |
| P0-TC-08 | Broken JSON gives 400 | P1 | BE | ✅ | |
| P0-TC-08b | Body over 2.5 MB never gives 500 | P2 | BE | ❌ run 1; fixed `96a2117`, verified in run 2 (case row not re-recorded) | [BUG-0001](../../qa/bugs/BUG-0001.md) |
| P0-TC-09 | A 500 shows no traceback | P1 | BE | ✅ | |
| P0-TC-10 | Schema and docs pages are protected on staging | P1 | BE | ✅ local + staging | |
| P0-TC-11 | Served schema equals committed `schema.yaml` | P2 | BE | ✅ | |
| P0-TC-12 🔥 | Contract inventory: 17 P0/P1 operations, strict responses | P0 | BE | ✅ (one gap, fixed: BUG-0004) | [BUG-0004](../../qa/bugs/BUG-0004.md) |
| P0-TC-13 | Bad client headers are ignored | P2 | BE | ✅ | |
| P0-TC-14 | Security headers on API responses | P2 | BE | ✅ | |
| P0-TC-15 | `check --deploy` with production settings | P1 | BE | ✅ | |
| P0-TC-16 | Secrets scan of tracked files | P0 | BE | ✅ | |
| P0-TC-17 | `pip-audit` clean | P1 | BE | ✅ | |
| P0-TC-18 | `/admin/` redirects anonymous users to login | P1 | ADM | ✅ | |
| P0-TC-19 | Times are ISO 8601 UTC | P2 | BE | ✅ | |
| P0-TC-20 | Redis, MinIO and Mailpit services up | P2 | BE | ✅ | |
| P0-TC-21 | Both apps build the `dev` flavor and reach the backend | P1 | CUS/RID | ⏭ deferred (no Flutter run) | |
| P0-TC-22 | `jivo_api` compiles, `flutter analyze` clean | P1 | CUS | ⏭ deferred | |
| P0-TC-23 | Backend and mobile CI green on `main` | P1 | BE/CUS | ⬜ not run | |

**Count (QA run 1): 25 cases. 21 pass, 1 fail (fixed since), 2 deferred, 1 not run.** Pass rate 84%, below the 95% gate.

---

## 4. Exit criteria

From `development-phase.md` §3 (Phase 0 exit) and `10-testing-strategy.md` §5.2.

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | `docker compose ... up` is healthy | Met | P0-TC-20 pass in run 1. Note: the current dev PC has no Docker and uses native services (`docs/dev-environment.md`). |
| 2 | Both CIs are green | Not met | Not verified by QA (P0-TC-23 not run). Roadmap notes "CI green" for the same commit under P1; no CI link in the sources. |
| 3 | The generated client compiles | Not met | Dev reports it built; QA did not check (P0-TC-22 deferred). |
| 4 | Both apps build `dev` and reach the backend | Not met | QA did not check (P0-TC-21 deferred). Later phone tests on staging show the apps run, but that is not a Phase 0 test record. |
| 5 | All tasks done or deferred with owner and target | Not met | The risk spike report is open; H-11 gate is open. |
| 6 | Phase cases on staging: 100% of P0/P1 priority passed, 95% of all | Not met | 21 of 25 (84%). P0-TC-21/22/23 are Pri P1 and not passed. Run was on a QA instance, not on staging. |
| 7 | Smoke set (P0-TC-01, 02, 04, 12) passed | Met | All four pass. |
| 8 | No open P0/P1 bugs | Met | None open. BUG-0001 is closed. |
| 9 | Documentation updated | Not met | Not checked as a whole. The test case file notes that `docs/plan/` did not exist until now. |
| 10 | Demo done and sign-off recorded | Not met | Both pending. |

---

## 5. Demo script (for a non-developer, on staging)

Needs: a browser and a phone with the staging build of the customer app. About 10 minutes. Phase 0 has nothing to see for shoppers, so the demo shows "the system is alive".

1. Open `https://jqc.jivo.in/health/live` in a browser. **You should see:** `{"status":"ok"}`.
2. Open `https://jqc.jivo.in/health/ready`. **You should see:** status ok, with database ok and redis ok.
3. Open `https://jqc.jivo.in/admin/`. **You should see:** the Jivo admin login page. Do not log in (Phase 1 covers that).
4. Open `https://jqc.jivo.in/health/nothing-here`. **You should see:** a plain "not found" page, with no technical details.
5. Open the customer app (staging build). **You should see:** the splash screen, then the next screen (login or onboarding). That proves the app reached the server.
6. Ask the PM for the build and version shown on screen, and note them in the sign-off.

Stop and report if any step shows an error page with code or file names.

---

## 6. Sign-off

```
Phase 0 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

---

## 7. Open questions

1. **Hosting (D-05):** doc 11 recommends AWS ap-south-1, but staging is a shared Linux server at `jqc.jivo.in`. Is that the final hosting, or only the test server? (`project-status.md` calls it the test server.)
2. **Firebase and Sentry (D-19):** doc 11 lists the status as "decided" (🔵) but the sources do not say whether the Sentry init and Firebase projects exist. Not confirmed.
3. **CI proof:** the roadmap says CI was green at `4960527` (under P1), but QA's report says CI was not verified. Which counts for the gate?
4. **Risk spike:** no written result for the rider foreground-service spike. Should it be closed as superseded by T-515?
5. **Test case file:** `qa/docs/02` titles itself "Phases 0, 1, 3, 4 and 5" and still says `docs/plan/` does not exist. QA should update it.
6. **Rows not re-recorded:** P0-TC-08b and P0-TC-12 still show their run 1 result in `qa/docs/02`, though their bugs were verified fixed in run 2.
7. **Branch conflict in docs:** `CLAUDE.md` says `main` holds only gated work, but `main` already holds Phase 2 work that passed no gate (DL-34, DL-36).
