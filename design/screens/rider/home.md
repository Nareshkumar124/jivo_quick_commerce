# Screen spec: Rider home (screen 8)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04.
- **Owner:** ui-designer. **Implements:** flutter-rider-dev, in `rider_app/lib/features/shift/presentation/home_screen.dart`.
- **Sources:** `docs/04-rider-app.md` §2.3 and §2.7. Audit finding RD-01 (and RD-05 for colours and text) in `design/audits/2026-11-04-rider-delivery.md`. Tokens are in `design/tokens/rider.tokens.json`; the token names below are that file's paths.
- **Rules:**
  - Every number on this screen (amounts, counts, durations, distances, limits) comes from the server. The app formats values but never adds or compares them. The cash-limit state follows the server's `limit_reached` flag.
  - Format amounts with the shared `en_IN` formatter (₹, Indian grouping, paise only when non-zero). Show times in IST.
- **Who sees it:** ACTIVE riders only. Other statuses are routed elsewhere, as today. While a task is active or an offer is open, the router keeps the rider on those screens. Home appears only between tasks, or after a task ends.

## 1. Layout (portrait, 360×640 dp minimum)

```
┌──────────────────────────────────────┐
│ AppBar: "Hi, Ravi"         [person]  │  person icon 48 dp → profile
├──────────────────────────────────────┤
│ [Status card]                        │  §3
│ [Guard card]   (0 or 1, §4)          │
│ [Deposit cash banner] (limit_reached)│  §6
│ Today                                │  section title, titleMedium
│ ┌──────────┬──────────┐              │
│ │Delivered │ Earned   │              │  §5 tiles
│ ├──────────┼──────────┤              │
│ │Online    │Cash in   │              │
│ │time      │hand      │              │
│ └──────────┴──────────┘              │
│ Earnings ›  Cash ›  History ›        │  records rows, 64 dp each
│ Payouts ›   Profile ›                │
├──────────────────────────────────────┤
│ [ Online control 72 dp / Task card ] │  bottom-pinned, §2 / §7
└──────────────────────────────────────┘
```

- **Scrolling:** the body scrolls (`ListView`, 16 dp gutter, `RefreshIndicator`, where a pull refreshes `GET /rider/me/` and the shift state). The bottom area is pinned in `bottomNavigationBar` inside `SafeArea`, with 16 dp horizontal and 16 dp bottom padding.
- **Order:** the guard card comes **directly under** the status card, so the reason the rider can't go online sits next to the state it explains.
- **Records rows:** Earnings, Cash in hand, History, Payouts, Profile. Each is a `ListTile` with `minTileHeight: 64`, a leading icon (`account_balance_wallet`, `payments`, `history`, `receipt_long`, `person`) and a trailing `chevron_right`.
- **Visibility:** the build label and the dev buttons appear only in the dev flavor with the fakes, and render below the records rows.

## 2. Online control (bottom-pinned)

A single full-width button that is **72 dp high** (`rider.size.onlineControl`) with a 12 dp radius. It is a button, never a `Switch`. Its label is `rider.font.onlineControlLabel` (22 sp / 700) and its icon is 28 dp.

| State | Label | Icon | Style | Enabled |
|---|---|---|---|---|
| Offline, can go online | **Go online** | `power_settings_new` | `FilledButton`, bg `rider.color.online.bg`, fg `rider.color.online.fg` (7.87:1) | yes |
| Offline, blocked by a guard | **Go online** | `power_settings_new` | same at 38% opacity, with the reason in the guard card (§4) | no; `Semantics(hint: <guard title>)` |
| Going online | **Going online…** | spinner, 24 dp | same colours, `onPressed: null` | no |
| Online | **Go offline** | `power_off` | `OutlinedButton`, fg `rider.color.text.primary`, border `rider.border.outlinedButton` (2 dp, 17.16:1), bg `rider.color.surface` | yes |
| Going offline | **Going offline…** | spinner | outlined, `onPressed: null` | no |
| Task active | replaced by the current-task card (§7) | n/a | n/a | n/a |

- **Going online:** no confirmation. The tap first runs the permission gate when anything is missing (the existing flow), then starts the shift.
- **Going offline:** also no confirmation. If an offer is open, the router already shows the offer screen. If the server refuses because a task is active, the guard card shows "**Finish your current order first.**"
- **Haptics:** `HapticFeedback.mediumImpact` when the state change succeeds.
- **Semantics:** a button labelled "Go online" or "Go offline". After a change, announce "You're online" or "You're offline" (`SemanticsService.announce`).

## 3. Status card

This card is full width with a 16 dp padding and a 12 dp radius. Its state is always written in words. The 12 dp dot at the start is decorative (`ExcludeSemantics`).

