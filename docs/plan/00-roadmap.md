# Roadmap & Phase Status

The project is built in 9 gated phases. Each phase is a vertical slice: backend, admin/ops panel, both apps and QA together. Each phase's scope and its per-agent work are in [`../development-phase.md`](../development-phase.md) §3. The gate process is in [`../10-testing-strategy.md`](../10-testing-strategy.md) §5.

The **main session (Project Manager)** maintains this file and [`../task-tracker.md`](../task-tracker.md). Agents never edit it.

Status: ⬜ not started · 🔄 in progress · ⛔ blocked · ✅ built (automated tests green) · 🏁 gate passed (QA, demo, sign-off)

| Phase | Scope | Build | Gate | Notes |
|-------|-------|-------|------|-------|
| **P0** Foundation | Repo, skeletons, local stack, CI, the schema → `jivo_api` pipeline | ✅ 2026-11-02 | ⬜ | Pushed in `4960527`. Phase 0 test cases live in `qa/docs/02-test-case-repository.md`. |
| **P1** Auth & users | OTP login, JWT, profile, devices, addresses, account deletion, app config (426/503), staff roles | ✅ 2026-11-02 | 🔄 | Pushed in `4960527`; CI green. QA's independent verification is running. The human gate steps (staging QA, demo, sign-off) are still open. |
| **P2** Stores, catalog, inventory, home | Serviceability, catalog, inventory, home and search; admin for stores, catalog and inventory; the rider KYC lookahead | 🔄 | ⬜ | Integration branch `develop` (module branches per DL-24). Contract published (T-201). Backend R2a/R2b (catalog, inventory, stores, GeoDjango serviceability) in progress. PostGIS on the server and GDAL on the host are both done. |
| **P3** Cart, checkout, payments | Cart, `compute_bill`, coupons, orders T1–T5, Razorpay (Cashfree is the alternative, D-01), COD | ⬜ | ⬜ | Needs Razorpay test keys (D-01, long lead). |
| **P4** Order processing & store ops | Transitions T6–T8a/T11/T12, packing console, live board, refunds, invoices | ⬜ | ⬜ | Needs D-10 refund policy and D-12 GST data. Mini-UAT with store staff. |
| **P5** Rider & delivery | Rider KYC, shifts, dispatch, offers, pickup, delivery OTP, COD cash, earnings | ⬜ | ⬜ | Needs D-11 Play Console, D-14 KYC policy and D-16 rider pay. Mini-UAT with riders. |
| **P6** Real-time & notifications | WebSockets, live tracking, ETA, FCM push, SMS, inbox | ⬜ | ⬜ | Needs FCM projects (D-19) and the Apple account (D-11). |
| **P7** Dashboard, promotions, support, reports | Ops dashboard, reports, ratings, support, CMS, Jivo Auth SSO | ⬜ | ⬜ | Needs D-20 support contacts and the legal pages. |
| **P8** Hardening & launch | Security review, load test, backup restore, store releases, pilot, UAT, go-live | ⬜ | ⬜ | Uses [`../release-checklist.md`](../release-checklist.md). |

## Per-phase files
The detailed per-phase files (`phase-N-*.md`: task checklist, test cases, exit criteria, demo script, sign-off) are **not written yet**. Until they exist:
- **Scope:** [`../development-phase.md`](../development-phase.md) §3.
- **Test cases:** the QA agent's [`../../qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (`P<n>-TC-<nn>` IDs, with 🔥 smoke cases).
- **Sign-off:** the template in `10 §8`. Record it below.

## Sign-off log
| Phase | Date | Build / commit | Cases passed | Open bugs (P0/P1/P2) | Approved by |
|-------|------|----------------|--------------|----------------------|-------------|
| | | | | | |
