# 04: Functional Testing Report

**Date:** 2026-11-02 (QA run 1) · **Build:** backend `4960527`; apps at the same commit (static review only) · **Environment:** QA instance `127.0.0.1:8004`. Cases and statuses: [02-test-case-repository.md](02-test-case-repository.md).

## Backend features (executed black-box)
| Feature (doc) | Result | Notes |
|---|---|---|
| Phone OTP login, customer and rider (06 §2.1, 03 §2.2, 04 §2.1) | ✅ | New and returning user flags, `rider_status: NONE`, `app` claim, consent version stored |
| OTP errors and lockout (06 §2.1) | ✅ / ❌ | Attempts counting, expiry, single use, supersede ✅. Some non-ASCII numeric input is accepted ❌ BUG-0002. |
| Session: refresh rotation, logout (06 §2.1) | ✅ / ❌ | ❌ BUG-0003 (details private); sequential rotation and reuse rejection ✅ |
| Profile view/edit (03 §2.11) | ✅ | Name trimmed and required; email lowercased, clearable, unique with a generic error |
| Push device registration (06 §2.1) | ✅ | Upsert by token, moves between users, deactivated on logout |
| Account deletion and restore (03 §2.2, 07 §4) | ✅ | 30-day `anonymise_after`; tokens and devices revoked; restore on login during grace. Anonymisation job ⏭. |
| Saved addresses (03 §2.4 P1 basic) | ✅ / ❌ | CRUD, one default, promotion on delete, soft delete, ordering ✅. Pagination 404 undocumented (BUG-0004). The concurrent set-default race can leave no default (BUG-0007). |
| App config / splash data (03 §2.1) | ✅ | Per app/platform policy, nulls without headers, OTP and rider-location settings, feature flags |
| Force update / maintenance (03 §2.1, 04 §2.1) | ⏭ | Positive cases need a shared `AppConfig` change; the negative "no 426" rules ✅ |
| Staff login, roles, Customers block/unblock (05 §2–3) | ✅ / ⏭ | Role matrix per page ⏭ to run 2. Session lifetime ❌ BUG-0006. |

## Mobile features (03 §2.1/2.2/2.4/2.11, 04 §2.1)
Not executed on a device this run: no Flutter commands, phone or emulator allowed. Static review of commit `4960527` found the following:
- Customer addresses and account screens implement loading (`SkeletonList`), empty (`EmptyView`) and error-with-retry (`ErrorRetryView`) states (03 §4).
- The address repository pages through all results.
- Session tokens are in `FlutterSecureStorage`. The `jivo_core` `AuthInterceptor` refreshes single-flight and retries once.
- No client-side money (none in P1).

**Remaining on device** (P1-TC-80…92):
- splash routing and onboarding
- force update and maintenance screens
- +91 validation and consent
- the OTP screen (autofill, 30 s resend, error messages)
- complete profile, logout, delete account
- profile edit and address CRUD
- offline banner
- rider login and `rider_status` routing

The dev agents report 62 customer, 112 rider and 75 `jivo_core` tests plus real-API integration tests. QA has **not** verified these (no Flutter this run).

## Phase 3 stage 1 (2026-11-04, `c2c153a`, executed black-box on :8004)
| Feature (doc) | Result | Notes |
|---|---|---|
| Cart bill = 08 §6.2 (fees and thresholds on item_total, half-up, 2-dp strings) | ✅ | An independent oracle from DB prices; 5 cart shapes, plus coupon cases |
| Cart set-quantity, max qty, stock flags, never reserves | ✅ | P3-TC-04…06 |
| Tip (0–500), instructions, address serviceability, preview | ✅ | P3-TC-07/08 |
| Coupons FLAT / PERCENT / cap / category eligible subtotal / min order / first order / stops applying / sheet | ✅ | Usage exhaustion and expiry ⏭ (QA coupon needed, T-304) |
| COD placement (T2) and ONLINE placement (T1), snapshot, reservation, cart handling | ✅ | R2b re-run |
| Idempotency-Key replay, reuse, parallel; PRICE_CHANGED; one unpaid order (DL-44) | ✅ | |
| Verify (T3), webhook (T3), payment.failed, retry-payment, duplicate capture (DL-45) | ✅ | |
| Cancel unpaid (T5); expiry (T4, :8001 beat); late capture (T3a) and auto-refund | ✅ | T4 was observed 45 s after the window ended |
| Store closed blocks checkout | ✅ | Clock profile |
| COD blocked user / COD disabled; gateway down 503 | ⏭ | Admin/shared config; fault injection |
| Admin P3 screens and roles (05 §3, DL-46) | ⏭ | T-304 in progress |
| Customer app P3 screens | ⬜ | No device this run |

