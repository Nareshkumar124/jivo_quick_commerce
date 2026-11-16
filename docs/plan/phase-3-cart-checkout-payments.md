# Phase 3: Cart, checkout, payments

**Goal:** a customer places a COD order and a Razorpay test-mode order, and the money is correct (`development-phase.md` §3).
**Needs:** D-01 (Razorpay test keys; a fake gateway is used until they arrive, DL-42) and D-09 (business rule values, PM defaults in DL-43).
**Contracts:** `docs/08-order-lifecycle.md` (§1-§4, §6, §7) is the money and state contract. API in `06 §2.5` and `§2.6`. Test steps are in [`qa/docs/02-test-case-repository.md`](../../qa/docs/02-test-case-repository.md) (Phase 3 section).

## Status summary (as of 2026-11-14)

1. **Build:** done and merged to `develop` (2026-11-04). Cart, `compute_bill`, coupons, orders T1-T5 and T3a, payments (fake gateway), COD.
2. **QA:** verdict "ready for sign-off on the QA instance" (T-310): 66 of 69 cases pass, 0 fail (`69fe035`). P3-TC-64 passed on the user's phone (tracker T-306).
3. **Since 2026-11-10:** water slab prices per carton (catalog 0005), a minimum of 5 cartons per order, referral coupons, the COD limit kept at ₹2,000 (user, 2026-11-14), and the cart tip and instructions reset after an order (`d387784`). QA has not re-run P3 on these.
4. **Gate:** open. Still needed: CI on the `develop` to `main` PR, a staging run, the demo and the sign-off (`10 §5`).
5. **Waiting on Jivo:** D-01 Razorpay test keys (the fake gateway runs until then) and D-09 confirmation of the pricing values.

## Scope

### Backend
| Item | Notes |
|---|---|
| Cart API (`06 §2.5`): add, set, remove, tip, instructions, coupons | Every call returns the whole cart with the server's bill. Stock is reserved when the order is placed, never at add-to-cart. |
| `cart.services.compute_bill()` (`08 §6.2`) | The only money function. `Decimal`, 2-decimal strings. Thresholds compare against `item_total` before the coupon (DL-45). |
| Coupons (`08 §6`, DL-45, DL-46) | Percent, flat and category coupons. Usage limits per user and in total. A personal (owner-only) coupon type was added by the referral program (`65c9248`). |
| `place_order` T1/T2 with reservations and `Idempotency-Key` | Locks rows in variant-id order. The same key with another body gives 400 `VALIDATION_ERROR` (DL-44). |
| `orders.services.transition()` T1-T5, T3a | The only way to change an order status. |
| Payments: Razorpay behind an interface, fake gateway for local and test only | Signature check on verify, idempotent webhook keyed on a unique event id, retry-payment, `expire_unpaid_orders`. Deployed settings refuse the fake gateway. |
| Rules from DL-43/44/46 | Payment window 15 min, `CART_MAX_TIP` ₹500, one pending order at a time, a fixed checkout blocker order, throttles 30/h orders and 60/h payment calls. |
| New since 2026-11-10 | Water slab prices (`VariantPriceTier`, catalog 0005, ADR 0001). Whole-order minimum units (`min_order_units`, 422 `MIN_UNITS_NOT_MET`) and per-variant `min_qty_per_order`. Referral program. Cart tip and instructions reset after an order (`c27f606`). |

### Admin panel
| Item | Notes |
|---|---|
| Pricing config, coupons, read-only orders and payments, `cod_blocked` | Role matrix per DL-46: Catalog Manager manages coupons; Support and Finance view; only Super Admin changes orders. |
| COD limit | `PricingConfig.cod_max_order_value`. Kept at ₹2,000 (user decision, 2026-11-14). |

### Customer app
| Item | Notes |
|---|---|
| Cart, bill breakdown (server bill only), coupon sheet, tip and instruction chips | No client-side money. |
| Payment method screen, success and failure screens, `razorpay_flutter` | The dev fake launcher is used only in tests and dev. |
| Real API, `Idempotency-Key`, `PRICE_CHANGED` / `STOCK_UNAVAILABLE`, `PAYMENT_PENDING` recovery | |
| New since 2026-11-10 | Slab rate table and per-box rate, "add N more cartons" message from the server thresholds, COD shown greyed with the server reason (`c95a111`), gold savings card, My coupons, referral screen. |

