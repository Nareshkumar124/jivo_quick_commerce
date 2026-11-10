# Screen spec: Home active order card (part of screen 14, Home)

- **Status:** ready for implementation. Version 1, 2026-11-10.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/home/presentation/home_screen.dart` (a new sliver under the search bar)
  - `customer_app/lib/features/orders/presentation/pending_payment.dart` (share one active-orders read, §5)
  - a new widget, for example `features/orders/presentation/active_order_card.dart`
- **Sources:** `docs/03-customer-app.md` §2.5, §2.9 (pending payment) and §2.10 (tracking); `docs/08-order-lifecycle.md` §1 (labels). Audit finding CA-10 in `design/audits/2026-11-10-customer-app.md`. Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - **Existing API fields only.** The card uses `GET /orders/?status=active` (already called by Home for the pending-payment banner) and the order socket's `order.status` events. From each order it reads only `id`, `order_number`, `status` and `eta_at` (the app's `PlacedOrder`).
  - The status words are the `08 §1` customer labels (`orderStatusLabel`). The card never shows money and never shows the delivery OTP itself (the OTP is only on tracking and the order detail).
  - Times are shown in IST with the existing `formatTime`. The card shows "Arriving by 3:45 pm" from the server's `eta_at`; it doesn't count minutes down (that is tracking's job).
  - **No H-22 decision blocks this spec.**
- **Who sees it:** signed-in customers with at least one active order that isn't waiting for payment. In builds where the cart is off (staging and prod until S3-B), there are no orders, so the card never shows.

## 1. Where it sits

```
┌──────────────────────────────────────┐
│ Delivery in 14 mins ▾        [acct]  │  header (unchanged)
│ [ 🔍 Search for oils, atta, ghee  ]  │  search bar (unchanged)
│ [Pending payment banner]  (CA-23)    │  only for PAYMENT_PENDING
│ ┌──────────────────────────────────┐ │
│ │ 🛵  On the way                    │ │  ACTIVE ORDER CARD (§2)
│ │     Arriving by 3:45 pm          │ │
│ │     Delivery OTP ready   Track › │ │
│ └──────────────────────────────────┘ │
│   +1 more order in progress · See all│  only with 2+ orders (§4)
│ [Update prompt]                      │
│ [Store closed banner]                │
│ banners, categories, rails …         │
└──────────────────────────────────────┘
```

- **Order of the top slivers:** header, search bar, pending-payment banner, **active order card**, "more orders" row, update prompt, store-closed banner, then the content.
- **It shows in every Home state**, including "Choose a delivery location", "not serviceable" and the feed error states. An order in progress doesn't depend on the current location.
- **Padding:** 16 dp left and right (`space.gutter`), 0 dp top, 12 dp bottom (`space.md`).

## 2. Card anatomy

A full-width `Material` card, radius 12 dp (`radius.md`), min height **64 dp**, padding 12 dp vertical and 16 dp horizontal. **The whole card is one button** (one tap target, one screen-reader stop). "Track ›" is a visual label inside it, not a second button.

| Part | Spec |
|---|---|
| Leading icon | 28 dp, colour as the state (§3), `ExcludeSemantics` |
| Line 1: status | `titleMedium` 16 sp / 700, 2 lines max (3 lines from 1.5× text) |
| Line 2: arrival | `bodyMedium` 14 sp, "Arriving by 3:45 pm" (`orderArrivingBy` with `formatTime(eta_at)`). Without `eta_at`: "Order JV-261103-000123" (`orderNumber`) |
| Line 3 (only while `OUT_FOR_DELIVERY`) | `bodyMedium` 14 sp / 600: "**Delivery OTP ready**" with a 16 dp `pin` icon. It tells the customer to open the order; the OTP is never on Home. |
| Trailing label | "Track ›" or "Details ›" (§3), `labelLarge` 14 sp / 600, vertically centred |

## 3. States by order status

| Order status (the shown order) | Shown? | Background / text (ratio) | Icon | Line 1 (`08 §1`) | Line 2 / 3 | Trailing | Tap opens |
|---|---|---|---|---|---|---|---|
| `PAYMENT_PENDING` | **No**: the pending-payment banner handles it | n/a | n/a | n/a | n/a | n/a | n/a |
| `PLACED` | yes | `brand.primaryContainer` / `brand.onPrimaryContainer` (13.24:1) | `receipt_long` | Order placed | Arriving by {time} | Track › | tracking* |
| `ACCEPTED` | yes | same | `thumb_up_alt` | Order confirmed | Arriving by {time} | Track › | tracking* |
| `PACKING` | yes | same | `inventory_2` | Packing your order | Arriving by {time} | Track › | tracking* |
| `PACKED` | yes | same | `inventory` | Packed, rider on the way to store | Arriving by {time} | Track › | tracking* |
| `OUT_FOR_DELIVERY` | yes | same | `delivery_dining` | On the way | Arriving by {time} · line 3 "Delivery OTP ready" | Track › | tracking* |
| `DELIVERY_FAILED` (non-terminal until `RETURNED`) | yes | `danger.container` / `danger.onContainer` (13.26:1) | `error_outline` | Delivery unsuccessful | We couldn't deliver it. See what happens next. | Details › | order detail |
| Unknown status (newer server) | yes | `surface.highest` / `text.primary` (13.27:1) | `info_outline` | Status unavailable | Order {number} | Details › | order detail |
| A terminal status reported **while Home is open** (`DELIVERED`, `CANCELLED`, `PAYMENT_FAILED`, `RETURNED`, from the socket) | yes, until Home is left or refreshed | `surface.card` / `text.primary` (15.49:1) | `check_circle` in `success.fg` for Delivered; `cancel` in `danger.fg` otherwise | the `08 §1` label ("Delivered", "Cancelled", …) | Order {number} | Details › | order detail |

\* **"Tracking"** means the live tracking screen when `trackingAvailableProvider` is true (the same rule as the order detail's Track button); otherwise the order detail.

- The status is always written in words; colour and icon only repeat it.
- An order that disappears from the active list on a refresh (finished while Home was not visible) simply drops the card. No "Delivered" state is shown for it.

## 4. Several active orders

- **The card shows one order:** the first order in the server's active list that is not `PAYMENT_PENDING`. The server returns active orders newest first (`-created_at`), the same order My orders uses.
- **With 2 or more such orders**, a row under the card: "**+1 more order in progress** · See all" (plural: "+2 more orders in progress"), `bodyMedium`, `text.secondary` for the count and `brand.primary` for "See all" (6.08:1). The whole row is one 48 dp button that opens **My orders** (`Routes.orders`).
- **Pending payment plus an active order:** both show (banner first, then the card). The server allows only one order waiting for payment at a time.

## 5. Data and refresh rules

- **One read for both widgets.** Move the `activeOrders()` call into a shared provider (for example `activeOrdersProvider`, an `AsyncNotifier<List<PlacedOrder>>`). `PendingPaymentController` derives its order from it, and the card takes the first non-pending order. Home then makes one request instead of two.
- **When to re-read** the list (quietly, keeping the current card while loading):
  | Trigger | Rule |
  |---|---|
  | Home first shown | always (as today's banner check) |
  | Home pull-to-refresh | always (already wired through `pendingPaymentProvider`) |
  | App resumed (`AppLifecycleState.resumed`) | when Home is the current tab |
  | Back on the Home tab | when the last read is older than 30 s |
  | An order was placed, paid, cancelled or retried | mark stale; re-read when Home shows (`refreshPendingPayment` already marks these moments) |
  | Socket `order.status` for the shown order | update line 1 at once from the event, then re-read the list quietly |
  | Socket not live (realtime off or dropped) | re-read every **60 s** while Home is visible and the card is showing; stop when the socket is live again or Home is hidden |
- **Socket use:** listen to `orderStatusEventsProvider(order.id)` for the **shown order only**. The provider is shared per order, so this socket is the same one My orders, the order detail and tracking use for that order. Because only one order can wait for payment, the shown order is always among the first two active orders My orders opens sockets for, so the worst case stays at 4 sockets per user (under the server's `WS_MAX_SOCKETS_PER_USER` of 5).
- **Errors:** a failed re-read keeps the last card as it is; Home shows no error for the card. If the first read fails, there is no card, and the next trigger tries again.
- **Loading:** no skeleton (most customers have no active order, and a placeholder would push Home down for them). The card appears when the data arrives, with a 200 ms size animation (`AnimatedSize`), or none under reduced motion (`MediaQuery.disableAnimations`).

## 6. Copy (new strings; suggested ARB keys)

| Key | Text |
|---|---|
| `activeOrderTrack` | Track |
| `activeOrderDetails` | Details |
| `activeOrderOtpReady` | Delivery OTP ready |
| `activeOrderDeliveryFailedBody` | We couldn't deliver it. See what happens next. |
| `activeOrderMore` | {count, plural, =1{+1 more order in progress} other{+{count} more orders in progress}} |
| `activeOrderSeeAll` | See all |
| `activeOrderSemantics` | {status}. {detail}. Opens {destination}. (for example "On the way. Arriving by 3:45 pm. Delivery OTP ready. Opens tracking.") |

Reused: `orderStatusLabel` (`08 §1`), `orderArrivingBy` ("Arriving by {time}"), `orderNumber` ("Order {number}"), `orderStatusUnknown`.

## 7. Content rules

- **Line 1** wraps to 2 lines (3 from 1.5× text), then "…". The text column is about 196 dp wide on a 360 dp phone, so "Packed, rider on the way to store" (about 280 dp at 16 sp / 700) already takes 2 lines at 1.0×; that is expected. From 1.5× the trailing label moves down (§8), giving line 1 the full width. The full label is in the semantics.
- **Order number** is shown as sent, never shortened.
- **No ETA arithmetic:** no "in 8 mins", no "late" here. A passed ETA still shows "Arriving by {time}"; tracking explains delays (see `tracking-layout.md`).

## 8. Accessibility and text scaling

- **Semantics:** `Semantics(button: true, label: activeOrderSemantics)` with `excludeSemantics: true` on the content. Make it a live region only for the status line change that comes from the socket (announce "Order on the way" once per change, not on every rebuild).
- **Contrast:** `brand.onPrimaryContainer` on `brand.primaryContainer` 13.24:1; `danger.onContainer` on `danger.container` 13.26:1; `text.primary` on `surface.card` 15.49:1 and on `surface.highest` 13.27:1; `brand.primary` on `surface.base` 6.08:1 ("See all").
- **Touch targets:** the card is at least 64 dp high and full width; the "more orders" row is 48 dp.
- **Text scale:** from 1.5× (`textScale.singleColumnFrom`), "Track ›" moves under the text lines, left-aligned, so the status keeps the full width. At 2.0× on 360×640, the card may grow to about 180 dp; it must not overflow, and the home content scrolls under it as usual.
- **Reduced motion:** no size animation.

## 9. APIs required

None. Optional later improvement (not needed for this spec): if the active list ever stops being newest-first, the backend should say so, because the socket-count reasoning in §5 relies on that order.

## 10. Acceptance checks (for the developer and QA)

- [ ] With one order in `PLACED`, `ACCEPTED`, `PACKING`, `PACKED` or `OUT_FOR_DELIVERY`, Home shows the card with the `08 §1` label and "Arriving by {time}" in IST; the whole card is one button and opens tracking (or the order detail where tracking is off).
- [ ] `OUT_FOR_DELIVERY` adds "Delivery OTP ready" and never shows the OTP digits.
- [ ] A `PAYMENT_PENDING` order shows only the pending-payment banner, never the card.
- [ ] `DELIVERY_FAILED` shows the red variant with "Details ›", opening the order detail.
- [ ] With two active orders, the newest shows, and "+1 more order in progress · See all" opens My orders.
- [ ] A socket status change updates the card at once; a terminal status while Home is open shows the final state until Home is left or refreshed.
- [ ] Home makes one `GET /orders/?status=active` per trigger (shared with the pending-payment banner); a failed re-read keeps the card unchanged.
- [ ] With the socket down, the list is re-read every 60 s only while Home is visible.
- [ ] No more than 4 order sockets are open when Home, My orders and one order detail are all in use.
- [ ] Widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
