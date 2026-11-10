# Roadmap & Phase Status

The project is built in 9 gated phases. Each phase is a vertical slice: backend, admin/ops panel, both apps and QA together. Each phase's scope and its per-agent work are in [`../development-phase.md`](../development-phase.md) §3. The gate process is in [`../10-testing-strategy.md`](../10-testing-strategy.md) §5.

The **main session (Project Manager)** maintains this file and [`../task-tracker.md`](../task-tracker.md). Agents never edit it.

Status: ⬜ not started · 🔄 in progress · ⛔ blocked · ✅ built (automated tests green) · 🏁 gate passed (QA, demo, sign-off)

| Phase | Scope | Build | Gate | Notes |
|-------|-------|-------|------|-------|
| **P0** Foundation | Repo, skeletons, local stack, CI, the schema → `jivo_api` pipeline | ✅ 2026-11-02 | ⬜ | Pushed in `4960527`. Phase 0 test cases live in `qa/docs/02-test-case-repository.md`. |
| **P1** Auth & users | OTP login, JWT, profile, devices, addresses, account deletion, app config (426/503), staff roles | ✅ 2026-11-02 | 🔄 | Pushed in `4960527`; CI green. QA run 1 verdict Not ready; its P2 bugs were fixed and verified in run 2 (BUG-0006/0008 re-check pending). The human gate steps (staging QA, demo, sign-off) are still open. |
| **P2** Stores, catalog, inventory, home | Serviceability, catalog, inventory, home and search; admin for stores, catalog and inventory; the rider KYC lookahead | ✅ 2026-11-03 | ⬜ | Code merged to `main` (`3b5066e`, includes the Mappls crash fix). QA run 2 was stopped part-way at the user's request (no verdict); BUG-0008 open, BUG-0006 awaiting re-verification; demo and sign-off open. |
| **P3** Cart, checkout, payments | Cart, `compute_bill`, coupons, orders T1–T5, Razorpay (Cashfree is the alternative, D-01), COD | ✅ 2026-11-04 | 🔄 | Merged to `develop`; QA verdict: ready for sign-off on the QA instance (T-310), P3-TC-64 passed on the user's phone. Open: CI on the `develop` → `main` PR, demo, sign-off. Fake payment gateway until Razorpay keys arrive (D-01). |
| **P4** Order processing & store ops | Transitions T6–T8a/T11/T12, packing console, live board, refunds, invoices | ✅ 2026-11-05 | 🔄 | All runs merged (`ef4199f`, `74f47d1`, admin `ef1426a`/`60a422f` incl. the BUG-0010/0011 fixes); migrations applied (DL-53). QA stage 2 verdict Not ready (`4d10384`); open: QA re-check of BUG-0010/0011, device cases, store-staff mini-UAT, sign-off. |
| **P5** Rider & delivery | Rider KYC, shifts, dispatch, offers, pickup, delivery OTP, COD cash, earnings | ✅ 2026-11-06 | 🔄 | Slices 5.1–5.4 merged (backend `57e8fb0`/`8566589`/`d72bd23`, rider `130b42a`, customer `9ce3234`, admin `680b904`); migrations applied (DL-62/63); DL-61 rules. QA stage 1 done (132 cases), stage 2 running. D-14/D-16 on doc 11 defaults; D-11 needed for real riders. Rider mini-UAT open. |
| **P6** Real-time & notifications | WebSockets, live tracking, ETA, FCM push, SMS, inbox | ✅ 2026-11-06 | 🔄 | Merged (backend `b8eead2`/`d29ed94`, customer `0e55bb4`, rider `1ef1ba3`, admin `ee35f0a`). QA stage 2 running. Push is a no-op until the FCM projects exist (D-19); real SMS waits on D-02. |
| **P7** Dashboard, promotions, support, reports | Ops dashboard, reports, ratings, support, CMS, Jivo Auth SSO | 🔄 | 🔄 | Backend (`024093c`, `18eaaef`, `10dbae4`), customer (`4175616`, `ce741be`, `8a3f886`) and rider (`695c2e5`, `130984b`) merged; migrations applied (DL-66). Open: admin P7 screens, Jivo Auth SSO (D-04), QA stage 2 (running), D-20 support contacts and legal pages. |
| **P8** Hardening & launch | Security review, load test, backup restore, store releases, pilot, UAT, go-live | 🔄 | ⬜ | Merged: OWASP fixes T-814 (`1015790`), Locust harness T-812 (`842e632`), backup/restore and monitoring T-813 (`4b30378`). Staging `jqc.jivo.in` live with HTTPS. Open: load test run, store releases (D-11), pilot, UAT, production (D-05). Uses [`../release-checklist.md`](../release-checklist.md). |

## Per-phase files
The detailed per-phase files (`phase-N-*.md`: task checklist, test cases, exit criteria, demo script, sign-off) are **not written yet**. Until they exist:
- **Scope:** [`../development-phase.md`](../development-phase.md) §3.
- **Test cases:** the QA agent's [`../../qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (`P<n>-TC-<nn>` IDs, with 🔥 smoke cases).
- **Sign-off:** the template in `10 §8`. Record it below.

## Sign-off log
| Phase | Date | Build / commit | Cases passed | Open bugs (P0/P1/P2) | Approved by |
|-------|------|----------------|--------------|----------------------|-------------|
| | | | | | |