### Rider app
Nothing in this phase (rider fakes only; see phase 5).

## Task checklist

Source: `docs/task-tracker.md`. `[x]` means tracker "Completed" or merged to `develop` (hash shown).

- [x] T-301 P3 API contract (R1): merged `cd5e53e`, `jivo_api` regenerated `48aaddd`
- [x] T-302 R2a: models, `compute_bill`, cart: merged `c4ff7d9`
- [x] T-303 R2b: `place_order`, T1-T5/T3a, verify, webhook, retry, expiry: merged, review fixes `476dfd5`
- [x] T-304 Admin: pricing config, coupons, read-only orders/payments, `cod_blocked`: merged `984e634`
- [x] T-305 Customer start: cart, bill, coupons, payment screens: merged `9dbe11c`
- [x] T-306 Customer on the real API, `Idempotency-Key`, recovery: P3-TC-64 passed on the phone 2026-11-04 (COD `JV-261104-000135`, online `JV-261104-000136`)
- [ ] T-307 Review of each P3 module branch: In Progress. Open for CUS: `jivo_core` `isVersionBelow` tests for build suffix and short versions
- [x] T-308 Twilio SMS backend for OTP: merged `88692a1`. Live SMS stays off (DL-48)
- [x] T-309 New Windows dev machine and local stack: Completed 2026-11-04
- [x] T-310 QA: verify P3: Completed (66/69, refund re-check `69fe035`)
- [x] T-401c Ops view for FAILED/PENDING refunds with retry: Completed (built in P4)
- [x] T-402c Refund cap and mismatch handling: merged `64dc6ce`
- [x] T-403c Gateway calls outside row locks, `skip_locked` on expiry: merged `64dc6ce`
- [x] T-404c Env var mirror, Celery beat everywhere, Razorpay pins in CI (DL-51): Completed 2026-11-04
- [x] T-405c `set_cod_blocked` service (and the DL-61 (d) count restart): merged `64dc6ce`
- [x] T-406c `PricingConfig` bounds and `save_coupon()` guard: merged `64dc6ce`
- [ ] T-407c Confirm Store Staff `ORDER_VIEW` against `05 §3`: Not Started (PM)
- [x] T-408c `pytest-xdist` for the backend suite: Completed 2026-11-04
- [ ] T-409c OBS-P3-05 (a double late capture understates `amount_refunded`): named in DL-53 and the T-412 row, but the tracker has no T-409c row (see Open questions)
- [x] Water slab prices, backend and customer: `5dd3a4f` (merged `c7f6da9`), `da9d9fe` (merged `9468080`), 2026-11-13
- [x] Minimum order units, backend and customer: `c30ba08` (merged `d64dc39`), `4e38149` and `96293bf` (merged `5f2f42b`), 2026-11-13
- [x] Referral program with personal coupons: `65c9248` (merged `b3434bd`), customer `4f9c57b` (merged `058219b`), 2026-11-13
- [x] My coupons, gold savings card, referral banner link: `d1d4ae9` (merged `6bb5eeb`)
- [x] COD greyed out with the reason: merged `c95a111`
- [x] Cart tip and instructions reset after an order: `c27f606` (merged `d387784`), 2026-11-14
- [ ] QA re-run for slabs, minimum units and the coupon changes (no QA run yet)
- [ ] CI on the `develop` to `main` PR, staging run, demo, sign-off

## Test cases

Steps and expected results: `qa/docs/02-test-case-repository.md`, section "Phase 3". 🔥 = regression smoke case. Layers: BE backend, ADM admin panel, CUS customer app. Status is the latest QA run (stage 2 plus the refund re-check `9ed7ffc`, 2026-11-04).