## Phase 3 stage 2 (2026-11-04, `f84482f`)
| Feature | Result |
|---|---|
| Admin P3 role matrix (coupons, redemptions, orders, payments, refunds, webhook events; 7 roles) | ✅ |
| Order/payment admin screens read-only; PII masked for roles without PII | ✅ |
| Coupon creation in admin; validity (expired / not started / inactive); usage limits incl. holds; last-use race | ✅ |
| COD blocked customer (admin action) | ✅. Store COD disabled ⏭ (PM: demo store in use) |
| Webhook malformed ids (BUG-0009) | ✅ fixed |
| Customer app P3 | ⬜ the user's phone test |

## Phase 3 refund re-check (2026-11-04, `9ed7ffc`, T-310)
- Refund behaviour after the T-303 fixes, black-box on :8004: T3a late capture, wrong-amount capture and duplicate capture (DL-45) each make exactly one refund that settles to PROCESSED; the T4 expiry plus late capture (P3-TC-47) settles to REFUNDED. Results: P3-TC-37/38/39/47/58 ✅. Details and commands are in 03.
- Phase 4 functional cases P4-TC-01…60 are written (02, plan in 01 §8). They are not executed yet: they are awaiting the P4 R2 merge.

## Phase 4 stage 1 (2026-11-04, `1b3552d`, T-416)
**Store and ops actions** (T6/T7/T8/T8a/T12, manual refund, retry, `sync_refund_status`, SLA alert) were driven through the **backend services** (`apps.orders.store_ops`, `apps.payments.order_refunds`) by `qa/tools/store_ops_driver.py`, run in the QA worktree backend with the QA environment, as the seeded staff users, because the Ops Console (admin P4) is not merged. The driver refuses any order that is not a QA customer's. Console pages, HTMX, CSRF and hidden-button checks stay ⏭.

- **Customer cancel (08 §7, T11):** PLACED and ACCEPTED cancel (COD → `FAILED`, nothing due; ONLINE → one full ORDER_CANCELLED refund, REFUNDED after the worker); PACKING/PACKED → 409 `{status}`, `can_cancel` false, nothing released. `CUSTOMER_CANCEL_UNTIL=PLACED` respected.
- **Store flow (T6/T7/T8):** accept assigns a 4-character pickup code; history actor_type `store`; customer timeline "Order confirmed" → packing → packed; out-of-order actions refused with no history change (incl. PAYMENT_PENDING and CANCELLED).
- **T8a (08 §6.3)** matches QA's independent oracle on every field (2×Sun+Canola ONLINE and COD; Sun + 3 sachets below both thresholds: fees stay 0.00; JIVO50 coupon kept at 50.00 below its minimum). Refund = old − new; the same value submitted twice refunds once; all units unavailable → CANCELLED (ITEMS_UNAVAILABLE, store), refunds total = amount paid.
- **T12** in PLACED, ACCEPTED, PACKING, PACKED: full refund, reservation released, **no StockMovement, no on_hand change**; customer-only / empty reasons refused.
- **Reorder:** raise-to-ordered (never on top, never lowered), idempotent, no reservation; OUT_OF_STOCK / LIMITED_STOCK with `added_quantity`.
- **Refunds:** Support limit 500.00 ok / 500.01 refused; Finance no limit; cap ("At most …") enforced; manual partial → PARTIALLY_REFUNDED → REFUNDED; FAILED (refund.failed webhook) shown to the customer as PENDING; retry → `cancel:<id>:retry-1`; a second retry refused; the original queued task never resent the FAILED refund; `sync_refund_status` re-queued a stuck refund twice and exactly one gateway refund resulted.
- **Hygiene:** the 38 QA orders left PLACED by P3 were cancelled with T11 (31 ONLINE → REFUNDED, ₹6,249 = Σ amount_paid; 7 COD → FAILED; the 5 with an earlier duplicate-capture refund got exactly one more refund, so each capture was refunded once). 9 more left by the smoke run and order 280 (PACKING, T12) were cancelled at the end. No QA order is open; the remaining reservations (variant 1: 7, variant 3: 1) are not QA orders'.
