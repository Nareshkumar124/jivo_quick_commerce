# Component spec: Ops alert banner and SLA badges

- **Status:** ready for implementation (Phase 4). Version 1, 2026-11-04. **Implements:** admin-panel-dev.
- **Used by:** the packing console (`templates/ops/store/console.html`, `partials/packing_queues.html`) and the live order board (`orders/live_board.html`, `partials/live_board_columns.html`, `partials/board_column.html`).
- **Sources:** audit `design/audits/2026-11-04-packing-console.md` PC-02, PC-06, PC-08, PC-19, PC-20 and PC-21; tokens `design/tokens/ops.tokens.json` (CSS variable = token path with dots → dashes, e.g. `--ops-tone-danger-badge-bg`).
- **Suggested files:**
  - `templates/ops/components/alert_banner.html`
  - `templates/ops/components/sla_badge.html` (or a `{% sla_badge timer %}` tag in `templatetags/ops.py`)
  - CSS in `static/ops/css/ops.css` under a new section `/* alerts and SLA badges */`
  - the behaviour in `static/ops/js/orders.js`

## Part A: Alert banner

### A1. Variants

| Variant | When | Background / text | Ratio | Icon | Copy | Action (48 px) |
|---|---|---|---|---|---|---|
| `paused` | The store is not accepting orders (console only) | `ops.tone.danger.badgeBg` / white | 6.42:1 | `block` | "**Paused: customers can't order from this store.**" | **Resume orders** (white button with `ops.tone.danger.text` label, 6.42:1), shown when the user can toggle |
| `stale` | No successful poll for `ops.motion.staleAfter` (25 s) | `ops.tone.warning.badgeBg` / `ops.tone.warning.badgeFg` | 6.94:1 | `wifi_off` | "**Not updating: check the connection.** Last update {HH:MM} IST." | **Retry now** (triggers `ops:refresh`) |
| `new` | The New queue is not empty and the oldest order is before its warning time (console only) | `ops.alert.new.bg` / `ops.alert.new.fg` | 5.54:1 | `notifications_active` | "**{n} new order(s): accept within {m:ss}**" (countdown to the **oldest** order's deadline) | **Mute 2 min** (secondary; while muted: "Muted · 1:42", which unmutes on click) |
| `urgent` | The New queue is not empty and the oldest order is at or past its warning time (console only) | `ops.tone.danger.badgeBg` / white | 6.42:1 | `alarm` | Before the deadline: "**{n} new order(s): accept now, {s} s left**". After it: "**{n} new order(s) are late: accept now**" | **Mute 2 min** |
| `breach` | One or more cards are past their deadline (board only) | `ops.tone.danger.badgeBg` / white | 6.42:1 | `alarm` | "**{n} order(s) past the SLA.**" | **Show late only** (sets the board's breach filter) |

- `ops.alert.new.bg` is the brand primary: TODO(D-06). Re-check its white-text contrast when the brand colour lands (the minimum is 4.5:1).
- The `new` and `urgent` variants are one banner switching tone. They never stack together.

### A2. Anatomy and layout

```
┌────────────────────────────────────────────────────────────────┐
│ [icon 24]  2 new orders: accept within 0:45        [Mute 2 min] │  min-height 56 px
└────────────────────────────────────────────────────────────────┘
```

| Property | Value |
|---|---|
| Element | `<div class="ops-alert ops-alert--{variant}" data-testid="alert-{variant}">` |
| Size | Full width of the content area, min-height 56 px, padding 12px 16px, radius 6 px (`var(--border-radius)`), gap 12 px |
| Text | 16 px; the first sentence is 700 weight; the countdown uses `font-variant-numeric: tabular-nums` |
| Icon | Material Symbols 24 px, `aria-hidden="true"`; the meaning is always in the text |
| Action | `ops-button` at min-height `ops.target.min` (48 px), right-aligned. Below 600 px it wraps under the text at full width. |
| Position | **Sticky** at the top of the content area (`position: sticky; top: 0; z-index: 30`), above the queues and board, below the header |
| Stacking | When several are active, show them in this order, 8 px apart: `paused`, `stale`, then `new`/`urgent` (console) or `breach` (board). At most 3 can show at once. |
| Motion | No animation and no flashing (budget tablets; WCAG 2.3). A tone change is instant. Under `prefers-reduced-motion` nothing changes, because nothing moves. |
| Dark mode | Same colours (they are self-contained pairs). The surrounding page may be dark. |

### A3. Where the banner lives (important for polling)

- Render a container `<div id="ops-alerts" aria-live="off">` **outside** the polled regions (`#packing-queues`, `#board-columns`), so polling never re-creates it and the focus on its buttons survives.
- `orders.js` owns it. After each `htmx:afterSettle` (and every second for the countdowns), it reads the data the poll rendered:
  - packing: `data-new-orders`, plus the deadline and warning time of the oldest New ticket (add `data-oldest-deadline` and `data-oldest-warn` to `#packing-queues`);
  - board: `data-breached="{{ board.breached }}"` on `#board-columns`;
  - stale: `lastOkAt`, updated on `htmx:afterRequest` with a successful response for the polled region.
- The paused banner is rendered by the server in the store bar's swap target (`#store-bar`, PC-21), not by JS.

### A4. Sound and title (console only; tied to `new` / `urgent`)

| Banner | Sound (when unlocked, not muted) | Tab title |
|---|---|---|
| `new` | Alert every `ops.motion.alertRepeat` (15 s): two tones, 880 Hz, 0.2 s each, gain 0.6 | "({n}) New orders · {store}" |
| `urgent` | Alert every `ops.motion.alertRepeatUrgent` (5 s): three tones, 660 / 880 / 990 Hz, 0.25 s each, gain 0.6 | "(!{n}) Accept now · {store}" |
| None | silent | "{page title}" |

- **Mute:** lasts exactly 2 minutes and is never indefinite. The label counts down ("Muted · 1:42"). Muting does not hide the banner.
- **Audio unlock:** the "Start taking orders" overlay (PC-02) must have been tapped on this page load. Until then, the banner shows an extra inline button "**Turn on sound**" (48 px) next to the mute button.

### A5. Accessibility

- **Announcements:** use the page announcer from PC-13 (`#ops-announcer`, `role="status"`, plus an assertive twin). Do not make the banner a live region itself, because its countdown changes every second.
  - `new` appears or its count rises → assertive: "{n} new orders."
  - It switches to `urgent` → assertive: "Accept now: order {number} is about to breach." Once per order.
  - `stale` appears → polite: "Not updating. Check the connection." Once per outage.
  - `breach` count rises → polite: "{n} orders past the SLA."
- **Semantics:** each banner is `role="region"` with `aria-label="Alert: {variant label}"`, so it is reachable by landmark navigation.
- **Countdown span:** `role="timer"` and `aria-live="off"`.
- **Focus:** the action buttons are in the normal tab order, first after the header. Focus is never moved to the banner automatically.

## Part B: SLA badges

### B1. Variants

| Tone (`data-tone`, from `sla.py`) | Badge | Icon | Colours | Ratio | Time text (always shown) |
|---|---|---|---|---|---|
| `success` | none | `timer` (in the time text) | time text `ops.color.text.secondary` | 7.56:1 | "12m left" (when a deadline exists) or the age "4m 12s" (when none) |
| `warning` | **DUE SOON** | `schedule` | `ops.tone.warning.badgeFg` on `ops.tone.warning.badgeBg` | 6.94:1 | "1m 40s left" in `ops.tone.warning.text` (5.22:1), 600 weight |
| `danger` | **LATE** | `alarm` | white on `ops.tone.danger.badgeBg` | 6.42:1 | "3m late" in `ops.tone.danger.text` (6.42:1), 700 weight |

- **Badge anatomy:** `<span class="ops-sla-badge ops-sla-badge--{tone}">` containing an icon (16 px, `aria-hidden`) and an uppercase label at 12 px / 700 with letter-spacing 0.04em. Height 24 px, padding 0 8px, radius 4 px. It is not a touch target, because it is not interactive.
- **The label is the meaning; the colour is redundant.** Never show a tone without its word (or, for success, the plain time).
- **Ticket and card border:** a left border of `ops.border.ticket` (6 px) in `ops.tone.warning.border` (5.22:1) or `ops.tone.danger.border` (6.42:1). Success uses `ops.tone.success.text` (4.95:1).

### B2. Placement

| Surface | Row |
|---|---|
| Packing ticket | Header row: order number (`ops.font.orderNumber`), pickup code chip, then right-aligned: badge + time text |
| Board card | Second row: badge + time text (replaces the current `timer` row). The store code stays on the first row. |

### B3. Time text rules (all from `data-sla-*` timestamps; the JS `tick()` already computes them)

| Situation | Text |
|---|---|
| Deadline in the future, ≥ 1 h | "1h 05m left" |
| Deadline in the future, < 1 h | "12m left"; under 2 minutes "1m 40s left" |
| Deadline passed | "3m late"; under 1 minute "40s late"; ≥ 1 h "1h 10m late" |
| No deadline (`DELIVERY_FAILED`) | age only: "Waiting 14m" with no badge (the exceptions lane is itself the alert) |

- **Every** ticket and card with a deadline renders `<span data-left>` (today only PLACED tickets do).
- `title` tooltips may stay, but no information may exist **only** in a tooltip.
- **Semantics:** the time-and-badge group gets an `aria-label` refreshed on each poll, not each second, for example "Late by 3 minutes, promised delivery time 14:32".

### B4. Ordering and counts

- Within each packing queue and board column, show **LATE** tickets first (oldest deadline first), then the rest oldest first. When at least one LATE ticket exists, put a divider "LATE ({n})" above them (12 px / 700, `ops.tone.danger.text`).
- **Count pills** in queue and column headers: height `ops.target.queueCountPill` (28 px), min-width 28 px, 14 px / 700.
  - default: `ops.color.text.primary` on `ops.color.surfaceMuted` (16.12:1);
  - New queue with count > 0: `ops.alert.new.fg` on `ops.alert.new.bg` (5.54:1);
  - column with late cards: add a second pill "**{n} late**" in white on `ops.tone.danger.badgeBg`, with the `alarm` icon.

## Part C: CSS skeleton (for orientation; the developer owns the final CSS)

```css
.ops-alert { position: sticky; top: 0; z-index: 30; display: flex; align-items: center; gap: 12px;
  min-height: 56px; padding: 12px 16px; border-radius: var(--border-radius, 6px); font-size: 16px; }
.ops-alert--new { background: var(--ops-alert-new-bg); color: var(--ops-alert-new-fg); }
.ops-alert--urgent, .ops-alert--breach, .ops-alert--paused { background: var(--ops-tone-danger-badge-bg); color: #fff; }
.ops-alert--stale { background: var(--ops-tone-warning-badge-bg); color: var(--ops-tone-warning-badge-fg); }
.ops-alert .ops-button { min-height: var(--ops-target-min); margin-left: auto; }
.ops-sla-badge { display: inline-flex; align-items: center; gap: 4px; height: 24px; padding: 0 8px;
  border-radius: 4px; font-size: 12px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; }
.ops-sla-badge--warning { background: var(--ops-tone-warning-badge-bg); color: var(--ops-tone-warning-badge-fg); }
.ops-sla-badge--danger { background: var(--ops-tone-danger-badge-bg); color: #fff; }
```

## Acceptance checks

- [ ] Every non-success tone shows its word (DUE SOON / LATE) and a time text; no ticket or card relies on colour alone.
- [ ] Every ticket and card with a deadline shows "…left" or "…late".
- [ ] The banners live outside the polled regions and keep focus across polls.
- [ ] `new` turns into `urgent` at the oldest order's warning time, and the sound cadence follows (15 s, then 5 s).
- [ ] Mute lasts exactly 2 minutes and shows its countdown.
- [ ] The stale banner appears after 25 s without a successful poll and clears on the next success, with at most one network toast per outage.
- [ ] Announcements fire once per event, never every second.
- [ ] All colour pairs match the `ops.tokens.json` contrast records.