| ID | Title | Pri | Layer | Latest status | Bug |
|---|---|---|---|---|---|
| P3-TC-01 | GET /cart/ on an empty cart | P0 🔥 | BE | pass | - |
| P3-TC-02 | 5 carts (below/above free delivery, big, max tip 500) | P0 🔥 | BE | pass | - |
| P3-TC-03 | Thresholds below/above free delivery | P1 | BE | pass | - |
| P3-TC-04 | Set the same qty twice; PATCH line; qty 0; DELETE line | P1 | BE | pass | - |
| P3-TC-05 | Qty > max; out-of-stock variant; variant not sold; bad qty types | P0 | BE | pass | - |
| P3-TC-06 | Add 4 units to the cart; read reserved | P0 | BE | pass | - |
| P3-TC-07 | Tip −1 / 500.01 / 3 dp / text; chips duplicate/unknown; note 201; DE... | P1 | BE | pass | - |
| P3-TC-08 | Mumbai address; another user's address; ?address_id= preview | P0 | BE | pass | - |
| P3-TC-09 | No token; no / malformed / unknown X-Store-Id | P0 🔥 | BE | pass | - |
| P3-TC-10 | User A patches/deletes user B's cart line | P0 🔥 | BE | pass | - |
| P3-TC-11 | An orderable cart | P1 | BE | pass | - |
| P3-TC-12 | Apply jivo50 (lower case); remove twice | P0 🔥 | BE | pass | - |
| P3-TC-13 | JIVO10 on a ₹3,591 cart and a ₹549 cart | P0 | BE | pass | - |
| P3-TC-14 | OILS15 on oil + seeds; seeds only | P0 | BE | pass | - |
| P3-TC-15 | JIVO50 on a ₹165 cart | P1 | BE | pass | - |
| P3-TC-16 | Apply, then drop below the minimum | P1 | BE | pass | - |
| P3-TC-17 | Unknown code; empty/long/non-string code | P1 | BE | pass | - |
| P3-TC-18 | GET /cart/coupons/ | P1 | BE | pass | - |
| P3-TC-19 | Coupon endpoints without a token / store header | P1 | BE | pass | - |
| P3-TC-20 | COD placement | P0 🔥 | BE | pass | - |
| P3-TC-21 | ONLINE placement, then cancel (T5) | P0 🔥 | BE | pass | - |
| P3-TC-22 | Same key + same body; same key + another body | P0 🔥 | BE | pass | - |
| P3-TC-23 | Key missing / short / spaces / 65 characters | P1 | BE | pass | - |
| P3-TC-24 | expected_grand_total ≠ bill | P0 🔥 | BE | pass | - |
| P3-TC-25 | Empty cart; unserviceable / unknown address; bad method | P0 | BE | pass | - |
| P3-TC-26 | Item total below the store minimum | P1 | BE | moved to P4-TC-49 (DL-50) | - |
| P3-TC-27 | A second placement while one is unpaid | P0 🔥 | BE | pass | - |
| P3-TC-28 | COD above ₹2,000 | P1 | BE | pass | - |
| P3-TC-29 | B retrieves/cancels/retries/verifies A's order | P0 🔥 | BE | pass | - |
| P3-TC-30 | GET /orders/?status=active/past/bogus, no token | P1 | BE | pass | - |
| P3-TC-31 | Cancel with a bad/missing reason; cancel a COD PLACED order | P1 | BE | pass | - |
| P3-TC-32 | The 06 §2.6 worked signature example | P2 | BE | pass | - |
| P3-TC-33 | Verify a valid signature ×3 | P0 🔥 | BE | pass | - |
| P3-TC-34 | Verify: zero signature, other secret, foreign gateway order, non-ASCII... | P0 🔥 | BE | pass | - |
| P3-TC-35 | Webhook: bad signature, signature of another body, no signature, no ev... | P0 🔥 | BE | pass | - |
| P3-TC-36 | payment.captured webhook, the same event again, a new event id, then v... | P0 🔥 | BE | pass | - |
| P3-TC-37 | Capture of the wrong amount | P0 | BE | pass | - |
| P3-TC-38 | Cancel, then verify + webhook for the same capture (T3a) | P0 🔥 | BE | pass | - |
| P3-TC-39 | Retry-payment (same key ×2), pay the new gateway order, then the old ... | P0 | BE | pass | - |
| P3-TC-40 | Retry without a key; retry on a cancelled order | P1 | BE | pass | - |
| P3-TC-41 | payment.failed, then capture, then payment.failed again | P1 | BE | pass | - |
| P3-TC-42 | Signed: unknown gateway order, unhandled type, malformed payload; garb... | P1 | BE | pass | - |
| P3-TC-43 | 5 customers race for the last 2 units (ONLINE, parallel) | P0 🔥 | BE | pass | - |
| P3-TC-44 | One Idempotency-Key sent 6× in parallel | P0 🔥 | BE | pass | - |
| P3-TC-45 | ONLINE order with a coupon, then T5 | P0 | BE | pass | - |
| P3-TC-46 | 31 placements within an hour | P1 | BE | pass | - |
| P3-TC-47 | Unpaid ONLINE order with a coupon: wait for the :8001 beat (T4), then ... | P0 | BE | pass | - |
| P3-TC-48 | SQL: order money identities over all orders | P0 🔥 | BE | pass | - |
| P3-TC-49 | SQL: 0 ≤ reserved ≤ on_hand, reserved ≥ Σ ACTIVE reservations, ... | P0 🔥 | BE | pass | - |
| P3-TC-50 | SQL: duplicate payment ids, two live captures, double refunds, duplica... | P0 🔥 | BE | pass | - |
| P3-TC-51 | SQL: history matches status; coupon counts within limits | P1 | BE | pass | - |
| P3-TC-52 | The same webhook event 6× in parallel | P0 | BE | pass | - |
| P3-TC-53 | Verify and cancel at the same instant (3 rounds) | P0 | BE | pass | - |
| P3-TC-54 | POST /orders/ without X-Store-Id; without the app headers | P1 | BE | pass | - |
| P3-TC-55 | WELCOME100 for a user with a PLACED order / with only cancelled unpaid... | P0 | BE | pass | - |
| P3-TC-56 | Clock profile (store closed): cart and POST /orders/ | P1 | BE | pass | - |
| P3-TC-57 | Signed webhook with a payment id over 64 / over 56 characters (refund) | P2 | BE | pass | BUG-0009 |
| P3-TC-58 | refund.processed replayed for a processed refund; refund.failed for an... | P1 | BE | pass | - |
| P3-TC-59 | 05 §3 P3 rows (DL-46): Catalog Manager manages coupons; Support/Finan... | P0 | ADM | pass | - |
| P3-TC-60 | Admin order/payment screens show the bill, history, payments and refun... | P1 | ADM | pass | - |
| P3-TC-61 | Coupon usage limits exhausted (per user, total); expired / not-started... | P1 | BE | pass | - |
| P3-TC-62 | COD for a cod_blocked user; store COD disabled | P1 | BE | pass | - |
| P3-TC-63 | Gateway unreachable at placement / retry | P1 | BE | moved to P4-TC-50 (DL-50) | - |
| P3-TC-64 | Customer app cart → checkout → pay (fake key) / COD → success; r... | P0 | CUS | pass on the phone per tracker T-306 (QA table still not run) | - |
| P3-TC-65 | refund.processed (no receipt) arrives before process_refund recorded t... | P0 | BE | pass | - |
| P3-TC-66 | refund.processed with the refund's receipt before the task, then the t... | P0 | BE | pass | - |
| P3-TC-67 | While payment A has an unrecorded PENDING refund: refund events for an... | P1 | BE | pass | - |
| P3-TC-68 | refund.failed (receipt-matched) before the task, then the task runs | P1 | BE | pass | - |
| P3-TC-69 | refundwindow profile (window 20 s): unmatched refund event inside the ... | P1 | BE | pass | - |

