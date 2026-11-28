# Phase 8: Hardening & launch

Goal (`development-phase.md` §3): production go-live after the pilot and UAT. Each agent hardens its own area in parallel. Needs D-05 (production), D-15 (reviewer account) and every long-lead item in `11 §2`. The go-live list is [`../release-checklist.md`](../release-checklist.md).

## Status summary (as of 2026-11-14)
1. **Started early (DL-58).** Merged: OWASP fixes (`1015790`), Locust harness (`842e632`), backup/restore and monitoring (`4b30378`), CI secret and dependency scans (`5a48518`), customer and rider hardening (`abd2c6d`, `e225b8f`).
2. **Staging is live** at `https://jqc.jivo.in` with HTTPS (deploy `9e10f01`, HTTPS `c339294`). It is staging only. There is no production.
3. **Not run yet:** the load test, the full-data restore test on staging, device and network matrix, store releases, pilot week, UAT.
4. **Blocked on people:** D-05 production hosting (needs the user's OK), D-11 store accounts, D-02 DLT and SMS, D-01 Razorpay live keys, D-15 reviewer number, dark store, riders, legal pages.
5. **Gate: not started.** The release checklist is almost entirely unticked, and P0 to P7 are not yet 🏁 in the roadmap.

---

## 1. Scope

### Backend (`backend/`)
- OWASP API Top 10 review and fixes: refund caps (DL-59), stale-payment guard, `NUM_PROXIES`, lockout per username, throttles, PII scrub (T-814).
- Locust load test: 50 orders/min and 500 concurrent sessions, with p95 targets from `09 §1` (reads < 300 ms, order placement < 800 ms, serviceability < 150 ms). Harness refuses localhost:8001 and the shared DB (T-812).
- `check --deploy` and `pip-audit` (the second is a CI gate).
- Staff two-step sign-in (TOTP) per DL-59 and DL-70.

### Admin panel
- Ops Console fixes found on staging (T-232).
- Staff TOTP screens and enrolment rule (DL-70). Browser check: Chrome, Firefox, Edge, and tablet Chrome for the packing console (`10 §4`).

### Customer app
- Device and network matrix (`10 §4`), release build with `--obfuscate --split-debug-info`, Android release (Play) and iOS submission (App Store).
- Hardening (T-230): sign-out data clearing, stale ids, error handling, `allowBackup` off, HTTPS-only network config.

### Rider app
- Low-end and aggressive-OEM device runs, the Play background-location review and video, release build.
- Hardening (T-229): 7 bugs fixed, `allowBackup` off.

### DevOps (`infra/`, `.github/workflows/`)
- Backup and restore (PITR, daily dump, guarded restore, verifier), monitoring as code, deploy-time checks, edge limits, secrets and rotation (`deployment.md` §7 to §11).
- CI secret and dependency scanning (T-231). Staging deploy (T-220). Production stack and `deploy-production.yml` wait on D-05.

### Launch (human steps)
- Pilot week with real orders to employees (`10 §7`), UAT sign-off by a Jivo business owner.
- Dark store ready, riders recruited and approved, full catalog, legal pages, Razorpay live keys and webhook, DLT approved, store listings.
- Release tag, deploy window, rollback owner, 72 h monitoring.

## 2. Task checklist
Sources: `docs/task-tracker.md`, `plan/00-roadmap.md`, `release-checklist.md`. Ticked means merged (hash given). Nothing here is QA-Completed unless stated.

### Built and merged
- [x] T-814 OWASP API Top 10 fixes. Merged `1015790`. QA verification pending.
- [x] T-812 Locust harness and guarded load-test seed/cleanup. Merged `842e632`.
- [x] T-813 Backup/restore, monitoring as code, deploy-time checks, edge limits. Merged `4b30378` (CI keys `03cbd8b`, nginx upload cap `7dc9b49`).
- [x] T-220 Staging readiness and deploy. Merged `9e10f01`; HTTPS live `c339294`.
- [x] T-231 CI secret and dependency scanning. Merged `5a48518`.
- [x] T-230 Customer P8 hardening. Merged `abd2c6d` (open: rest of CA-07, CA-08, 11, 13, 14, 18, 19, 20, 22, 24 to 27, 30).
- [x] T-229 Rider P8 hardening. Merged `e225b8f` (open: RA-05, 15, 16, 22 and the rest of the text-scale matrix).
- [x] T-232 Ops Console htmx trigger fix. Merged `3a42b4d`. Staging hotfix still waits on the user's OK.
- [x] T-219 Enforce the token `app` claim. Merged `9742d40` (review: Approve with fixes; follow-ups open).
- [x] BUG-0013 and BUG-0020 fixes. Merged `2f7c942`. QA re-verification pending.
- [x] T-402c and T-403c carry-overs. Merged `64dc6ce`.

### Open (not done)
- [ ] Run the load test on staging (T-812 says "load run on staging pending").
- [ ] Full-data restore test on staging with `restore_db.sh --verify` plus one PITR restore, recorded in `deployment.md` §7.3 (T-813: "restore test on staging pending").
- [ ] QA verification of T-814 (OWASP fixes).
- [ ] Confirm the historical `rzp_test_` key id in Razorpay (T-231 follow-up). Decide how PR scans pick their scanner config.
- [ ] Staging hotfix for T-232 (needs the user's OK).
- [ ] Remaining UX audit findings: customer CA list above, rider RA list above.
- [ ] Rider and customer release configuration check (`--obfuscate --split-debug-info`), size budget, cold-start, battery and memory profiling.
- [ ] Device and network matrix runs (`10 §4`): low-end Android, Realme/Xiaomi, recent Samsung/Pixel, older and recent iPhone, 3G and airplane-mode toggling.
- [ ] D-05 production hosting decision and production stack (needs the user's approval).
- [ ] `deploy-production.yml` (`main` only, two reviewers, `production` environment).
- [ ] D-11: Google Play Console and Apple Developer accounts. Play listing, App Store listing, data safety and privacy labels, reviewer test account, account-deletion link, background-location declaration and video.
- [ ] D-15 reviewer number (single allow-listed number, sandbox store). Production refuses `OTP_TEST_NUMBERS` otherwise.
- [ ] D-02 SMS provider and DLT: entity, sender ID, templates approved, real OTP SMS delivered.
- [ ] D-01 Razorpay live keys after KYC, live webhook (`deployment.md` §5). Drain pending ONLINE orders before enabling auto-capture (`release-checklist` §7).
- [ ] D-19 Firebase and Sentry projects for production.
- [ ] D-04 Jivo Auth (if Jivo IT decides). H-14 rotate the DB server SSH password. H-03 make the GitHub repo private.
- [ ] GST invoice data (D-12), FSSAI and Legal Metrology info on products, full product catalog with photos (H-18).
- [ ] Dark store ready (location, polygon, tablet, printer, staff). Riders recruited, approved, cash limits set.
- [ ] Pilot week, feedback fixed, UAT signed by a Jivo business owner.
- [ ] Phase gates P0 to P7 passed (🏁) with sign-off in `plan/00-roadmap.md` (the sign-off log is empty).
- [ ] Release tag, deploy window, rollback owner named, production smoke test, 72 h monitoring.

## 3. Test cases
`qa/docs/02-test-case-repository.md` has **no `P8-TC` ids** today (count: 0). Do not invent ids. The kinds of tests below are **to be written by QA**.

| Kind of test (to be written by QA) | Source | Layer | Status |
|---|---|---|---|
| Regression of all 🔥 smoke cases P0 to P7 on staging (`10 §5`) | 10 §5, §6 | E2E | To be written / run by QA |
| End-to-end order flows on staging: COD, online, cancel, partial unavailability, failed delivery and return, refund | release-checklist §1 | E2E | To be written by QA |
| No duplicate money under retry and webhook replay; no stock drift | release-checklist §1, `08 §6` | BE | To be written by QA |
| Verify T-814 OWASP fixes (refund caps, stale-payment guard, throttles, lockout, PII scrub) | DL-59, T-814 | BE | To be written by QA |
| Verify staff TOTP rule per role (DL-59, DL-70), incl. ops live socket gate | DL-59, DL-70 | ADM | To be written by QA |
| Spoofed `X-Forwarded-For` test and real client IPs in logs | deployment §9.5 | BE | To be written by QA |
| Load test pass: 50 orders/min, 500 sessions, p95 targets | 09 §1, T-812 | Perf | To be written by QA; harness merged `842e632` |
| Restore test: full-data restore and one PITR restore | deployment §7.3 | DevOps | To be written by QA / DevOps |
| Graceful degradation: Redis down, FCM or SMS failure, socket drop | release-checklist §3 | E2E | To be written by QA |
| Edge limits, access logs without query strings or tokens, WS 64 KiB cap | deployment §9 | DevOps | To be written by QA (P6-TC-54 is related) |
| Monitoring: test alert delivered to each channel | deployment §10 | DevOps | To be written by QA / DevOps |
| `check --deploy --fail-level ERROR` against the real environment; rollback rehearsal | deployment §8 | DevOps | To be written by QA / DevOps |
| Device and network matrix, both apps (`10 §4`) | 10 §4 | Device | To be written by QA |
| Rider background-location and aggressive-OEM runs | 10 §4, D-11 | Device | To be written by QA |
| Release-build checks: obfuscation, no secrets in the APK, restricted public keys | release-checklist §2 | Device | To be written by QA |
| Production refuses `OTP_TEST_NUMBERS` except the reviewer number | D-15 | BE | To be written by QA |
| Compliance spot checks: GST invoice, FSSAI info, grievance officer, legal pages, DPDP consent and deletion | release-checklist §4 | E2E | To be written by QA |
| UAT with pilot users (ops lead, store manager, 2 to 3 staff, 3 to 5 riders, 10+ customers) | 10 §7 | UAT | Planned, human run |
| Production smoke after deploy: config, login, browse, COD order to delivery, refund | release-checklist §8 | E2E | Planned |

**Email OTP login and login method switch (added 2026-11-28, backend run `backend/email-otp`).** Backend-only ids `P8-EOTP-nn` (not `P8-TC`, which QA owns), automated in `backend/apps/accounts/tests/test_email_otp.py` and `test_contact_api.py`:

| Id | Case | Layer |
|---|---|---|
| P8-EOTP-01 | `GET /auth/methods/` defaults to `["phone"]` for both apps | BE |
| P8-EOTP-02 | Each setting (phone / email / both) per app | BE |
| P8-EOTP-03 | A switch change is seen at once (cache dropped on save) | BE |
| P8-EOTP-04 | Phone OTP request / verify refused with `LOGIN_METHOD_DISABLED` when phone is off | BE |
| P8-EOTP-05 | Email OTP refused while email is off (default) | BE |
| P8-EOTP-06 | Email OTP sent by email, hashed, `email_sent_at` set | BE |
| P8-EOTP-07 | No OTP and no full email address in logs | BE |
| P8-EOTP-08 | Fixed-OTP test emails send nothing (non-production only) | BE |
| P8-EOTP-09 | Send limits per email (3 / 10 min, 10 / day) and shared per-IP limit | BE |
| P8-EOTP-10 | New email creates a customer with a verified email and no phone | BE |
| P8-EOTP-11 | Verified email signs in the existing account (one user table) | BE |
| P8-EOTP-12 | Unverified email on another profile never signs in to it (claim released) | BE |
| P8-EOTP-13 | 5 attempts then locked; expiry; single use | BE |
| P8-EOTP-14 | Rider app: existing rider with verified email signs in | BE |
| P8-EOTP-15 | Rider app: unknown email gets `EMAIL_NOT_REGISTERED`, no account created | BE |
| P8-EOTP-16 | `/me/` `has_phone` / `email_verified` | BE |
| P8-EOTP-17 | Email-only account cannot drop its sign-in email by PATCH | BE |
| P8-EOTP-18 | Add a phone by SMS OTP (`/me/phone/otp/`, `/me/phone/verify/`) | BE |
| P8-EOTP-19 | Phone of another account: `PHONE_IN_USE`, never merged | BE |
| P8-EOTP-20 | Verify an email (`/me/email/otp/`, `/me/email/verify/`) | BE |
| P8-EOTP-21 | Email verified on another account: `EMAIL_IN_USE` | BE |
| P8-EOTP-22 | `POST /orders/` without a phone: 422 `PHONE_REQUIRED` | BE |
| P8-EOTP-23 | Account without a phone deletes itself with an email OTP | BE |
| P8-EOTP-24 | `send_otp_email` is idempotent | BE |
| P8-EOTP-25 | Production refuses `OTP_TEST_EMAILS` | BE |

Reference open cases: P5 (21 not run, including P0 TC-12, 42, 45, 51, 110), P6 (3 failed, 9 not run) and P7 (4 not run) must be closed before this gate (see the phase 5, 6 and 7 files).

## 4. Exit criteria
Taken from `release-checklist.md` and `10 §5`, `§7`.

| # | Criterion | Met? |
|---|-----------|------|
| 1 | Every phase P0 to P7 is 🏁 with sign-off recorded | **Not met.** The roadmap sign-off log is empty. |
| 2 | CI green on `main`; coverage gates; `pip-audit` clean | **Not met** as a release check. Latest admin run showed 4178 passed, 96.37% (on `develop`). CI on `main` for this release is not recorded. |
| 3 | No open P0/P1 bug, at most 5 open P2, full 🔥 smoke set passed on staging | **Not met.** Smoke has not run on staging. No P0/P1 open at QA stage 3. |
| 4 | OWASP review done and fixed | **Partly met.** Fixes merged (`1015790`). QA verification pending. |
| 5 | Secret and dependency scans in CI | **Met.** Merged `5a48518`. Open follow-ups: confirm the `rzp_test_` key id. |
| 6 | Load test passes (50 orders/min, 500 sessions, p95 targets) | **Not met.** Harness merged, run pending. |
| 7 | Backup restore tested with full data, plus PITR | **Not met.** Only the 2026-11-04 schema-only drill on the dev DB (does not count). |
| 8 | `check --deploy` clean on production settings; deploy-time checks live | **Not met.** No production environment. |
| 9 | Production stack up with TLS, one beat, monitoring, DNS | **Not met.** Staging only. Waits on D-05. |
| 10 | Release builds obfuscated; store listings; reviewer account; background-location approved | **Not met.** Waits on D-11, D-15. |
| 11 | Real SMS with DLT templates delivered | **Not met.** Waits on D-02. |
| 12 | Razorpay live keys and live webhook | **Not met.** Waits on D-01. |
| 13 | Legal pages live, grievance officer shown | **Not met.** Waits on D-20 and legal. |
| 14 | Dark store ready, riders approved, full catalog | **Not met.** |
| 15 | Pilot week run, UAT signed by a Jivo business owner | **Not met.** |
| 16 | Release tag, rollback owner named, rollback rehearsed | **Not met.** |
| 17 | Go-live approved by the user | **Not met.** |

## 5. Demo script (staging `https://jqc.jivo.in`)
This is the final walkthrough shown to Jivo before the go-live decision. It runs on **staging**, not production. Test numbers `+919000000001` (customer), `+919000000002` (rider) with OTP `123456`. Staff details come from the PM.

1. **Health.** Open `https://jqc.jivo.in/health/ready` in a browser. It should say ready.
2. **Order to delivery.** Customer app: sign in, add items, place a COD order. Ops console: watch it arrive, accept and pack it. Rider app: accept, pick up, deliver with the delivery code.
3. **Online order.** Place an order with online payment (test mode). Cancel one and show the refund.
4. **Live and ratings.** Show live tracking, the inbox, then rate the order and raise a support ticket (Phases 6 and 7).
5. **Dashboard and report.** Ops console: dashboard numbers and a CSV report.
6. **Safety.** Show a staff sign-in asking for the two-step code. Show that a wrong role cannot open a restricted page.
7. **Resilience.** Turn on airplane mode on the customer phone for 20 seconds. The app recovers.
8. **Evidence pages.** Show the load-test result, the restore-test log (`deployment.md` §7.3), the alert test and the QA release-readiness report.

## 6. Sign-off (template from `10 §8`, empty)
```
Phase 8 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

Go-live approval (user):

```
Go-live approved by:  ____________________ (user)    Date: YYYY-MM-DD
Release tag:          ____________________
Rollback owner:       ____________________
Deploy window:        ____________________
```

## 7. Open questions
1. **No P8 test ids.** `qa/docs/02` has none, so Section 3 lists kinds of tests only. Should QA write a Phase 8 section?
2. **Staging deploy rules.** `development-phase.md` §6 and `CLAUDE.md` say staging and production need the user's approval (D-05), but staging is already live. This file treats staging as live and production as not started.
3. **DL-59 / DL-70 TOTP.** The sources do not say if staff TOTP is built in the admin panel. Not ticked.
4. **`deployment.md` §6 is marked "target; to be implemented once D-05 is decided"** while staging is live. The text appears out of date for staging.
5. **Roadmap vs tracker:** roadmap P8 lists T-812, T-813, T-814. The tracker also files T-219, T-220, T-229 to T-232 under other tables. They are included here as P8 hardening because the task text says "P8" or "staging". Please confirm.
6. **Jivo Auth (D-04):** the `development-phase.md` plan says integrate by Phase 7. It is not built. Should it block go-live or stay on the Django login plus TOTP?
7. **Branch names:** the checklist says "CI green on `main`", but `main` only receives work at phase gates, and no P0 to P7 gate has passed.
