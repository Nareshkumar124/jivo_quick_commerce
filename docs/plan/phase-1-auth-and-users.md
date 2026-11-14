# Phase 1: Auth & Users

**Status summary (as of 2026-11-14)**
1. **Build:** done. OTP login, profile, devices, addresses, account deletion, app config and staff roles are in `4960527` (built 2026-11-02). Tracker rows T-101 to T-104 are still "Testing", not "Completed".
2. **QA:** run 1 (2026-11-02): 78 pass, 8 fail, 6 deferred, 13 not run, out of 105. Verdict **Not ready**. In QA run 2 the bugs behind 7 of the 8 failing cases were verified fixed. The case rows were not re-recorded.
3. **Bugs:** 0 open P0/P1/P2. One P3 open: BUG-0006 (staff session length), partly verified on 2026-11-09.
4. **Gate:** open. The 13 phone cases (T-214) are "Not Started". No staging run, demo or sign-off (H-11).
5. **Staging:** `jqc.jivo.in` is live. Staging shows only water products since 2026-11-11 (on purpose). Login and profile screens are not affected.

**Goal:** OTP login works on both apps, and staff log in with roles.

**Needs (decisions):** D-02 SMS (console backend meanwhile; Twilio trial skipped, DL-48), D-04 staff SSO (decide later; staff use Django session login now), D-15 fixed-OTP test numbers.

Sources: `docs/development-phase.md` §3, `docs/plan/00-roadmap.md`, `docs/task-tracker.md`, `docs/decision-log.md`, `docs/10-testing-strategy.md` §5/§8, `qa/docs/02-test-case-repository.md`, `qa/docs/08-bug-tracking-report.md`, `qa/docs/10-release-readiness-report.md`.

---

## 1. Scope

| Area | What Phase 1 delivers |
|---|---|
| **Backend** | The `06 §2.1` auth and account endpoints (OTP request and verify, refresh, logout, `me`, devices, delete account) and the `06 §2.2` address endpoints. Final `config/app` with the 426 (update required) and 503 (maintenance) guard. OTP rules (hashed codes, limits, throttles, fail closed when Redis is down, DL-13). simplejwt rotation and blacklist (access 15 min, refresh 30 days). `Device`, `Address` with soft delete. Groups per `05 §3` and staff session login with lockout. `anonymise_deleted_accounts`. `seed_demo` with staff per role and the fixed-OTP test numbers. IDOR tests on addresses. |
| **Admin panel** | Users & roles, Customers (basic, with Block and Unblock), CMS app config. Role groups per `05 §3` (7 roles). |
| **Customer app** | Session layer in `jivo_core` (secure storage, refresh once on 401, logout when refresh fails, 426 handler). Splash, onboarding, login, OTP screen (6 digits, autofill, 30 s resend), +91 validation, consent text, profile, basic addresses (no map), logout, delete account, offline banner. |
| **Rider app** | Permissions gate and location module (lookahead). Login and OTP with `X-App-Name: rider`, force update and maintenance screens, routing by `rider_status` with a placeholder when there is no rider profile. |

Related rules decided in this phase: staff log in with email + password (DL-06), OTP login during the 30-day deletion grace period restores the account (DL-07), email conflicts give a generic message (DL-08), consent is recorded as `terms_version` (DL-10), any phone can log in to the rider app and `rider_status` routes it (DL-11).

---

## 2. Task checklist

`[x]` = merged. Merged in the Phase 0+1 push `4960527` unless another hash is shown. The tracker status is shown when it is not "Completed".

**Backend**
- [x] T-101 P1 backend: OTP auth, JWT, `me`, devices, addresses, deletion, config 426/503, staff roles, lockout (`4960527`; tracker: Testing)
- [x] SMS behind an interface with a console backend (`4960527`)
- [x] Twilio SMS backend for OTP (T-308, `88692a1`; live SMS is off, DL-48)
- [x] Address PATCH can clear the receiver name and phone (T-205, Completed)
- [x] Fix BUG-0001 to BUG-0005 and BUG-0007 (`96a2117`; tracker: Completed, QA verified in run 2)
- [x] Fix BUG-0008, notify-me privacy (tracker: Completed, QA verified 2026-11-09, `10dbae4`)
- [x] Token `app` claim enforced (T-219, `9742d40`; tracker: Testing)
- [x] ER diagram with the P1 entities (T-204, `9742d40`, Completed)
- [ ] BUG-0006: staff session 8 h absolute and 2 h idle for admin roles (tracker: Testing; the idle timeline is not re-run)
- [ ] DB connection reuse or pooling (T-218, In Progress; pool added in `96a2117`, not enabled)

**Admin panel**
- [x] Users & roles, Customers (basic), CMS app config, 7 role groups (`4960527`)
- [ ] Role matrix tested page by page for all 7 roles (P1-TC-67; T-213, In Progress)