Totals: 69 cases. Pass 66 (95.7%), fail 0, moved to P4 2 (TC-26 and TC-63, DL-50), phone test 1 (TC-64, passed per tracker).
Not covered by any case yet: slab prices, the 5-carton minimum, WELCOME90 and referral coupons, and the tip/instructions reset. New ids must come from QA (this file does not invent ids).

## Exit criteria

| # | Criterion (`10 §5.2`) | State |
|---|---|---|
| 1 | All checklist tasks done or deferred with an owner | Not met: T-307, T-407c, T-409c open |
| 2 | CI green (lint, tests, coverage, migrations, schema) | Not met: not verified by QA; CI on the `develop` to `main` PR is pending |
| 3 | All cases run on staging: 100% of P0/P1 and at least 95% of all pass | Not met: 95.7% on the QA instance, not on staging |
| 4 | Regression smoke set of earlier phases passed | Met on the QA instance (77 passed at `9ed7ffc`; 138 passed at stage 3, `3a59367`) |
| 5 | No open P0/P1 bugs | Met: the open P3 bugs were BUG-0006 and BUG-0008 (both P3, at 2026-11-04) |
| 6 | Docs updated (feature docs, this file, schema) | Met for slabs and minimums (`03`, `06`, `07`, `08`, ADR 0001); re-check for the referral changes |
| 7 | Demo done and sign-off recorded | Not met |
| P3 | Coverage at least 90% on cart, payments and inventory services | Met per tracker (97.27% at T-303) |
| P3 | Bill matches an independent oracle | Met: P3-TC-02 and P3-TC-48 pass |

