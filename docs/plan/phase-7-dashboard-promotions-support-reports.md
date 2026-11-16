# Phase 7: Dashboard, promotions, support, reports

Goal (`development-phase.md` §3): ops and finance have their dashboard, reports and support tools, and the legal pages are live. Needs D-04 (Jivo Auth), D-20 (support contacts, grievance officer) and the legal pages (long lead).

## Status summary (as of 2026-11-14)
1. **Build: mostly done.** Backend, customer, rider and admin P7 are merged to `develop`. Migrations are applied (DL-66). The roadmap shows build 🔄 because the items in point 4 are open.
2. **Gate: not passed.** QA stage 3 (`3a59367`, 2026-11-10): 34 of 38 cases pass. QA says the backend is **ready for sign-off on the QA instance**. No P7 bug is open.
3. **Not tested yet:** the admin screens (P7-TC-40, merged after QA's build) and the three device cases (P7-TC-37, 38, 39).
4. **Not built / waiting:** **Jivo Auth SSO is not built** (D-04, waits on Jivo IT). D-20 support contacts and the real legal pages are not delivered.
5. **Not confirmed in the tracker:** notification campaigns, `reconcile_payments`, `daily_reports_email`, payout batches, and the "Phase 8 prep" release config in both apps.

---

## 1. Scope

### Backend (`backend/`)
- Ratings (order and rider), `POST /orders/{id}/rating/`, `GET /rider/ratings/` (no customer data, no comments).
- Dashboard KPIs and alerts (`05 §1.1`), 12 reports with CSV export and async export for large reports (`05 §4`). Net revenue follows DL-65.
- Support tickets with SLA, canned replies and attachments, rider tickets, FAQs, CMS pages, notification links.
- Erasure of rating comments and ticket bodies on account deletion (DPDP).
- Planned in `development-phase.md` §3 but **not confirmed built**: notification campaigns, `reconcile_payments`, `daily_reports_email`, payout batches, Jivo Auth for staff.

### Admin panel (`backend/apps/ops_console/`, `admin.py` files)
- Dashboard cards, alerts panel, charts, ticket queue with SLA badge, ratings list, reports page and export download.
- Role matrix from `05 §3` enforced on the server. Store-scoped roles see only their own store.
- Staff two-step sign-in (TOTP) extended to Catalog Manager and Store Manager (DL-70). Built and merged 2026-11-11 (`64dc6ce`, admin/p8-security): Super Admin allows the first setup, which expires after 72 h.

### Customer app (`customer_app/`)
- Help, tickets, FAQ and CMS pages on the real API. Rate an order (`03 §2.10`), support photos, deep links for rate and support (`03 §2.11`).
- Phase 8 prep: release config (`--obfuscate --split-debug-info`), size budget, cold-start profiling.

### Rider app (`rider_app/`)
- Help and support tickets, "my rating", legal pages through the CMS (safe HTML) (`04 §2.9`).
- Phase 8 prep: release config, battery and memory profiling.

## 2. Task checklist
Sources: `docs/task-tracker.md` and `plan/00-roadmap.md`. Ticked means merged to `develop`. QA verification is a separate line.

- [x] T-711 BE lookahead: support tickets, FAQs, CMS pages API. Merged `024093c`.
- [x] T-712 BE: ratings, dashboard KPIs, 12 reports with CSV/async export, support SLA, canned replies, attachments, rider tickets, DL-65 net revenue. Merged `18eaaef`, `10dbae4`. Migrations applied (DL-66).
- [x] T-713 CUS: help, tickets, FAQ, CMS on the real API. Merged `4175616`.
- [x] T-714 CUS: ratings, deep links, rated view, support photos. Merged `ce741be`, `8a3f886`.
- [x] T-715 RID: support tickets, my rating, legal pages via CMS. Merged `695c2e5`, `130984b`.
- [x] T-716 ADM: dashboard, reports, support and ratings screens. Merged `6f92706`. Review: Approve with fixes (5 Minor). Fix run merged `2a270da` (4178 passed, 96.37%; re-review Approve; 2 Minor go to the next admin run).
- [ ] T-717 QA P7: tracker status In Progress (34/38 pass).
- [ ] QA of the admin screens: P7-TC-40.
- [ ] Device cases: P7-TC-37, 38, 39 (the user's phone, run by the PM).
- [ ] D-04 Jivo Auth SSO for staff (use the `integrate-jivo-auth` skill; Jivo IT must decide). **Not built.** Until then staff use Django login plus TOTP.
- [ ] D-20: support phone, email, hours, grievance officer (H-05 and H-22 questions).
- [ ] Legal pages (Terms, Privacy, Refund) written and loaded into the CMS.
- [ ] Notification campaigns, `reconcile_payments`, `daily_reports_email`, payout batches: no tracker row found. Needs the PM to confirm built or moved.
- [ ] Phase 8 prep in the apps (release config, size budget, profiling): no tracker row found.
- [ ] Apply the 2 Minor items left from the admin re-review (next admin run).

## 3. Test cases
Steps and expected results: [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md), section "Phase 7". Status: ✅ passed (`efb3c3d`, 2026-11-09 or 2026-11-10), ⏭ not run. Total 38: 34 ✅, 4 ⏭, 0 ❌. No linked bugs. Titles are short summaries written for this file.

| ID | Title | Pri | Layer | Latest status | Bug |
|----|-------|-----|-------|---------------|-----|
| P7-TC-01 🔥 | Rate a delivered order (order and rider stars, tags) | P0 | BE | ✅ efb3c3d | |
| P7-TC-02 🔥 | Only one rating wins under parallel requests | P0 | BE | ✅ efb3c3d | |
| P7-TC-03 🔥 | Cannot rate an order that is not delivered | P0 | BE | ✅ efb3c3d | |
| P7-TC-04 🔥 | Rating IDOR: other user gets 404 | P0 | BE | ✅ efb3c3d | |
| P7-TC-05 | Rating validation (stars, tags, comment length) | P1 | BE | ✅ efb3c3d | |
| P7-TC-06 | Order-only rating is allowed | P1 | BE | ✅ efb3c3d | |
| P7-TC-07 🔥 | Rider sees own ratings without comment or customer | P0 | BE | ✅ efb3c3d (OBS-06: customer token gets 200) | |
| P7-TC-08 | Staff ratings list per role and store | P1 | ADM | ✅ efb3c3d | |
| P7-TC-10 🔥 | Create a support ticket, SLA dates set | P0 | BE | ✅ efb3c3d | |
| P7-TC-11 | Ticket validation; other user's order id same as a miss | P1 | BE | ✅ efb3c3d | |
| P7-TC-12 🔥 | Ticket IDOR: other user gets 404 | P0 | BE | ✅ efb3c3d | |
| P7-TC-13 🔥 | Customer and rider tickets kept apart per app | P0 | BE | ✅ efb3c3d | |
| P7-TC-14 | Rider ticket for own task or payout only | P1 | RID | ✅ efb3c3d | |
| P7-TC-15 🔥 | Attachments: EXIF stripped, signed URLs, key reuse blocked | P0 | BE | ✅ efb3c3d | |
| P7-TC-16 | Bad file types rejected (GIF, PDF, SVG, empty) | P1 | BE | ✅ efb3c3d | |
| P7-TC-17 | 5 MB upload limit | P1 | BE | ✅ efb3c3d | |
| P7-TC-18 🔥 | Staff reply, status changes, role limits, inbox entry | P0 | BE | ✅ efb3c3d | |
| P7-TC-19 | Ticket create limit (10 per hour) | P2 | BE | ✅ efb3c3d | |
| P7-TC-20 | No ticket text or comments in logs | P1 | BE | ✅ efb3c3d | |
| P7-TC-21 🔥 | Reports available per role | P0 | ADM | ✅ efb3c3d | |
| P7-TC-22 🔥 | Store manager sees only own store in reports | P0 | ADM | ✅ efb3c3d | |
| P7-TC-22b | Store manager with a different store | P1 | ADM | ✅ efb3c3d | |
| P7-TC-23 🔥 | Sales summary matches SQL oracle (DL-65) | P0 | ADM | ✅ efb3c3d | |
| P7-TC-24 🔥 | CSV injection guard and BOM | P0 | ADM | ✅ efb3c3d | |
| P7-TC-25 | Report date range validation | P1 | ADM | ✅ efb3c3d | |
| P7-TC-26 | No customer phone, name or address in CSV | P0 | ADM | ✅ efb3c3d | |
| P7-TC-27 | Async export, signed URL, own exports only | P1 | ADM | ✅ efb3c3d | |
| P7-TC-30 🔥 | Account deletion erases comments and ticket bodies | P0 | BE | ✅ efb3c3d | |
| P7-TC-31 🔥 | Dashboard KPIs match reports | P0 | ADM | ✅ efb3c3d | |
| P7-TC-32 🔥 | Dashboard access per role and store | P0 | ADM | ✅ efb3c3d | |
| P7-TC-33 | Alert: order without a rider after 3 min | P1 | ADM | ✅ efb3c3d | |
| P7-TC-34 | Charts add up to the KPIs | P1 | ADM | ✅ efb3c3d | |
| P7-TC-35 🔥 | SLA due times per priority | P0 | ADM | ✅ efb3c3d | |
| P7-TC-36 🔥 | SLA breach states and queue | P0 | ADM | ✅ efb3c3d | |
| P7-TC-37 | Rate an order in the customer app | P1 | CUS | ⏭ device run (PM) | |
| P7-TC-38 | Help ticket with photo in the customer app | P1 | CUS | ⏭ device run (PM) | |
| P7-TC-39 | Rider help tickets, rating, legal pages | P1 | RID | ⏭ device run (PM) | |
| P7-TC-40 | Admin P7 screens in the console | P1 | ADM | ⏭ not run (admin P7 merged `6f92706`; repository note still says "not merged") | |

## 4. Exit criteria
| # | Criterion | Met? |
|---|-----------|------|
| 1 | All P0/P1 cases passed | **Not met.** 34 pass. TC-37, 38, 39, 40 (all P1) are not run. |
| 2 | No open P0/P1 bug | **Met.** QA stage 3 found no P7 bug. |
| 3 | Reports match an independent SQL check (DL-65) | **Met on the QA instance** (TC-23). |
| 4 | Role matrix enforced on dashboard, reports, support (`05 §3`) | **Met for the service level** (TC-08, 21, 22, 32). **Not met for the screens** until TC-40 runs. |
| 5 | Personal data is erased and masked (DPDP; no PII in CSV or logs) | **Met on the QA instance** (TC-20, 26, 30). |
| 6 | Staff sign in with Jivo Auth (D-04) | **Not met.** Not built. |
| 7 | Support contacts and grievance officer live (D-20) | **Not met.** Not delivered. |
| 8 | Legal pages (Terms, Privacy, Refund) live in the CMS | **Not met.** Content not delivered. |
| 9 | Full 🔥 smoke set of earlier phases re-run on staging | **Not met.** Stage 3 smoke ran on the QA instance, not on staging. |
| 10 | Demo given and sign-off recorded | **Not met.** |

## 5. Demo script (staging `https://jqc.jivo.in`)
Customer phone `+919000000001`, rider phone `+919000000002`, OTP `123456`. Staff login details come from the PM (staff use a two-step code). Do not expect Jivo Auth login: it is not built.

1. **Place and deliver an order.** Customer app: sign in, order any item with COD. Rider app: accept, pick up and deliver (the customer reads the delivery code to the rider).
2. **Rate it.** In the customer app open the delivered order, give stars to the order and the rider, add a tag and a short comment. Open the order again: it shows as rated and cannot be rated twice.
3. **Raise a ticket.** Customer app: Help, new ticket, attach one photo, send.
4. **Answer it.** In the ops console sign in as Support. Open the ticket queue, see the SLA badge, reply. The customer app shows the reply.
5. **Rider side.** Rider app: Help, open a ticket about the delivered task. Open "My rating" (stars only, no comments). Open a legal page.
6. **Dashboard.** Ops console as Ops or Super Admin: show today's orders, GMV and delivered count, the alerts panel and the charts.
7. **Report.** Reports page: run "Sales summary" for today and download the CSV. Open it in a spreadsheet. Point out: no customer phone, name or address.
8. **Roles.** Sign in as Store Manager. Show that only their own store's data is visible.

## 6. Sign-off (template from `10 §8`, empty)
```
Phase 7 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

## 7. Open questions
1. **Admin P7 status conflict.** `docs/project-status.md` line 14 says "`admin/phase-7` has no commits". The tracker and roadmap say it is merged (`6f92706`, fix run `2a270da`). This file follows the tracker. `project-status.md` looks out of date.
2. **Case counts differ.** Roadmap: "34/38". The QA readiness table says "34/34 executable cases" (4 not run). Both agree: 34 passed, 4 not run.
3. **TC-40 note is stale.** The QA repository says "admin P7 screens not merged"; they are merged in `develop`, but QA's build did not include them.
4. **Build status.** The roadmap shows P7 build 🔄, while the tracker shows every T-71x row merged. The difference is probably Jivo Auth SSO, campaigns and the backend jobs in `development-phase.md` §3. The tracker has no rows for them, so the PM should confirm built, moved or dropped.
5. **DL-70 (TOTP for Catalog and Store Manager):** the decision says the admin agent implements it and the backend agent covers the ops WebSocket. These sources do not say whether it is built.
6. **OBS-06 (P7-TC-07):** a customer-app token gets 200 on `GET /rider/ratings/` (R1's own list) instead of 403. Related to T-219 (app claim, merged `9742d40`). Whether this needs a decision is not stated.
