# Screen spec: "Item couldn't be supplied" notice (order detail and tracking)

- **Status:** ready for implementation. Version 1, 2026-11-10. **No decision needed.**
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/orders/domain/order_history.dart` (`OrderRefund`: add `reason`) and `features/orders/data/api_order_history_repository.dart` (map it)
  - `customer_app/lib/features/orders/presentation/order_detail_screen.dart` (the notice, the item row, a line under the bill)
  - `customer_app/lib/features/tracking/presentation/tracking_screen.dart` (the same notice, in the slot from `tracking-layout.md` §1 item 8)
  - a new widget, for example `features/orders/presentation/unavailable_notice.dart`
- **Sources:** `docs/08-order-lifecycle.md` §6.3 (partial unavailability, T8a) and §6.4 (refunds); `docs/05-admin-and-store-panel.md` §1.3 ("Item unavailable": the system adjusts the order, refunds the difference or reduces the COD due, and notifies the customer). Audit finding CA-27 in `design/audits/2026-11-10-customer-app.md`. Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - **Existing API fields only.** From `GET /orders/{id}/`: each line's `quantity`, `quantity_unavailable`, `product_name` and `variant_name`; `refunds[]` with `amount`, `status`, `reason` (`OrderRefundReasonEnum`, which includes `ITEMS_UNAVAILABLE`) and `processed_at`; `payment_method`, `payment_status`, `status`, `bill.grand_total` and `cancellation.reason`. The app model drops `refunds[].reason` today; mapping it is the only data change.
  - **No money is computed.** Every amount is a server string shown with `formatRupeesOrNull`. Refunds are listed one by one, never added up. The app only compares two integers per line (`quantity_unavailable` against `quantity`) to choose between "1 of 2" and "not supplied", and counts affected lines for the title.
- **Who sees it:** the order's customer, whenever at least one line has `quantity_unavailable > 0`.

## 1. Where it shows

| Screen | Place |
|---|---|
| Order detail | Directly under the status block (headline, "Arriving by", store name), above the stage card, the OTP and the COD card. |
| Live tracking | The notices slot (`tracking-layout.md` §1, item 8), when the order detail has loaded on that screen. |
| Items section (order detail) | Each affected line gets its own marker (§4). |
| Bill (order detail) | One line under "To pay" (§5). |

The Home active order card and My orders don't show it (they carry no line data). The order detail is one tap away.

## 2. The notice

```
┌──────────────────────────────────────┐
│ ⓘ 1 item couldn't be supplied        │  title, titleSmall 14 sp / 700
│   Jivo Canola Oil 1 L: 1 of 2        │  one line per affected product (max 2)
│   ₹250 is being refunded to your     │  money line (§3), bodyMedium / 600
│   original payment method.           │
└──────────────────────────────────────┘
```

| Part | Spec |
|---|---|
| Container | `warning.tint` (#FFF4D6) background, a 2 dp left border in `warning.fg` (#8A5300), `radius.sm`, 12 dp padding, full width |
| Icon | `info` 20 dp in `warning.fg` (5.78:1, non-text) |
| Title | "**{n} item couldn't be supplied**" / "**{n} items couldn't be supplied**", where n is the number of affected lines. `text.primary` (15.62:1) |
| Lines | "{product} {variant}: {unavailable} of {quantity}" when part of the line was supplied; "{product} {variant}: not supplied" when `quantity_unavailable == quantity`. `bodyMedium`, `text.primary`. At most 2 lines, then "and {k} more" (the Items section lists them all). |
| Money line | §3, `bodyMedium` / 600, `text.primary` |
| Action | none; the whole notice is information. A "See items" link isn't needed: the items are on the same screen. |

## 3. The money line (by payment and state)

| Case | How the app knows | Money line |
|---|---|---|
| Paid online, refund started | a refund with `reason = ITEMS_UNAVAILABLE` and `status = PENDING` | "**₹250** is being refunded to your original payment method. It usually takes 5–7 working days." |
| Paid online, refund done | that refund with `status = PROCESSED` | "**₹250** refunded to your original payment method on 9 Nov." (`formatDate(processed_at)`, IST) |
| Paid online, more than one such refund | several `ITEMS_UNAVAILABLE` refunds | one line per refund, newest first, each with its own status text (never a total) |
| Paid online, no refund yet | no `ITEMS_UNAVAILABLE` refund in the list | "Your refund for these items is being set up. You'll see it here." |
| Cash on delivery, still to pay | `codAmountDue` is not null | "You're not charged for them. **Pay ₹990** to the rider." (the server's `bill.grand_total`, as the COD card shows) |
| Cash on delivery, after delivery or once collected | `codAmountDue` is null | "You weren't charged for them." |
| Every item unavailable, order cancelled | `status = CANCELLED` and `cancellation.reason = ITEMS_UNAVAILABLE` | Title becomes "**None of your items could be supplied**", body "So the order was cancelled." Then the refund line as above for an online order, or "Nothing to pay." for COD. The existing cancellation section stays below. |
| Unknown payment method (newer server) | `paymentMethod` is null | no money line |

- **Amounts:** if a refund amount can't be read, drop that line rather than showing "₹" alone.
- **Wording:** never "out of stock" (the customer can't act on it); never blame the store.

## 4. Item row marker (Items section)

Today the row shows "{count} unit(s) were unavailable and are not charged" in red. Change it to a marker that reads clearly and isn't red-only:
- Icon `remove_shopping_cart` 16 dp in `warning.fg`, then "**1 of 2 not supplied**" (or "**Not supplied**" for the whole line), `bodySmall` / 600, `text.primary`.
- The line total stays the server's `line_total`.
- Screen reader: "Jivo Canola Oil 1 L, 1 of 2 not supplied, ₹249."

## 5. Bill note

Under "To pay" in the order detail bill, when any line is affected: "Updated after {n} item(s) couldn't be supplied." (`bodySmall`, `text.secondary`, 8.91:1). The bill rows themselves are the server's recomputed values, as today.

## 6. When the notice appears and refreshes

- The store can mark items unavailable while the order is `ACCEPTED` or `PACKING`. That doesn't change the order status, so the screens learn about it from the next order read: pull to refresh, opening the screen, app resume, or the next status change (`PACKED` re-reads the order, as today).
- **Announce once:** when the notice appears on a screen that is already open (after a quiet re-read), wrap it in `Semantics(liveRegion: true)` for that first build only, so a screen reader says "1 item couldn't be supplied" once.
- A push for this event waits for D-19 (backend, CA-27).

## 7. Copy (suggested ARB keys)

| Key | Text |
|---|---|
| `unavailableTitle` | {count, plural, =1{1 item couldn't be supplied} other{{count} items couldn't be supplied}} |
| `unavailableNoneTitle` | None of your items could be supplied |
| `unavailableNoneBody` | So the order was cancelled. |
| `unavailablePartLine` | {name}: {unavailable} of {quantity} |
| `unavailableAllLine` | {name}: not supplied |
| `unavailableMore` | {count, plural, =1{and 1 more} other{and {count} more}} |
| `unavailableRefundPending` | {amount} is being refunded to your original payment method. It usually takes 5–7 working days. |
| `unavailableRefundDone` | {amount} refunded to your original payment method on {date}. |
| `unavailableRefundSettingUp` | Your refund for these items is being set up. You'll see it here. |
| `unavailableCodDue` | You're not charged for them. Pay {amount} to the rider. |
| `unavailableCodDone` | You weren't charged for them. |
| `unavailableNothingToPay` | Nothing to pay. |
| `orderLineNotSuppliedPart` | {unavailable} of {quantity} not supplied |
| `orderLineNotSuppliedAll` | Not supplied |
| `billUpdatedAfterUnavailable` | {count, plural, =1{Updated after 1 item couldn't be supplied.} other{Updated after {count} items couldn't be supplied.}} |

`orderLineUnavailable` ("1 unit was unavailable and is not charged") is retired.

## 8. Content rules

- **Product names:** "{product} {variant}" on one line, ellipsized at 2 lines in the notice; full in the Items section and the semantics.
- **Hindi (D-24):** the notice has no fixed height; every line wraps.
- **Text scaling:** at 2.0× on 360×640 the notice may grow to about 220 dp; it must not overflow. Include it in the order detail rows of `design/system/text-scaling-checklist.md`.

## 9. Accessibility

- **Contrast:** `text.primary` on `warning.tint` 15.62:1; `warning.fg` icon and border 5.78:1; `text.secondary` bill note 8.91:1.
- **Not colour alone:** the icon, the title and the words "not supplied" carry the meaning.
- **One semantics node** for the notice (`MergeSemantics`), read as: title, lines, money line.

## 10. APIs required

None. Optional later (backend, after D-19): a push "1 item in your order couldn't be supplied", opening the order detail.

## 11. Acceptance checks (for the developer and QA)

- [ ] `OrderRefund` carries `reason`, mapped from `refunds[].reason`; an unknown reason doesn't break the screen.
- [ ] With one affected line, the order detail shows the notice under the status block with "1 item couldn't be supplied" and the line "{name}: 1 of 2".
- [ ] Paid online: the money line follows the `ITEMS_UNAVAILABLE` refund's status (pending, processed with the IST date, or "being set up" when absent); several refunds are listed separately, never summed.
- [ ] Cash on delivery: the line says "Pay {cod_amount_due}" while the cash is due and "You weren't charged for them" afterwards.
- [ ] All items unavailable and the order cancelled with `ITEMS_UNAVAILABLE`: the "None of your items could be supplied" variant shows, and the cancellation section stays.
- [ ] The item row shows the "not supplied" marker with its icon; the bill shows the "Updated after…" note.
- [ ] Tracking shows the same notice in its notices slot.
- [ ] Widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