## Demo script (staging jqc.jivo.in)

For a non-developer. Use a phone with the customer app. Test login numbers: `+919000000001`, `+919000000002`, `+919000000003`, all with OTP `123456`.

1. Open the app and sign in with `+919000000001` and OTP `123456`. Expected: you reach Home.
2. Pick a delivery address that the store serves. Expected: the store shows as open.
3. Add water cartons to the cart, fewer than 5. Expected: the cart says "Add N more cartons to place your order (minimum 5 cartons)" and checkout is blocked.
4. Add more cartons until you have 5 or more. Expected: the message goes away. The price per carton drops when you reach a slab (the product page has a "Wholesale rates" table).
5. Open the coupon sheet and apply a coupon. Expected: the bill shows the discount. Check the total yourself: item total, minus discount, plus fees, plus tip.
6. Choose a tip and write delivery instructions. Expected: both are saved on the cart.
7. Choose Cash on delivery and place the order. Expected: a success screen. The order is PLACED.
8. Open the cart again. Expected: the tip and instructions are empty (they reset after an order).
9. Start an order above ₹2,000. Expected: Cash on delivery is greyed out with a reason, and Online is selected.
10. Pay online with the Razorpay test method (or the fake gateway). Expected: success, and the order is paid.
11. Start another order and cancel it before paying. Expected: it is cancelled and the coupon use comes back.
12. In the admin panel, open the order. Expected: the bill, history and payment are shown and are read-only.

## Sign-off

```
Phase 3 sign-off
- Test run date:        YYYY-MM-DD
- Build / commit:       backend <sha>, customer_app <version+build>, rider_app <version+build>
- Cases executed:       X / Y   Passed: X   Failed: X   Deferred: X
- Open bugs:            P0: 0  P1: 0  P2: n  P3: n
- Demo given to:        <names, roles>
- Approved by:          <name, role>  on  YYYY-MM-DD
- Notes / deferrals:
```

## Open questions

1. **WELCOME90:** the brief names it, but no source in `docs/`, `qa/docs/`, `backend/apps` or git history contains "WELCOME90" (QA tests WELCOME100 in P3-TC-55). Only the ₹90 referral reward coupon appears (`65c9248`). Confirm the code and its rules.
2. **P3-TC-64:** the tracker (T-306) and the roadmap say it passed on the phone; `qa/docs/02` still shows it not run. QA to update.
3. **T-409c** is cited in DL-53 and T-412, but the tracker has no row for it. Does it exist?
4. **Gate evidence:** DL-50 says the gate is CI on the `develop` to `main` PR, while `10 §5` asks for a staging run. Which applies?
5. **COD limit:** `08` and P3-TC-28 use ₹2,000 (kept by the user on 2026-11-14). No decision-log entry records this yet (the log ends at DL-71).
6. **Slabs, minimums and referral coupons** have no QA case ids yet.
