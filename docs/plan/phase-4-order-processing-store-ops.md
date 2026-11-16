# Phase 4: Order processing and store ops

**Goal:** the store accepts, packs and cancels orders, refunds and invoices work, and customers see their orders (`development-phase.md` §3).
**Needs:** D-10 (refund policy; the `08 §6.4` defaults are used, DL-47), D-12 (GST details; marked placeholder data is used, DL-47), D-22 (store hardware for the pilot).
**Contracts:** `docs/08-order-lifecycle.md` (transitions T6-T8a, T11, T12, refunds §6.4, partial unavailability §6.3). Ops screens in `05 §1.2`, `§1.3`, role matrix `05 §3`. Test steps are in [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (Phase 4 section).

## Status summary (as of 2026-11-14)

1. **Build:** done and merged to `develop` (2026-11-04/05): backend `ef4199f`, customer `74f47d1`, admin `ef1426a` and `60a422f`. Migrations applied to the shared DB (DL-53).
2. **QA:** stage 2 (`f744508`, 2026-11-04) verdict "Not ready": 46 of 60 pass, 3 fail (TC-32, 33, 40), 1 partial, 4 deferred, 6 not run (device cases). The bug files say BUG-0010 and BUG-0011 were verified on 2026-11-09; the case rows were not updated.
3. **P3 carry-overs T-401c to T-406c and T-408c:** completed (merged `64dc6ce` on 2026-11-11). T-407c is not started.
4. **Since 2026-11-10:** water slab prices, a minimum of 5 cartons per order, referral coupons, COD limit kept at ₹2,000 (user, 2026-11-14), cart tip and instructions reset after an order (`d387784`). QA has not re-run P4 on these.
5. **Gate:** open. Needed: device cases, the store-staff mini-UAT, a staging run, CI on the `develop` to `main` PR, demo and sign-off. Waiting on Jivo: D-10, D-12, D-22.

## Scope

### Backend
| Item | Notes |
|---|---|
| Order list, detail, cancel, reorder, invoice endpoints (`06 §2.6`) | Querysets are scoped to the requester. Another user gets 404. |
| T6 accept, T7 start packing, T8 packed, T8a partial unavailability, T11 customer cancel, T12 staff cancel | Only through `orders.services.transition()`. T8a recomputes the bill with `compute_bill()` and refunds the difference. |
| Refunds (`08 §6.4` defaults): `process_refund`, `sync_refund_status`, manual refund | One `Refund` per event. Total refunds never exceed what was captured (T-402c). `order_refunds.settle()` is the only refund-status writer. |
| Invoices (WeasyPrint) | On demand now; on DELIVERED from P5. GST data is placeholder (DL-47). |
| Auto-accept and the acceptance SLA alert | `STORE_ACCEPTANCE_SLA_SECONDS` (60 s). |
| Rules from DL-59 (b) | Support refunds capped at ₹500 total per order and ₹5,000 per agent per IST day; larger refunds go to Finance or Super Admin. |
| New since 2026-11-10 | Slab prices and the minimum-units rule (reorder goes through the same cart rules), referral coupons, tip and instructions reset after an order (`c27f606`). |

### Admin panel and Ops Console
| Item | Notes |
|---|---|
| Live board `/ops/orders/live/` (HTMX polling) | Lanes Placed to Packed, Out for delivery, Exceptions (`05 §1.2`). |
| Packing console `/ops/store/<store>/` | Queue, packing slip with number, 4-character code and QR, item-unavailable form, cancel (`05 §1.3`). |
| Orders admin, customer detail, refund retry screen, manual refund form, CSV export, audit log | Role matrix `05 §3`; state changes only through services. BUG-0010 (refund form) and BUG-0011 (CSV export) were fixed in `60a422f`. |
| Staff two-step sign-in | Store Manager and Catalog Manager now need TOTP (DL-70). Store Staff stays password-only. |
| Carry-overs | `save_coupon()`, `set_cod_blocked` and its permission, `PricingConfig` bounds (T-405c, T-406c). |

### Customer app
| Item | Notes |
|---|---|
| Order list (active then past), order detail with timeline, invoice download | Server bill only. |
| Cancel sheet with the refund sentence (DL-52 (b)), reorder, "Previously bought" rail | A FAILED refund is shown as PENDING (DL-52 (c)). |
| Lookahead | Tracking UI on fake data, inbox, `jivo://` deep links (https links wait for the App Links domain, DL-52 (a)). |

### Rider app
Lookahead only (T-415): earnings, cash ledger, history, documents, and an accept-to-deliver test harness with GPX, all on fakes. They were bound to the real API in phase 5.

## Task checklist

Source: `docs/task-tracker.md`. `[x]` means tracker "Completed" or merged to `develop` (hash shown).

- [x] T-411 P4 contract (R1): order list, detail, cancel, reorder, invoice: Completed (merged `ef4199f`)
- [x] T-412 P4 R2: T6-T8a/T11/T12, refunds, invoices, auto-accept, packing services: merged `ef4199f`, migrations applied (DL-53); gateway call outside the lock `1015790`. Tracker status "Testing" (2427 passed, 96.92% at merge)
- [x] T-413 Admin and Ops Console: live board, packing console, refund retry, audit log: merged `ef1426a`, `60a422f` (includes the BUG-0010/0011 fixes). QA verification pending in the tracker
- [x] T-414 Customer P4: order list, detail, cancel, reorder, invoice: merged `74f47d1` (295 tests; installed on the user's phone). Tracker status "Testing"
- [x] T-415 Rider lookahead: merged (351 tests; review Approve). Tracker status "Testing"
- [ ] T-416 QA: P4 test plan, verification and store-staff mini-UAT: In Progress (stage 1 `8e7da52`, stage 2 `4d10384`)
- [x] T-401c Ops view for FAILED/PENDING refunds with retry: Completed (PM code check 2026-11-10)
- [x] T-402c Refund status for mismatch and duplicate, cap at captured: merged `64dc6ce`
- [x] T-403c Gateway calls outside row locks, `skip_locked` on expiry: merged `64dc6ce`
- [x] T-405c `set_cod_blocked` service, DL-61 (d) restart, AuditLog: merged `64dc6ce`
- [x] T-406c `PricingConfig` bounds, `save_coupon()` with row lock: merged `64dc6ce`
- [ ] T-407c Confirm Store Staff `ORDER_VIEW` against `05 §3`: Not Started (PM)
- [ ] T-409c OBS-P3-05 (a double late capture understates `amount_refunded`; own migration): named in DL-53, but the tracker has no row (see Open questions)
- [x] Water slab prices (`5dd3a4f`, merged `c7f6da9`) and minimum order units (`c30ba08`, merged `d64dc39`), 2026-11-13
- [x] Cart tip and instructions reset after an order: `c27f606` (merged `d387784`), 2026-11-14
- [ ] Device cases P4-TC-51 to 54, 56, 58 on the user's phone
- [ ] Mini-UAT with store staff on the packing console (`10 §7`)
- [ ] QA re-run of P4-TC-32, 33, 40 and a regression for the new slab and minimum rules
- [ ] CI on the `develop` to `main` PR, staging run, demo, sign-off

## Test cases

Steps and expected results: `qa/docs/02-test-case-repository.md`, section "Phase 4". 🔥 = regression smoke case. Layers: BE backend, ADM admin and ops panel, CUS customer app, E2E end to end. Status is the latest QA run (stage 2, `f744508`, 2026-11-04).

| ID | Title | Pri | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P4-TC-01 | Order detail of an ONLINE order, then after verify (strict P4 schema o... | P0 🔥 | BE | pass | - |
| P4-TC-02 | Customer cancels a COD order in PLACED (T11) | P0 🔥 | BE | pass | - |
| P4-TC-03 | Customer cancels a paid ONLINE order in PLACED (T11) | P0 🔥 | BE | pass | - |
| P4-TC-04 | Store accepts, then the customer cancels in ACCEPTED (paid ONLINE and ... | P0 | BE | pass | - |
| P4-TC-05 | Customer cancels in PACKING and in PACKED | P0 🔥 | BE | pass | - |
| P4-TC-06 | The same paid order cancelled 5× in parallel | P0 | BE | pass | - |
| P4-TC-07 | User B cancels user A's order: (a) PAYMENT_PENDING, (b) PLACED | P0 🔥 | BE | pass | - |
| P4-TC-08 | Customer cancel with staff reasons (ITEMS_UNAVAILABLE, SUSPECTED_FRAUD... | P1 | BE | pass | - |
| P4-TC-09 | Customer cancel and staff "Start packing" at the same instant (3 round... | P0 | BE | pass | - |
| P4-TC-10 | Instance with CUSTOMER_CANCEL_UNTIL=PLACED: cancel in ACCEPTED | P2 | BE | pass | - |
| P4-TC-11 | Reorder a past order twice | P0 🔥 | BE | pass | - |
| P4-TC-12 | Reorder an order whose variants are now out of stock / partly in stock... | P1 | BE | pass | - |
| P4-TC-13 | Reorder when the cart already holds more units of a line | P1 | BE | pass | - |
| P4-TC-14 | (a) list/detail/cancel without a token; (b) reorder and invoice of ano... | P0 🔥 | BE | pass | - |
| P4-TC-15 | Invoice of a PLACED / CANCELLED order | P0 | BE | pass | - |
| P4-TC-16 | Invoice of a DELIVERED order, twice | P1 | BE | deferred | - |
| P4-TC-17 | Signed invoice URL: after expires_at, with a changed signature, with a... | P1 | BE | deferred | - |
| P4-TC-18 | Order list after cancel / accept | P1 | BE | pass | - |
| P4-TC-19 | Store Staff accepts a PLACED order (T6) | P0 🔥 | ADM | pass | - |
| P4-TC-20 | Start packing (T7), Mark packed (T8) | P0 🔥 | ADM | pass | - |
| P4-TC-21 | Out-of-order actions: pack from PLACED/ACCEPTED, start packing from PL... | P0 | ADM | pass | - |
| P4-TC-22 | T8a: paid ONLINE order in PACKING, mark 1 of 2 units of a line unavail... | P0 🔥 | ADM | pass | - |
| P4-TC-23 | T8a on a COD order | P0 | ADM | pass | - |
| P4-TC-24 | T8a with every unit unavailable | P0 | ADM | pass | - |
| P4-TC-25 | T8a that drops item_total below the free-delivery and small-cart thres... | P0 | ADM | pass | - |
| P4-TC-26 | T8a on an order with a FLAT coupon whose minimum is no longer met | P1 | ADM | pass | - |
| P4-TC-27 | Item unavailable on PACKED; qty > line qty, 0, negative; an item of an... | P0 | ADM | pass | - |
| P4-TC-28 | Store Manager / Ops / Support cancel (T12) in PLACED, ACCEPTED, PACKIN... | P0 | ADM | pass | - |
| P4-TC-29 | Staff cancel without a reason / with a customer-only reason | P1 | ADM | pass | - |
| P4-TC-30 | Store Staff / Manager of GGN-01: another store's console URL; accept /... | P0 🔥 | ADM | pass | - |
| P4-TC-31 | 05 §3 P4 rows × 7 roles: live board, packing console, cancel, refund... | P0 🔥 | ADM | pass | - |
| P4-TC-32 | Support refunds 500.00 and 500.01; Finance any amount; refund above re... | P0 | ADM | fail at stage 2; bug since verified (see Open questions) | BUG-0010 |
| P4-TC-33 | Manual partial then full refund (GOODWILL); double submit | P0 | ADM | fail at stage 2; bug since verified (see Open questions) | BUG-0010 |
| P4-TC-34 | Retry a FAILED refund from the ops screen; try to retry a PENDING / PR... | P1 | ADM | pass | - |
| P4-TC-35 | Refund PENDING without a gateway answer for > REFUND_STUCK_MINUTES; sy... | P1 | BE | pass | - |
| P4-TC-36 | Store with auto-accept: new PLACED order | P1 | BE | pass | - |
| P4-TC-37 | Order not accepted within STORE_ACCEPTANCE_SLA_SECONDS (60 s); one acc... | P1 | BE | pass | - |
| P4-TC-38 | Live board /ops/orders/live/ | P1 | ADM | pass | - |
| P4-TC-39 | Packing console /ops/store/<store>/ | P1 | ADM | pass | - |
| P4-TC-40 | Orders admin: filters, detail, actions, CSV export | P1 | ADM | fail at stage 2; bug since verified (see Open questions) | BUG-0010, BUG-0011 |
| P4-TC-41 | Each staff action (accept, start packing, pack, unavailable, cancel, r... | P0 🔥 | ADM | pass | - |
| P4-TC-42 | Console POST without a CSRF token; GET on action URLs | P0 | ADM | pass | - |
| P4-TC-43 | Customer detail (Customers admin, P4) per role | P1 | ADM | pass | - |
| P4-TC-44 | SQL: refunds per payment ≤ captured; amount_refunded ∈ [0, grand_t... | P0 🔥 | BE | pass | - |
| P4-TC-45 | SQL: no ACTIVE reservation on CANCELLED/PAYMENT_FAILED orders; 0 ≤ r... | P0 🔥 | BE | pass | - |
| P4-TC-46 | SQL: T6/T7/T8/T11/T12 history rows with actor types; the API timeline ... | P1 | BE | pass | - |
| P4-TC-47 | SQL: bill identity after T8a; item_total = Σ (qty − unavailable) ×... | P0 | BE | pass | - |
| P4-TC-48 | Domain events per transition (08 §9): T6, T8a, T11, T12, refund proce... | P2 | BE | pass | - |
| P4-TC-49 | (ex P3-TC-26, DL-50) Cart of one ₹45 sachet JV-WG-PW-10S; place COD ... | P1 | BE | pass | - |
| P4-TC-50 | (ex P3-TC-63, DL-50) Instance with FAKE_GATEWAY_DOWN=1: ONLINE placeme... | P1 | BE | pass | - |
| P4-TC-51 | Orders tab: active then past, status chips, pagination, empty and erro... | P0 🔥 | CUS | not run | - |
| P4-TC-52 | Order detail: timeline, items with removed units struck through, serve... | P0 🔥 | CUS | not run | - |
| P4-TC-53 | Cancel sheet: only when can_cancel; reason picker; confirmation; refun... | P0 🔥 | CUS | not run | - |
| P4-TC-54 | "Order again": cart opens, unavailable lines listed | P1 | CUS | not run | - |
| P4-TC-55 | Home "Previously bought" rail | P2 | CUS | not run | - |
| P4-TC-56 | Customer app integration test "cancel an order" (S4-B) against the QA ... | P1 | CUS | not run | - |
| P4-TC-57 | Invoice download opens the PDF; an expired link is refreshed | P1 | CUS | deferred | - |
| P4-TC-58 | COD order on the phone → accept on the packing console → start pac... | P0 🔥 | E2E | not run | - |
| P4-TC-59 | Paid ONLINE order → customer cancels → a late payment.captured for... | P0 | E2E | pass | - |
| P4-TC-60 | Live board and packing console poll endpoints: query count and p95 wit... | P2 | BE | partial | - |

Totals (stage 2): 60 cases. Pass 46, partial 1 (TC-60), fail 3 (TC-32, 33, 40), deferred 4 (TC-16, 17, 55, 57: need a DELIVERED order, which P5 can now produce), not run 6 (TC-51 to 54, 56, 58: device).
The repository table above shows TC-55 as not run and the stage 2 report shows it deferred; the totals above follow the report.

## Exit criteria

| # | Criterion (`10 §5.2`) | State |
|---|---|---|
| 1 | All checklist tasks done or deferred with an owner | Not met: T-407c, T-409c, T-416 open |
| 2 | CI green | Not met: not verified by QA; CI on the `develop` to `main` PR pending |
| 3 | All cases run on staging: 100% of P0/P1 and at least 95% of all pass | Not met: 46/60 = 77% at stage 2, on the QA instance |
| 4 | Regression smoke set (P0-P3) passed | Met on the QA instance (98 passed at stage 2; 138 passed at stage 3) |
| 5 | No open P0/P1 bugs | Met: BUG-0010 (P2) and BUG-0011 (P3) are marked Verified in the bug files; the tracker still lists the re-check as pending |
| 6 | Docs updated | Met for the order rules (`06`, `08`); re-check `08` for the slab and minimum rules in T8a |
| 7 | Demo done and sign-off recorded | Not met |
| P4 | Mini-UAT with store staff on the packing console | Not met |
| P4 | Backend coverage at least 90% on orders, payments and inventory services | Met per tracker (96.92% at T-412) |
| P4 | No double refund, refunds at most what was paid | Met: P4-TC-44, 35, 59 pass |

## Demo script (staging jqc.jivo.in)

For a non-developer, with two people: a customer (phone with the customer app) and a store person (a computer with the ops panel). Test customer numbers: `+919000000001`, `+919000000002`, `+919000000003` with OTP `123456`. For the store login, ask the project manager for the demo store account (passwords are not written here). Store Manager accounts also need the two-step code.

1. Customer: sign in, add at least 5 water cartons, choose Cash on delivery, place the order. Expected: success screen, order in the Orders tab as Placed.
2. Store person: open the live board (`/ops/orders/live/`). Expected: the new order is in the Placed lane within a few seconds.
3. Store person: open the packing console, press Accept. Expected: the order moves to Accepted. The customer's order detail shows the new step.
4. Store person: press Start packing, then Mark packed. Expected: a packing slip with the order number, a 4-character code and a QR is shown.
5. Customer: place a second order and pay online with the test method. Store person: accept and start packing.
6. Store person: mark one unit of one item as unavailable. Expected: the bill is recalculated by the server and the difference is refunded. The customer sees the struck-through unit.
7. Customer: open the third order (placed, not packed) and cancel it from the cancel sheet. Expected: Cancelled, and a refund sentence is shown for a paid order.
8. Store person: cancel a packed order from the console with a reason. Expected: Cancelled with the reason in the history.
9. Store person (Finance or Super Admin): open the order in the admin and issue a small manual refund. Expected: the refund is listed once; pressing the button twice makes only one refund.
10. Customer: press "Order again" on a past order. Expected: the cart opens; lines that are not available are listed.
11. Customer: download an invoice for a delivered order (needs phase 5 to deliver one first). Expected: a PDF opens.

## Sign-off

```
Phase 4 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

## Open questions

1. **BUG-0010 and BUG-0011:** the bug files say Verified (2026-11-09, `4ac5dae`), but `docs/task-tracker.md` T-413/T-416 still say the re-check is pending, and `qa/docs/02` still shows TC-32, 33 and 40 as failed. QA to update the rows.
2. **T-409c:** DL-53 defers OBS-P3-05 to "T-409c", but the tracker has no such row. T-402c says the late-capture refund counting was fixed in `64dc6ce`. Is OBS-P3-05 closed?
3. **Slabs and minimums with T8a and reorder:** `08` says the slab tier is chosen once for the whole order. It does not say whether T8a (unavailable units) recomputes the tier, or whether "Order again" can hit `MIN_UNITS_NOT_MET`. Needs a decision and QA cases.
4. **Invoice cases** TC-16, 17 and 57 depend on a DELIVERED order. P5-TC-77 covers them but is not run yet.
5. **Store Staff `ORDER_VIEW`** (T-407c) is still unconfirmed against `05 §3`.
6. **WELCOME90:** not found in docs, code or git (see phase 3 file). Does its refund and reversal behaviour need a P4 case?
7. **COD limit ₹2,000** (user, 2026-11-14) has no decision-log entry yet (the log ends at DL-71).