| State | Background | Dot | Title (`titleMedium`, 18 sp / 600) | Body (`bodyLarge`, 18 sp) |
|---|---|---|---|---|
| Offline | `rider.color.neutral.container` | outline only, `rider.color.text.secondary` | **You're offline** | You won't get orders. |
| Online, idle | `rider.color.surface`, with a 2 dp border in `rider.color.online.bg` | filled, `rider.color.online.bg` | **You're online** | Waiting for orders near {storeName}. |
| Online, prepaid only (`limit_reached`) | `rider.color.cod.bg`, with border `rider.border.codContainer` | filled, `rider.color.cod.border` | **You're online: prepaid orders only** | Deposit cash at the store to get cash orders again. |
| Auto-offline (the server ended the shift after 10 min without location) | `rider.color.cod.bg`, border `rider.border.codContainer`, icon `location_off` | n/a | **You were set offline** | We didn't get your location for 10 minutes. Check GPS and your connection, then go online again. |
| Loading | skeleton, 72 dp high, with the background shimmer disabled under reduced motion | n/a | n/a | n/a |

- **Show the auto-offline state when:** the shift state from the server says the rider was set offline by the server (`ended_by: SYSTEM` or equivalent; see "APIs required"), or the auto-offline push was opened.
- **Clear it when:** the rider next goes online, or taps the card's close button (48 dp).
- **Store name:** taken from `GET /rider/me/` (the home store). If it is missing, use "Waiting for orders near your store."

## 4. Guard card (why "Go online" is blocked)

This card shows **at most one** guard at a time, in the priority order below. The text is `rider.color.text.primary` on `rider.color.surface`, with a 2 dp `rider.color.danger` border on the left edge and a 24 dp leading icon in `rider.color.danger`. The card has one 56 dp action button (`rider.size.primaryAction`) that is full width inside it.

| Priority | Guard (source) | Icon | Title | Body | Action |
|---|---|---|---|---|---|
| 1 | Not ACTIVE (rider status) | `badge` | Your account isn't active | We'll let you know when Jivo approves your documents. | **See status** → status screen |
| 2 | Permissions missing (permission gate) | `location_disabled` | Allow location and notifications | You need them to get orders. | **Fix permissions** → gate |
| 3 | GPS off (gate check) | `gps_off` | Turn on location (GPS) | Jivo Rider can't find you with GPS off. | **Turn on GPS** → system location settings |
| 4 | Too far from the home store (server refusal `OUTSIDE_GEOFENCE`, `details.distance_m`, `details.radius_m`) | `wrong_location` | You're too far from your store | You're **{distance} km** from {storeName}. Go within **{radius} km** to go online. | **Navigate to store** (opens maps, as on the task screen) |
| 5 | Active task (server refusal on going offline) | `two_wheeler` | Finish your current order first | n/a | **Continue order** |
| 6 | Network error while changing state | `wifi_off` | No internet | Check your connection and try again. | **Try again** |

- **Distance and radius:** the server sends both, and the app formats them as km with one decimal when the value is 1 km or more (1840 m → "1.8 km"). That is unit formatting, not calculation. If the server omits them, use the body "Move closer to {storeName} and try again."
- **Cash limit is not a blocker.** The rider can still go online (04 §2.3), so it is handled by the status card (§3) and the banner (§6), not here.
- **Live region:** wrap the card in `Semantics(liveRegion: true)`, so a guard that appears after a tap is announced.

## 5. Today summary

The summary is a 2×2 grid of tiles with an 8 dp gap. Each tile has a min height of 88 dp, a 12 dp padding, a 12 dp radius and the background `rider.color.neutral.container`.

| Tile | Label (`rider.font.tileLabel`, 14 sp / 500, `rider.color.text.secondary`) | Value (`rider.font.tileValue`, 24 sp / 700, tabular figures, `rider.color.text.primary`) | Source field (see "APIs required") |
|---|---|---|---|
| 1 | Delivered | `12` | `today.delivered_count` |
| 2 | Earned | `₹1,240` | `today.earnings` (money string) |
| 3 | Online time | `5h 20m` | `today.online_seconds` (formatted as h/m; under 1 h show `45m`) |
| 4 | Cash in hand | `₹3,480` | `cash_in_hand` (money string) |

- **Interaction:** tapping the Earned tile opens Earnings, and tapping Cash in hand opens Cash. These two tiles are 48 dp or taller (they always are) and have the semantics label "Earned today ₹1,240, opens earnings".
- **Loading:** four skeleton tiles.
- **Field missing or the request failed:** show the value "–" with the semantics label "not available". The section title then gets a trailing text button "Retry" (48 dp). Never show 0 in place of an unknown value.
- **Zero values:** `0`, `₹0` and `0m` are shown as they are.
- **Day boundary:** "Today" is the IST calendar day, as the server defines it. The app does not reset counters itself; it re-fetches on resume.

## 6. Deposit cash banner

The banner shows only when the server sends `limit_reached: true`. It uses the background `rider.color.cod.bg` with the border `rider.border.codContainer` and the icon `warning` (24 dp, `rider.color.cod.border`).

- **Title (18 sp / 700):** "Deposit cash"
- **Body (16 sp):** "You've reached the cash limit of **{limit}**. Hand the cash to the store manager to get cash orders again. Until then you get prepaid orders only." This is the existing string `cashDepositBody`; `{limit}` comes from the server.
- **Action:** "**How to deposit**" (outlined, 56 dp) opens a bottom sheet: "Hand the cash to your store manager. It shows in your cash ledger once they record it." The sheet has a "See cash ledger" button.