**Customer app**
- [x] T-102 `jivo_core` session layer (`4960527`; 75 tests; tracker: Testing)
- [x] T-103 login, profile, addresses, delete account (`4960527`; 62 tests and the real-API integration test; tracker: Testing)

**Rider app**
- [x] T-104 login and routing by status (`4960527`; 112 tests and the real-API integration test; tracker: Testing)

**QA**
- [x] T-212 QA run 1: P0/P1 verification, 130 cases, 7 bugs (`94854f7`, Completed)
- [ ] T-214 Device test of the P1 apps (Not Started)
- [ ] Re-run the P1 cases on staging, including the smoke set

**Human steps**
- [x] D-15 fixed-OTP test numbers `+919000000001` to `+919000000003` (local and test settings only)
- [ ] Formal gate: staging run, demo, sign-off (H-11, Not Started)
- [ ] Real config values: support phone and email, policy URLs, store URLs, terms version (H-05, Not Started)
- [ ] SMS provider and DLT (H-06, Not Started)
- [ ] OTP per-IP limits confirmed (H-07, Not Started)
- [ ] Consent at login: text or checkbox (H-09, Not Started)

**Count: 14 done / 24 total.**

---

## 3. Test cases

Steps and expected results: [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (section "Phase 1"). Layer: BE backend, ADM admin, CUS/RID apps. 🔥 smoke case. Status is from QA run 1 (2026-11-02, QA instance, not deployed staging) unless noted. "Fixed" means the bug was verified fixed in QA run 2 but the case row was not updated.

**Totals: 105 cases. 78 pass, 8 fail, 6 deferred, 13 not run.** Passed: 74%, below the 95% gate.

| ID | Title | Pri | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P1-TC-01 🔥 | OTP request | P0 | BE | ✅ | |
| P1-TC-04 | Non-ASCII digits in phone | P1 | BE | ❌ then fixed | [BUG-0002](../../qa/bugs/BUG-0002.md) |
| P1-TC-06 🔥 | Verify with a test OTP, tokens issued | P0 | BE | ✅ | |
| P1-TC-08 🔥 | 5 wrong codes then locked | P0 | BE | ✅ | |
| P1-TC-13 | Verify input validation | P1 | BE | ❌ then fixed | [BUG-0002](../../qa/bugs/BUG-0002.md) |
| P1-TC-14 🔥 | OTP send rate limit (429) | P0 | BE | ✅ | |
| P1-TC-14b | Security guard for BUG-0002 | P1 | BE | ❌ then fixed | [BUG-0002](../../qa/bugs/BUG-0002.md) |
| P1-TC-21 🔥 | Rider-app login | P0 | RID/BE | ✅ (re-run `efb3c3d`, 2026-11-10) | |
| P1-TC-24 🔥 | Refresh and reuse of old refresh token | P0 | BE | ✅ | |
| P1-TC-24c | Security guard for BUG-0003 | P1 | BE | ❌ then fixed | [BUG-0003](../../qa/bugs/BUG-0003.md) |
| P1-TC-28 🔥 | Logout | P0 | BE | ✅ | |
| P1-TC-33 🔥 | `GET /me/` exact fields | P0 | BE | ✅ | |
| P1-TC-39 🔥 | Register the same device token twice | P1 | BE | ✅ | |
| P1-TC-42 🔥 | Delete account with OTP | P0 | BE | ✅ | |
| P1-TC-43 🔥 | Sign in again in the grace period restores the account | P0 | BE | ✅ | |
| P1-TC-45 | Staff cannot delete via `/me/delete/` | P2 | BE | ⏭ no black-box path | |
| P1-TC-46 | Anonymise job after 30 days | P1 | BE | ⏭ needs time travel | |
| P1-TC-47 🔥 | Create first and second address | P0 | BE | ✅ | |
| P1-TC-52 | Non-ASCII digits in PIN code and receiver phone | P2 | BE | ❌ then fixed | [BUG-0002](../../qa/bugs/BUG-0002.md) |
| P1-TC-53 🔥 | Set default address, exactly one default | P0 | BE | ✅ | |
| P1-TC-55 🔥 | Address IDOR: another user gets 404 | P0 | BE | ✅ | |
| P1-TC-57 | Concurrent set-default keeps one default | P0 | BE | ❌ then fixed | [BUG-0007](../../qa/bugs/BUG-0007.md) |
| P1-TC-58 🔥 | `config/app` per app and platform | P0 | BE | ✅ | |
| P1-TC-60 🔥 | No 426 on partial or old client headers | P0 | BE | ✅ | |
| P1-TC-61 | 426 when version is below the minimum | P0 | BE | ⏭ shared AppConfig must not change | |
| P1-TC-62 | 503 maintenance mode | P0 | BE | ⏭ same reason | |
| P1-TC-64 🔥 | Super Admin login at `/admin/login/` | P0 | ADM | ✅ (local run) | |
| P1-TC-67 | Role matrix per page, 7 roles | P0 | ADM | ⏭ admin UI was being reworked | |
| P1-TC-80 🔥 | Customer cold start, splash, config, onboarding | P0 | CUS | ⬜ phone run needed | |
| P1-TC-81 | Force update, dismissible prompt, maintenance screen | P0 | CUS/RID | ⬜ phone + test config | |
| P1-TC-82 🔥 | Login: +91 check and consent text | P0 | CUS | ⬜ phone | |
| P1-TC-83 | OTP screen: autofill, resend, error messages | P0 | CUS | ⬜ phone (autofill needs real SMS) | |
| P1-TC-84 | New user must enter a name | P1 | CUS | ⬜ phone | |
| P1-TC-85 🔥 | Session: secure storage, silent refresh | P0 | CUS/RID | ⬜ phone (static review ok) | |
| P1-TC-86 | Logout clears local data | P1 | CUS | ⬜ phone | |
| P1-TC-87 🔥 | Delete account and re-login notice | P0 | CUS | ⬜ phone | |
| P1-TC-88 | Profile edit | P1 | CUS | ⬜ phone | |
| P1-TC-89 🔥 | Addresses: list, add, edit, delete, default | P0 | CUS | ⬜ phone | |
| P1-TC-90 | Offline banner | P2 | CUS | ⬜ phone | |
| P1-TC-91 🔥 | Rider login and routing by `rider_status` | P0 | RID | ⬜ phone (API side ✅) | |
| P1-TC-92 | Rider force update and maintenance | P1 | RID | ⬜ phone | |
| P1-TC-93 | Re-run both apps' login integration tests | P1 | E2E | ⏭ no Flutter run | |
| P1-TC-95 | Staff session lifetime (8 h, 2 h idle) | P2 | ADM | ❌ run 1; cookie expiry verified 2026-11-09, idle not re-run | [BUG-0006](../../qa/bugs/BUG-0006.md) |
| P1-TC-96 | Production refuses console SMS backend | P1 | BE | ❌ then fixed | [BUG-0005](../../qa/bugs/BUG-0005.md) |
| P1-TC-02, 03, 05, 07, 09 to 12, 15 to 20, 22, 23 | Other OTP and sign-in rules (enumeration, limits, spoofed IPs, test numbers, rate-limit keys, blocked customer) | P0 to P1 | BE/ADM | ✅ all pass | |
| P1-TC-24b, 25 to 27, 28b, 29 to 32 (incl. 26b, 26c, 31b) | Tokens and sessions (tampered, expired, cookie-only, logout of other users) | P0 to P2 | BE | ✅ all pass | |
| P1-TC-34 to 38, 40, 41 | Profile and devices | P0 to P2 | BE | ✅ all pass | |
| P1-TC-44 | Delete account validation | P1 | BE | ✅ | |
| P1-TC-48 to 51, 54, 55b, 56 | Addresses: list, fields, coordinates, delete, fuzz | P0 to P2 | BE | ✅ all pass | |
| P1-TC-59, 63 | Config exempt paths, Redis down | P0 to P1 | BE | ✅ | |
| P1-TC-65, 66, 68, 71 | Staff lockout, role groups, CSRF, block and unblock | P0 to P1 | ADM | ✅ all pass | |
| P1-TC-69, 70, 71b, 72 to 75 | Database checks (read-only SQL) | P0 to P2 | BE | ✅ all pass | |
| P1-TC-76 to 79, 94 | Strict schema, logs without PII, performance baseline, fuzzing, static app review | P0 to P1 | BE/CUS/RID | ✅ all pass | |

Notes:
- Cases still open for the gate: the 13 phone cases (TC-80 to 92), the 6 deferred ones (TC-45, 46, 61, 62, 67, 93) and TC-95.
- Every other P1 case in the file passed in run 1.
- Later QA stages (up to stage 3, `3a59367`) re-ran P1 smoke cases on the QA instance as part of the regression set (138 passed, 1 skipped, 2 expected failures for BUG-0021/0022). They were not run on `jqc.jivo.in`.

---

## 4. Exit criteria

| # | Criterion | Met? | Evidence |
|---|---|---|---|
| 1 | All phase tasks done or deferred with owner and target | Not met | Built and merged, but T-214 (phone test), T-213 (role matrix) and BUG-0006 are open. T-101 to T-104 are "Testing", not "Completed". |
| 2 | CI green (lint, tests, coverage, migrations, schema) | Met at `4960527` | Roadmap: "CI green". Dev reports 318 backend tests at 99% coverage. QA did not re-run the suite. Not re-checked on current `develop`. |
| 3 | Phase cases on staging: 100% P0/P1-priority pass, 95% of all | Not met | 78 of 105 (74%) in run 1, on a QA instance. Open P0/P1-priority cases: TC-61, 62, 67, 80 to 89, 91, 92. |
| 4 | Regression smoke set (from previous phases) passed | Not met | Passed on the QA instance only. Not run on staging. |
| 5 | No open P0/P1 bugs | Met | P0 0, P1 0. Open: BUG-0006 (P3). |
| 6 | Documentation updated | Not met | ER diagram and the `06` address contract were updated (T-204, T-205). Not checked as a whole. |
| 7 | Demo done and sign-off recorded | Not met | H-11 Not Started. |
| 8 | Login works on both apps on a real phone | Not met | The real-API integration tests pass (T-103, T-104). The P1 phone cases were never executed. The user's phone did run login for the P3 order test (P3-TC-64), which is not a P1 record. |
| 9 | 426 and 503 verified with a QA-owned config | Not met | TC-61 and TC-62 are deferred. |

---

## 5. Demo script (for a non-developer, on staging `jqc.jivo.in`)

Needs: a phone with the **staging** build of the customer app, a second phone or the same phone with the rider app, a laptop browser, and the PM. Test phone numbers send **no SMS**. Use `+919000000001` with OTP `123456` (also `+919000000002` and `+919000000003`). Staff passwords are given by the PM in person; never write them down here. Note: only water products show on staging. That is on purpose.

**Part A: customer app**
1. Open the customer app. **You should see:** a splash screen, then the welcome screens (first time) and the login screen.
2. Type `9000000001` (the app adds +91). **You should see:** the consent text with links, and the Continue button works only for a full 10-digit number.
3. Type a short number like `12345`. **You should see:** the app refuses it.
4. Continue with the right number. On the OTP screen type `123456`. **You should see:** you are signed in. A new user is asked for a name first.
5. Open Account, then Profile. Change the name and save. **You should see:** the new name saved. The phone number cannot be edited.
6. Open Addresses and add an address. **You should see:** it is saved and marked default. Add a second one and make it default. **You should see:** only one default.
7. Delete the first address. **You should see:** it disappears from the list.
8. Log out. **You should see:** the login screen. Log in again with the same number. **You should see:** the same account and name.
9. (Use `+919000000003`, not your main test number.) Delete the account with an OTP. **You should see:** the login screen. Log in again with the same number. **You should see:** a notice that the deletion was cancelled and the account is restored.

**Part B: rider app**
10. Open the rider app and log in with a number that has no rider profile (ask the PM which test number is free). **You should see:** login works and the app shows the rider sign-up or placeholder screen, not the home screen.

**Part C: staff panel (laptop)**
11. Open `https://jqc.jivo.in/admin/` and sign in as the Super Admin (the PM gives the password). **You should see:** the admin dashboard.
12. Open Customers, find `+919000000003`, and use Block. Then try to log in on the app. **You should see:** "This account is deactivated." Use Unblock and log in again. **You should see:** it works.
13. Open Users & roles. **You should see:** 7 staff roles.

Stop and report any error page that shows code, file names or a crash.

---

## 6. Sign-off

```
Phase 1 sign-off
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

1. **Stale case statuses:** `qa/docs/02` keeps the run 1 result for 7 cases whose bugs were verified fixed in run 2 (TC-04, 13, 14b, 24c, 52, 57, 96). QA should re-record them. The 78 / 8 / 6 / 13 totals above are the run 1 totals.
2. **BUG-0006:** `qa/docs/08` lists it as "Open". The tracker says "Testing" and the bug file says "Fixed, partially verified". Which is right? Also, `qa/docs/08` still shows BUG-0008 as "Open", but the tracker and the bug file say it is verified (2026-11-09).
3. **Tracker status:** T-101 to T-104 say "Testing" because the tracker needs QA verification for "Completed". Should the PM move them after the phone cases run?
4. **Consent (H-09):** the demo shows consent as text (DL-10). Jivo has not confirmed text or checkbox.
5. **Test numbers for the rider demo:** the sources do not say which fixed-OTP number has no rider profile (QA says one QA user became rider R1 in P5). Ask the PM.
6. **Staff session rule (DL-39):** 8 h cap for everyone plus 2 h idle for admin roles. `qa/docs` earlier said "fixed 12 h". Confirm the idle timeline once it is re-run.
7. **Phone tests need the phone build:** the P1 phone cases were planned for an emulator (T-214), but the project has no emulator (user instruction 2026-11-03). Use the USB phone.
8. **Real SMS:** the console SMS backend runs on staging and Twilio is off (DL-48). Test numbers do not need SMS, but real customers will (H-06).
