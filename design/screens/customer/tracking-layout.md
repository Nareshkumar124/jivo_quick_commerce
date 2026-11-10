# Screen spec: Live tracking layout (screen 28)

- **Status:** ready for implementation. Version 1, 2026-11-10.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/tracking/presentation/tracking_screen.dart` (`_TrackBody` order, `EtaCountdown`)
  - `customer_app/lib/features/tracking/presentation/tracking_providers.dart` (`TrackController`: expose freshness, §3)
  - `customer_app/lib/features/tracking/presentation/delivery_cards.dart` (`DeliveryOtpCard`, `RiderCard`)
- **Sources:** `docs/03-customer-app.md` §2.10 (tracking, socket and polling behaviour); `docs/06-backend-modules-and-api.md` §2.6 (`track/`) and §4 (order socket); `docs/08-order-lifecycle.md` §1 (labels), §2.1 (dispatch), §8 (ETA). Audit findings CA-25 (OTP below the map), CA-26 (freshness, late) and CA-27 (items not supplied) in `design/audits/2026-11-10-customer-app.md`. Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - The ETA is the server's (`eta_at`, `order.eta` events). The app only compares it with the phone's clock to show "Arriving in 8 mins" or the late message; it never estimates a new ETA.
  - The delivery OTP comes only from `GET /orders/{id}/track/` (never the socket) and only while `OUT_FOR_DELIVERY`.
  - Money (the COD amount, refunds) comes from the order detail, as today. Nothing is computed.
  - **No new API, and no H-22 decision blocks this spec.**
- **Who sees it:** the order's customer, from "Track" on the order detail, the Home active order card, or a push / inbox link.

## 1. Order of content

```
┌──────────────────────────────────────┐
│ AppBar: "Track order"                │
├──────────────────────────────────────┤
│ On the way                           │ 1 status headline (live region)
│ Arriving in 8 mins                   │ 2 ETA line (§2)
│ ● Live                               │ 3 freshness line (§3)
│ ┌──────────────────────────────────┐ │
│ │ Delivery OTP                     │ │ 4 OTP card (§4), only OUT_FOR_DELIVERY
│ │        4  8  2  7                │ │
│ │ Share it at the door, only when… │ │
│ └──────────────────────────────────┘ │
│ [Pay ₹990 to the rider]              │ 5 COD card, COD orders only
│ [👤 Ravi · Location updated 1 min ago  📞]│ 6 rider row (§5)
│ [Stage card: Rider is arriving]      │ 7 stage card (picked up / arriving / failed / returned)
│ [Notice: 1 item couldn't be supplied]│ 8 notices (CA-27), when the order detail has them
│ ┌──────────────────────────────────┐ │
│ │            MAP 220 dp            │ │ 9 map, or the route sketch (120 dp)
│ └──────────────────────────────────┘ │
│ Timeline                             │ 10 status timeline
│ [ Order details ]                    │ 11 outlined button, 48 dp
└──────────────────────────────────────┘
```

- **Why this order:** at the door, the customer needs the OTP, the cash amount and the rider's call button, in that order. The map is the least urgent part and the tallest (220 dp), so it comes after them. On a 360×640 phone the OTP card now starts at about 200 dp from the top at 1.0× text (today about 490 dp), and it stays on the first screen at 2.0×.
- **Spacing:** 16 dp gutter (`space.gutter`); 12 dp (`space.md`) between items 1–3, 16 dp (`space.lg`) between cards.
- **Items that are missing simply don't render** (no empty boxes).

## 2. Status headline and ETA line

- **Headline:** the `08 §1` label (`orderStatusLabel`), `headlineSmall` 24 sp / 700, `text.primary` (16.22:1), `Semantics(liveRegion: true)` (as today).
- **ETA line** (`titleMedium` 16 sp / 500), recomputed every 30 s (`motion.etaTick`) and whenever a new `eta_at` arrives:

| Condition (order active) | Text | Style |
|---|---|---|
| `eta_at` in the future | "Arriving in {n} mins" (existing `trackingEtaMinutes`, rounded up) | `text.primary` |
| `eta_at` passed up to 5 minutes ago (`motion.etaLateAfter`) | "Arriving any moment" (existing) | `text.primary` |
| `eta_at` passed more than 5 minutes ago, `OUT_FOR_DELIVERY` | "**Running a little late.** Your rider is on the way." | notice: `warning.tint` background, `text.primary` (15.62:1), icon `schedule` in `warning.fg`, 12 dp padding |
| `eta_at` passed more than 5 minutes ago, before pickup (`PLACED` to `PACKED`) | "**Taking a little longer than planned.** Your order is being prepared." | same notice style |
| No `eta_at` | no ETA line | n/a |
| Order finished | no ETA line (see §6) | n/a |

- **"Get help" in the late notice:** a 48 dp `TextButton` "Get help" that opens a new ticket for this order (`Routes.newTicket(orderId: …)`) when support is available in the build; otherwise "Call support" when `config/app` has a support phone; otherwise no button.
- **A new, later `eta_at`** (from `order.eta` or a re-read) replaces the late notice with "Arriving in {n} mins" at once.
- The late wording never blames anyone and never promises compensation.

## 3. Freshness line (socket and polling)

The line tells the customer whether what they see is current. It needs one small addition to `TrackController`: a freshness state, for example `TrackFreshness { mode: live | polling | stale, lastUpdatedAt }`, where `lastUpdatedAt` is the **phone's time when the app last received track data** (a successful `track/` read or a socket message). This is app state; no API change.

| Mode | When | Text (`bodySmall`, 12 sp) | Icon / colour |
|---|---|---|---|
| **Live** | the order socket is live (`OrderSocket.live` is true, between `auth.ok` and a close) | "Live" | 8 dp dot in `success.fg`; the word in `success.fg` (7.46:1) |
| **Polling** | the socket is down or off, and the last `track/` read succeeded | "Updated {time}" (`formatTime`, IST) | `sync` 16 dp, `text.secondary` (8.91:1) |
| **Stale** | the last `track/` read failed (the controller keeps the old data, as today) | "**Can't update right now.** Last update {time}. Pull down to try again." | `cloud_off` 16 dp in `warning.fg`, on `warning.tint`, text `text.primary` (15.62:1), 8 dp padding, live region (announced once when it starts) |
| Order finished | n/a | hidden | n/a |

- **The socket-drop fallback stays as built (`03 §2.10`):** while the socket is live there is no polling; when it drops, `track/` is polled every 10 s (`motion.trackPoll`); when it comes back, `track/` is read once and polling stops. Closes 4403 and 4404 stop the socket for good, and polling carries on. Only the line is new.
- **Pull to refresh** runs `poll()` (as today) and moves Stale back to Polling on success.
- **The global offline banner** (app-wide) can show at the same time; the line still says when the order data was last received.
- **No flicker:** switch from Live to Polling only after the socket has been down for 5 s (short reconnects are common on mobile data).

## 4. Delivery OTP card

- **Shown** only while `OUT_FOR_DELIVERY` and `track/` sent `delivery_otp` (a 4-digit code, `06` §2.6).
- **Style:** `brand.primaryContainer` background with `text.primary` (13.27:1); title "Delivery OTP" (`titleSmall`); the digits in `font.deliveryOtp` (36 sp / 700, letter spacing 8 dp, tabular figures); the hint "Share this with your rider at the door, only when you receive your order." (`bodySmall`, existing string).
- **When the rider is at the door** (stage `arriving`, task `AT_CUSTOMER`): add a 2 dp `brand.primary` border (4.98:1 against the container) and change the title to "**Your rider is at the door.** Delivery OTP".
- **Digits stay on one line** at every text scale: wrap them in `FittedBox(fit: BoxFit.scaleDown)`, so 2.0× text shrinks them to the card width instead of breaking "4827" across two lines.
- **Screen reader:** "Delivery OTP 4 8 2 7" (existing `trackingOtpSemantics`).
- The order detail keeps its own OTP card near the top (unchanged).

## 5. Rider row

| Server data | What shows |
|---|---|
| `rider` present | `RiderCard`: photo (40 dp, https only, placeholder otherwise), name, subtitle "**Location updated {when}**", call button (`IconButton.filledTonal`, 48 dp, tooltip "Call {name}") when the server sent a phone |
| No rider, task `SEARCHING`, `OFFERED` or `UNASSIGNED` | "Assigning a delivery partner…" with `hourglass_top` (existing string) |
| No rider and no task yet (before dispatch, `08 §2.1`) | nothing (no promise before the server starts dispatch) |

- **"{when}"** is relative to the phone's clock, from `rider.updated_at`: "just now" (under 1 minute), "{n} min ago" (1–59), otherwise the IST time ("at 3:45 pm"). Today the subtitle shows a bare time after "Your delivery partner", which reads like an arrival time.

## 6. Finished and failed orders

| Status | Content (in this order) |
|---|---|
| `DELIVERED` | Headline "Delivered"; "Delivered at {time}" from the order detail's timeline when it is loaded; **Rate your order** (`FilledButton`, 48 dp) when rating is available, opening the rate screen; the timeline; **Order details**. No OTP, no map, no freshness line. |
| `DELIVERY_FAILED`, `RETURNED` | Headline ("Delivery unsuccessful"); the stage card (failed or returned) with the server's refund note (existing `refundNoteFor`); the timeline; **Order details**. No map. |
| `CANCELLED`, `PAYMENT_FAILED` | Headline; "This order was cancelled. See the order details for any refund." (or the payment-failed equivalent); **Order details**. |

Polling already stops when the order is no longer active (`_schedule`).

## 7. Loading, error and empty

| State | What shows |
|---|---|
| First load | Static skeleton in the §1 shapes: headline bar (28 dp), ETA bar (20 dp), a 120 dp card, a 220 dp map box. No shimmer. |
| First load failed | `ErrorRetryView` (existing), retried by itself when the connection returns (CA-02) |
| `404` (not this customer's order, or gone) | "We couldn't find this order." with **My orders** (`FilledButton`) |
| Map unavailable (no Mappls config, or the map failed) | the existing route sketch (120 dp) in the map's place |

## 8. Copy (new or changed strings; suggested ARB keys)

| Key | Text |
|---|---|
| `trackingLive` | Live |
| `trackingUpdatedAt` | Updated {time} |
| `trackingStale` | Can't update right now. Last update {time}. Pull down to try again. |
| `trackingLateOnTheWay` | Running a little late. Your rider is on the way. |
| `trackingLatePreparing` | Taking a little longer than planned. Your order is being prepared. |
| `trackingGetHelp` | Get help |
| `trackingOtpAtDoorTitle` | Your rider is at the door. Delivery OTP |
| `trackingRiderUpdated` | Location updated {when} |
| `trackingJustNow` / `trackingMinutesAgo` | just now / {n, plural, =1{1 min ago} other{{n} min ago}} |
| `trackingDeliveredAt` | Delivered at {time} |
| `trackingCancelledBody` | This order was cancelled. See the order details for any refund. |
| `trackingNotFound` | We couldn't find this order. |

Reused: `trackingEtaMinutes`, `trackingArrivingNow`, `trackingOtpTitle`, `trackingOtpHint`, `trackingOtpSemantics`, `trackingRiderAssigning`, `trackingCallRider`, `trackingViewDetails`, `callSupport`, `myOrders`.

## 9. Accessibility and text scaling

- **Contrast** (all in the token records): `text.primary` on `surface.base` 16.22:1, on `brand.primaryContainer` 13.27:1 and on `warning.tint` 15.62:1; `success.fg` 7.46:1; `text.secondary` 8.91:1; `brand.primary` border on the container 4.98:1 (non-text).
- **Not colour alone:** Live / Updated / Can't update are words with different icons; the late state is words in a notice.
- **Live regions:** the headline (status changes), the stale line (once), the late notice (once). The ETA line is not a live region (it changes every 30 s and would be noisy).
- **Touch targets:** call button, "Get help", "Order details" and "Rate your order" are 48 dp.
- **Focus order:** headline, ETA, freshness, OTP, COD, rider (call), stage, notices, map (one stop: "Map of your rider's route" plus the existing percent label), timeline, Order details.
- **Text scale 2.0** on 360×640: the OTP card is still on the first screen (about 56 dp app bar + 70 dp headline + 50 dp ETA + 40 dp freshness, then the card); the digits stay on one line; the rider row's call button keeps 48 dp. Widget tests at 1.0×, 1.3× and 2.0× for `OUT_FOR_DELIVERY` with OTP and COD, and for the late and stale states.
- **Reduced motion:** no animated marker transitions on the map beyond what the map SDK does.

## 10. APIs required

None. The freshness state (§3) is app state in `TrackController`. Everything else comes from `track/`, the order socket and the order detail the screen already reads.

## 11. Acceptance checks (for the developer and QA)

- [ ] While `OUT_FOR_DELIVERY`, the OTP card is above the map and on the first screen at 1.0× and 2.0× text on 360×640; the digits never wrap.
- [ ] When the task is `AT_CUSTOMER`, the OTP card shows the at-the-door title and border.
- [ ] The freshness line shows "Live" while the socket is live, "Updated {time}" while polling, and "Can't update right now…" after a failed poll; pull to refresh recovers it.
- [ ] Polling behaviour is unchanged: none while live, every 10 s while down, one re-read on reconnect.
- [ ] More than 5 minutes past the server's ETA, the late notice replaces "Arriving any moment", with "Get help" when support or a support phone exists; a new later ETA clears it.
- [ ] The rider subtitle reads "Location updated {when}"; "Assigning a delivery partner…" shows only for the server task states listed in §5.
- [ ] Delivered, failed and cancelled orders show the §6 content, with no OTP, map or freshness line.
- [ ] Widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