## 7. Current task card (replaces the online control)

When `GET /rider/tasks/current/` returns a task while home is visible (for example, after an app restart before the router has redirected, or on the brief frame after a task ends), the bottom area shows this card instead of the online control.

```
┌──────────────────────────────────────┐
│ Order JQ-1042                 COD    │  18 sp/700 · payment chip
│ Go to customer · Sector 21           │  step + locality, 16 sp
│ ┌──────────────────────────────────┐ │
│ │        Continue  →               │ │  FilledButton 56 dp, online.bg
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

- **Step labels** use the existing task titles: "Go to the store", "Pick up the order", "Deliver to the customer", "Enter the delivery code", "Return to store".
- **Payment chip:** "COD ₹1,240" (`rider.color.cod.*`, 2 dp border) or "Prepaid" (neutral container). It is a text chip, not colour only.
- **Continue** goes to the task route. The online control is hidden while a task is active, because going offline is refused anyway.
- **Semantics:** "Current order JQ-1042, deliver to the customer. Continue."

## 8. States summary

| State | What shows |
|---|---|
| First load | Skeletons for the status card, four tiles and the bottom area (72 dp). No online control until the shift state is known. |
| Load failed (`GET /rider/me/`) | Status card body "Couldn't load your status." with a **Retry** button (56 dp). The online control stays disabled. |
| Offline, ready | Status "You're offline", no guard, **Go online** enabled |
| Offline, guarded | Status "You're offline", guard card (§4), **Go online** disabled |
| Going online / offline | Busy labels (§2). All other actions on the page stay usable. |
| Online, idle | Status "You're online", **Go offline** |
| Online, prepaid only | Status in the COD style (§3), deposit banner (§6), **Go offline** |
| Auto-offline | Status "You were set offline" (§3), **Go online** |
| Task active | Current-task card (§7) instead of the control |
| No network (any time) | Offline banner from RD-09 under the app bar: "**No internet.** You stay online; orders arrive when you're back." (`rider.color.cod.bg`, icon `wifi_off`, 15.66:1) |

## 9. Content rules

- **Rider name in the app bar:** use the first word of `full_name`, and ellipsize after 16 characters. If there is no name, use "Jivo Rider".
- **Store name:** ellipsize at 1 line in the status body. The full name goes in the semantics label.
- **Amounts:** use the shared formatter for every amount. If an amount string is unparseable, show "–", never "₹".
- **Hindi (D-24):** labels must fit at about 1.4× English length. The tiles wrap their label to 2 lines and the online control label may wrap to 2 lines (the 72 dp height allows 2 lines at 22 sp only up to a 1.3× text scale, so see §10).

## 10. Accessibility and text scaling

- **Contrast:** all pairs come from `design/tokens/rider.tokens.json`. Every text pair on this screen is 7:1 or more, except the guard's `rider.color.danger` icon and border, which are non-text cues paired with words.
- **Text scale 200%** (test on a 360×640 surface with `TextScaler.linear(2.0)`):
  - The online control grows to fit (`minimumSize` height 72, no fixed height), and the bottom area is capped at 40% of the screen height.
  - The tiles become a single column of 4 above a 1.5× text scale.
  - The guard card's action stays visible, because the body scrolls.
- **Focus order:** app bar, status card, guard card and its action, banner, tiles, records, bottom control.
- **Reduced motion:** no shimmer; skeletons are static.
- **Touch targets:** 72 dp for the online control, 56 dp for guard and banner actions and Continue, 64 dp for record rows, and 48 dp for the app bar icon, Retry and the close button.

## 11. APIs required (owner: django-backend-dev; tracked in `docs/api-requests.md` by the PM)

1. **`today` summary**, on `GET /rider/me/` or a shift endpoint: `delivered_count`, `earnings` (money string), `online_seconds` (IST day). `cash_in_hand`, `cash_limit` and `limit_reached` are already planned.
2. **Shift state:** `is_online`, plus `ended_by` (`RIDER`/`SYSTEM`) and `ended_at` for the auto-offline status.
3. **Go-online refusals:** `OUTSIDE_GEOFENCE` with `details.distance_m` and `details.radius_m`; a distinct code for "not ACTIVE".
4. **Home store name** on `GET /rider/me/`.

## 12. Acceptance checks (for the developer and QA)

- [ ] The online control is 72 dp high and pinned at the bottom. Its states and labels match §2, and it is never a `Switch`.
- [ ] Each guard in §4 shows its exact copy and action, one at a time, in priority order.
- [ ] The cash limit does not block going online; it shows the prepaid-only status and the banner instead.
- [ ] Tiles show server values only; a missing value shows "–" and never 0.
- [ ] An active task replaces the control with the task card, and Continue opens the task step.
- [ ] Every text pair matches the token contrast records. No text on this screen is below 14 sp.
- [ ] Golden or widget tests pass at text scales 1.0 and 2.0 on 360×640.
