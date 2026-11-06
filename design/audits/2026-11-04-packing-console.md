# UX audit: store packing console and live order board

- **Date:** 2026-11-04 (before the Phase 4 store-staff mini-UAT, QA script UAT-P4-01…13)
- **Auditor:** ui-designer
- **Scope:** `/ops/store/<store>/` (packing console), `/ops/orders/live/` (live board), the slip and bag label, and the shared confirm, cancel and toast components they use.
- **Build audited:** branch `admin/phase-4`, worktree `.worktrees/admin/backend/` (read-only).
- **Method:** static review of templates, CSS and JS against `docs/05` §1.2, §1.3 and §5, the agent design rules (WCAG AA, 48 dp targets, no colour-only signals) and the UAT script. No server was run. Sizes come from the CSS. Contrast ratios are WCAG 2.x ratios computed from unfold's Tailwind v4 `oklch` colours converted to sRGB (for example, `orange-600` ≈ `#f54a00`), so treat the second decimal as approximate.
- **Users and context:** store staff on a shared landscape tablet (about 10", 1280×800 CSS px) or a desktop, standing, under time pressure, possibly wearing gloves, with a printer nearby and the screen read from arm's length (about 60–70 cm).

## Severity

| Severity | Meaning |
|---|---|
| **Blocker** | Likely to fail a UAT-P4 case, or can cause a wrong refund, cancellation or missed order. Fix before the walkthrough. |
| **Major** | Slows staff down or causes errors under pressure, or fails WCAG AA. Fix in Phase 4 if possible, otherwise early in Phase 5. |
| **Minor** | Polish, or a risk for later phases. |

---

## Top 5 fixes (do these before the mini-UAT)

| # | ID | Severity | Fix in one line | UAT case at risk |
|---|---|---|---|---|
| 1 | PC-01 | Blocker | Ticking a pick-list checkbox stops polling, so new orders and alerts stop arriving. Exclude checkboxes from the "typing" guard. | P4-02, P4-12 |
| 2 | PC-02 | Blocker | The new-order alert is silent by default, is one 0.45 s beep, and is never repeated. Add a "Start shift" tap that unlocks audio and turns sound on, and repeat the alert until the order is accepted. | P4-02, P4-11 |
| 3 | PC-03 | Blocker | "Item unavailable" is an irreversible refund behind a 28 px number field. The confirmation names neither the item nor the quantity, and focus starts on the destructive button. Replace it with a per-line dialog that names both and puts focus on the safe button. | P4-06, P4-07 |
| 4 | PC-04 | Major | After a partial unavailability the pick list and slip still show "× 2", which reads as "pack 2". Show the quantity to pack. | P4-04, P4-05, P4-06 |
| 5 | PC-05 | Major | Touch targets are 38 px (buttons), 22 px (ticks) and about 20 px (text links). Raise them to 56 px for step buttons and 48 px for everything else. | P4-04, glove use |

---

## Findings

### A. Polling, alerts and live updates

#### PC-01 · Blocker · Polling stops while a checkbox has focus
- **Screen / file:** packing console. `static/ops/js/orders.js`, `window.opsPollAllowed`.
- **Issue:** the guard returns `false` when `document.activeElement` is any `INPUT` inside `#packing-queues`. Pick-list ticks are `<input type="checkbox">`, and a click focuses them in Chrome on desktop and Android. After the first tick, focus stays on the checkbox and polling stops **until staff tap somewhere neutral**. During that time no new orders, no alert sound and no notification arrive. The 10 s promise in UAT-P4-02 then fails as soon as a packer starts ticking. The "Unavailable" number field has the same effect while it has focus.
- **Fix:**
  1. Pause polling only for text entry:
     ```js
     const typing = active.tagName === "TEXTAREA" || active.tagName === "SELECT" ||
       (active.tagName === "INPUT" && !/^(checkbox|radio|button|submit)$/i.test(active.type));
     ```
  2. Even while typing, never pause for more than 30 s. Keep `lastPollAt` and allow the poll once `Date.now() - lastPollAt > 30000`.
  3. Better still (see PC-12): swap the queue with a morph (idiomorph), so a poll never wipes a half-typed value and the pause guard becomes unnecessary.

#### PC-02 · Blocker · The new-order alert is too easy to miss
- **Screen / file:** packing console. `orders.js` (`beep`, `checkNewOrders`, store `alerts`), and the sound button in `templates/ops/store/console.html`.
- **Issues:**
  1. Sound is **off by default** (`readJson("local","ops-sound", false)`). On a shared tablet, nobody notices that it is off.
  2. The `AudioContext` is created lazily inside `beep()`. After any reload (for example, "Pause orders" and "Resume orders" both call `window.location.reload()`), the first beep runs without a user gesture, so Chrome creates the context **suspended** and the beep is silent. The button still says "Sound on".
  3. On page load, every order already in "New orders" is written to `ops-seen` and never alerts again. Orders that arrive during a reload or a login are therefore silent.
  4. The tone is two 880 Hz beeps of 0.2 s each at gain 0.3, played once. That is too short and quiet for a dark store with fans and compressors, and nothing repeats while an order waits. UAT-P4-11 expects a **re-alert** at the SLA, and none exists.
  5. There is no visible alert apart from the card itself: no banner, no tab-title change and no flash.
  6. The `Notification` API needs HTTPS or `localhost`. On a LAN `http://` address the permission is `denied` and the "Allow notifications" button disappears without explanation.
- **Fix (spec):**
  1. **"Start shift" overlay.** On load, if no gesture has unlocked audio in this page, show a full-screen dimmed overlay with one 64 px button: "**Start taking orders**", with the subtitle "Turns on the new-order sound for this screen." The tap creates or resumes the `AudioContext` (`audio.resume()`), sets sound on and asks for notification permission. Do this on every page load, because unlocking does not survive a reload.
  2. **Repeat until acknowledged.** While "New orders" holds at least one order, play the alert every **15 s**. From the SLA warning time (`data-sla-warn`) play it every **5 s** with a three-tone pattern (660 / 880 / 990 Hz, 0.25 s each, gain 0.6). Stop when the New queue is empty. Add a "Mute for 2 min" button (48 px) that shows the remaining time, never an indefinite mute.
  3. **On-screen banner.** Whenever New is not empty, show a sticky bar above the queues: `token ops.alert.new.bg` with the icon `notifications_active` and the text "**2 new orders: accept within 0:45**", counting down the oldest order. At the warning time it switches to the breach style (PC-06).
  4. **Tab title.** Set `document.title = "(2) New orders · <store>"` while New is not empty, so a hidden tab still shows the count.
  5. **Do not mark orders as seen on page load before audio is unlocked.** Compute fresh orders only after the "Start shift" tap, so orders that were already waiting alert once.
  6. **Notifications.** When `Notification.permission === "denied"` or the context is not secure, show a muted line: "Browser notifications are off on this device. Keep this tab open and the sound on."
- **Note for PM:** UAT-P4-11 says the acceptance SLA is 60 s. `sla.py` defaults to 120 s (05 §1.1). Confirm the value before the walkthrough. This is a settings question, not a design one.

#### PC-03 · Blocker · "Item unavailable" is not error-proofed
- **Screen / file:** packing console. `templates/ops/partials/packing_queues.html` (the unavailable `<form>`), `apps/ops_console/forms.py` `UnavailableForm`, and `templates/ops/components/confirm_dialog.html`.
- **Issues:**
  1. The service is **one-way**. `store_ops.mark_item_unavailable` says the value "can only grow", and the refund or reduced COD happens at once. The UI suggests otherwise: the field has `min="0"`, its default is the current value, and the form docstring says "0 undoes".
  2. The meaning of the number is unclear. It is the line's **total** number of unavailable units, not "how many more". A packer who types 1 twice expects 2 removed and gets 1.
  3. The confirmation text is the same for every line. It names neither the product nor the quantity and does not say the change cannot be undone. With several lines in a ticket, staff cannot check what they are confirming.
  4. The confirm dialog focuses the **accept** button even for `tone="danger"` (`x-effect … $refs.accept.focus()`). A stray Enter, from a keyboard or a scanner that ends with Enter, confirms the refund.
  5. The controls are tiny: a 12 px label, a 28 px number field and a text-only "Update" link with no padding. The form sits under every line, which doubles the pick list's height and puts a money action next to each item.
- **Fix (spec):**
  1. Replace the inline form with one secondary button per line: "**Can't supply**" (48 px high, outlined, icon `remove_shopping_cart`). Show it only while the order is ACCEPTED or PACKING and units are left.
  2. The button opens a dialog (`role="alertdialog"`):
     - **Title:** "Can't supply **Jivo Cold Pressed Groundnut Oil 1 L**?"
     - **Body:** "The customer ordered **2**. How many can't you supply?"
     - **Choice:** large radio chips, 56 × 56 px each: `1`, `2 (all)`, and so on up to the units remaining. Chips start from units **not yet** marked unavailable. A stepper is acceptable for quantities above 6. Send the server the resulting **total** (`already + chosen`), so the form contract does not change.
     - **Consequence line** (rendered from the server, never computed in the page): "Customer will get **1 of 2**. Paid online: the difference is refunded." or "Cash on delivery: the rider collects less." If this choice leaves nothing in the order: "**This cancels the whole order** and refunds it in full."
     - **Irreversibility:** "You can't undo this."
     - **Buttons:** "Go back" (secondary, **gets focus on open**) and "Remove 1 unit" (danger; the label repeats the number).
  3. Change the confirm component: when `tone === "danger"`, focus the cancel button (`x-ref="cancel"`), not the accept button. This applies to "Pause orders" too.
  4. Set the field to `min = current value`, so it can never send a decrease, and fix the docstring.
  5. To show "this cancels the whole order", the template needs to know whether the choice empties the order. That is a units comparison, not money, so the server can compute it per line in `packing.Ticket` (`would_empty_if_all_removed`). The ONLINE/COD wording comes from `order.payment_method`. Exact amounts in the dialog would need a server preview (see "APIs required").

#### PC-04 · Major · Partial quantities read as "pack all"
- **Screen / file:** pick list in `packing_queues.html`, slip in `templates/ops/store/slip.html`.
- **Issue:** after 1 of 2 units is marked unavailable, the pick list still shows "**× 2**" in bold, with a 12 px orange "1 unavailable" under the name. The slip prints "2 (1 unavailable)". Under pressure, staff pack 2, the bag no longer matches the bill, and the customer gets an item they were refunded for.
- **Fix:**
  - **Pick list:** the quantity cell shows the units to pack: "**× 1**" at 24 px / 700. Under it, at 14 px in `ops.text.warning`, show "~~2~~ 1 can't supply" (strike the original). Use `<del>` for the old value with `aria-label="ordered 2"`.
  - **Fully unavailable line:** grey out the row and show the text label "**Not in this order**", with the `block` icon. Remove the checkbox (already done) and move the line to the bottom of the list.
  - **Slip:** add a column "Pack". The row reads `Groundnut Oil 1 L | SKU | Pack 1 | (2 ordered, 1 unavailable)`.
  - `quantity - quantity_unavailable` is a units count for display (not money or stock logic). Provide it from `packing.py` as `line.to_pack`, so the template does no arithmetic.

#### PC-05 · Major · Touch targets are below 48 px
- **Screen / file:** `static/ops/css/ops.css`.

| Control | Now | Fix |
|---|---|---|
| Step buttons (`Accept`, `Start packing`, `Mark packed`): `.ops-button` | 38 px high | **56 px** high, full ticket width, 18 px / 600 text (new modifier `.ops-button--step`) |
| Secondary buttons (`Print slip`, sound, notifications, `Pause orders`) | 38 px | 48 px (`.ops-button` min-height 48 px on the packing console and live board) |
| Pick-list checkbox `.ops-check` | 22 × 22 px | 28 × 28 px visible box, with the **whole row** as the hit area: wrap the cell contents in a `<label for>` and give the row `min-height: 56px; cursor: pointer` |
| `Cancel order`, `Update` (`.ops-link-button`, padding 0) | about 20 px high | 48 px min-height, `padding: 0 12px`. Keep the text style, but make the hit area a box |
| Unavailable number field | about 28 px | replaced by PC-03 chips (56 px) |
| Toast close button | about 18 px | 40 × 40 px (toasts are not a glove action, so 40 is acceptable) |
| Live board filters and checkbox | 38 px | 48 px |

- Keep at least **8 px** between adjacent targets. The step button and "Cancel order" share a row today with `gap: 0.5rem`. Move "Cancel order" to the ticket header overflow (see PC-09).

### B. Glanceability and urgency

#### PC-06 · Major · Urgency relies on colour (and warning colours fail contrast)
- **Screen / file:** `ops.css` `[data-tone]` rules, ticket and card timer markup, `orders.js` `tick()`.
- **Issues:**
  1. For ACCEPTED, PACKING and PACKED tickets, the timer shows only the age ("4m 12s"). A breach of the promised delivery time is shown only by the left border colour and the timer colour or weight. The deadline appears only in a `title` tooltip, which touch screens never show.
  2. The left border is 4 px. `orange-500` on white is **2.89:1**, below the 3:1 minimum for non-text contrast (WCAG 1.4.11).
  3. Warning text in `orange-600` on white is **3.58:1**, which fails AA for normal text. This affects the timer, "1 unavailable" (12 px) and the low-stock link.
  4. The success tone uses `green-600` (3.22:1) where it is used as text.
- **Fix:**
  - Add a **text badge** inside the timer row for every tone, with an icon and a word:
    | Tone | Badge | Icon | Badge colours | Ratio |
    |---|---|---|---|---|
    | success | none (the timer only) | `timer` | n/a | n/a |
    | warning | "**DUE SOON**" | `schedule` | text `orange-800` (#9f2d00) on `orange-50` (#fff7ed) | 6.94:1 |
    | danger | "**LATE**" | `alarm` | text white on `red-700` (#c10007) | 6.42:1 |
  - Show the remaining time as text for **every** status that has a deadline: "12m left" or "3m late". `tick()` already computes it for PLACED; render `<span data-left>` for every ticket, as the board card already does.
  - Widen the left border to **6 px** and use `orange-700` (5.22:1) and `red-700` (6.42:1).
  - Tone text: `.ops-tone-warning → var(--color-orange-700)`, `.ops-tone-danger → var(--color-red-700)`, `.ops-tone-success → var(--color-green-700)` (4.95:1).
  - **Sort:** keep oldest-first, which is correct. Also pin LATE tickets to the top of each queue with a "LATE" section divider, so they never sit below the fold.
  - Do **not** make the per-second timer an ARIA live region (see PC-13).

#### PC-07 · Major · The pick list is hard to read at arm's length
- **Screen / file:** `packing_queues.html` (`.ops-picklist`), `ops.css` `.ops-packing`.
- **Issues:** product names use the body size (about 14 px), variant and SKU are 12 px, the rack is 12 px and the order number 15 px. At 1280 px the sidebar takes 272 px and the four queues get about 230 px each, so names wrap to three or four lines. UAT-P4-04 checks exactly this.
- **Fix:**
  - **Type scale for the console** (proposed tokens `ops.packing.*`, 1 rem = 16 px):
    | Element | Size / weight |
    |---|---|
    | Order number | 18 px / 700, tabular numerals |
    | Pickup code chip | 20 px / 800 mono, letter-spacing 0.15em |
    | Product name | 18 px / 600, clamp to 2 lines with the full name in the row's `aria-label` |
    | Variant | 15 px / 500 |
    | Quantity to pack | 24 px / 700, in a 40 px min-width box |
    | Rack | 16 px / 700 mono badge, `base-100` background, placed **first** in the row when present (packers walk by rack) |
    | SKU | 13 px, `base-600` (7.56:1); secondary, may be hidden below 900 px |
  - **Focus layout:** hide the sidebar on `/ops/store/<code>/` by default (a "Menu" button opens the drawer). Lay the queues out with `grid-template-columns: 1.2fr 1fr 1.4fr 1fr` (New, Accepted, Packing, Packed), so Packing, which holds the pick list, gets the most room. Below 1100 px, use two columns: New with Accepted, then Packing with Packed.
  - **Long names:** clamp to 2 lines (`-webkit-line-clamp: 2`). Never truncate the variant, because "1 L" against "5 L" is the critical difference.

#### PC-08 · Minor · Queue headers and counts
- **File:** `packing_queues.html`.
- **Issue:** the counts are plain text at the header's right edge. An empty queue says "Nothing here".
- **Fix:** render each count as a 28 px pill. For New, use the alert colours when the count is above 0. Empty-state copy per queue: New "No new orders"; Accepted "Nothing waiting to pack"; Packing "Nothing being packed"; Packed "No bags waiting for a rider".

### C. Confirmations and destructive actions

#### PC-09 · Major · Cancel order: placement and dialog focus
- **Screen / file:** `packing_queues.html` (cancel button), `templates/ops/components/cancel_dialog.html`, and `orders.js` store `cancelOrder`.
- **Issues:**
  1. "Cancel order" is a red text link on the same row as the primary step button (`ml-auto`), about 20 px high. With gloves it is easy to hit by mistake. The dialog does catch it, but it costs time.
  2. When the dialog opens, focus stays on the page behind it. There is no initial focus and no focus trap, and on close focus is not returned to the trigger.
  3. Clicking the backdrop closes the dialog and silently discards the chosen reason and note.
  4. Submitting closes the dialog **before** the server answers. If the server refuses, the reason is lost and only a toast explains it.
- **Fix:**
  - Move "Cancel order" into a `more_vert` overflow button (48 × 48 px) in the ticket header. Alternatively keep it in the action row as an outlined danger button (48 px) **separated by 24 px**, never next to the step button.
  - In the dialog, focus the **Reason** select on open. Trap Tab inside the dialog and return focus to the trigger on close. Alpine's `x-trap` plugin does this; it would need to be vendored and pinned.
  - Backdrop click does nothing when the form is dirty. Escape asks "Discard this cancellation?"
  - Keep the dialog open with a busy state on the submit button (`aria-busy`, spinner, label "Cancelling…") until the response arrives. Close on 204. On refusal, show the error inline in the dialog (`role="alert"`).
  - The copy is good ("Keep the order" / "Cancel order", "This cannot be undone"). Add the payment line from the server: "Paid online: refunded in full." or "Cash on delivery: nothing to collect."

#### PC-10 · Major · Step buttons can be double-submitted
- **File:** `packing_queues.html` (`hx-post` on Accept, Start packing and Mark packed).
- **Issue:** there is no `hx-disabled-elt` and no busy state. A double tap with gloves sends two requests, and the second returns `INVALID_STATE_TRANSITION`, which shows a red "refused" toast for an action that actually worked.
- **Fix:** add `hx-disabled-elt="this"` and `hx-indicator` on each step button. While the request runs, show the label "Accepting…" with a spinner and `aria-busy="true"`. On success the poll re-renders the queue (already the case via `ops:refresh`).

#### PC-11 · Minor · "Mark packed" is disabled with no visible reason
- **File:** `packing_queues.html`.
- **Issue:** the button is disabled until every line is ticked, and the reason lives only in `title`, which touch screens do not show.
- **Fix:** while it is disabled, show "**3 of 5 items ticked**" next to it (16 px, `base-600`), driven by Alpine (`pickedCount / pick_ids.length`). Use `aria-describedby` to point the button at that text.

### D. Keyboard, scanner and focus

#### PC-12 · Major · Polling destroys focus and position
- **Files:** `packing_queues.html` (`hx-swap="outerHTML"`), `live_board_columns.html`.
- **Issue:** every 10 s, and after every action (`ops:refresh`), the whole queue element is replaced. Keyboard and switch users lose focus to `<body>`. A screen-reader user is thrown to the top of the page. On a tablet, the scroll position inside a long queue can jump.
- **Fix:** use the **idiomorph** htmx extension (`hx-ext="morph"`, `hx-swap="morph:outerHTML"`), vendored with a pinned version like the other files in `static/ops/vendor/`. Give every ticket and button a stable `id` (`ticket-<order.pk>`, `accept-<order.pk>`). Morphing keeps focus, scroll and Alpine state. If morphing is not adopted, restore focus in `htmx:afterSettle` by the id that was focused before the swap.

#### PC-13 · Major · Polled updates are not announced (ARIA)
- **Files:** `console.html`, `packing_queues.html`, `live_board_columns.html`.
- **Issues:** nothing announces new orders, status changes or breaches. The only live region is the toast container. Adding `aria-live` to the polled region itself would make a screen reader read the whole board every 10 s.
- **Fix:**
  - Add **one** visually hidden live region **outside** the polled element: `<div id="ops-announcer" class="sr-only" role="status" aria-live="polite" aria-atomic="true">`.
  - `orders.js` writes short sentences only on change: "2 new orders." / "Order JQ-1042 is late." / "Order JQ-1040 packed." Use `aria-live="assertive"` (a second region) only for a **new order** and a **LATE** transition.
  - Timers: give the timer `<span>` `role="timer"` and `aria-live="off"`, plus an `aria-label` refreshed on each poll (not each second): "Accept within 45 seconds".
  - Queue `<section>`: `aria-labelledby` is already set. Add `aria-describedby` pointing at the count pill: "New orders, 2".

#### PC-14 · Minor · No scanner or keyboard path
- **Screen:** packing console.
- **Issue:** staff cannot find an order by scanning the bag label QR or typing the order number or pickup code. Keyboard users must Tab through every ticket to reach a button.
- **Fix (P5 or later, worth a UAT question):**
  - Add a "**Scan or type order code**" field (48 px, `inputmode="text"`, `autocomplete="off"`) in the store bar, **outside** `#packing-queues`, so it does not pause polling. Enter scrolls to the matching ticket, highlights it for 3 s with a 3 px `primary-600` outline and moves focus to its next step button. "No active order with code K7QD" shows inline.
  - Do not autofocus it on tablets, because that opens the soft keyboard.
  - Shortcuts (desktop only, listed in a `?` help popover): `/` focuses the scan field and `Esc` closes dialogs. Do **not** add single-key shortcuts for Accept, because a scanner's keystrokes would trigger them.

#### PC-15 · Minor · Focus styles are missing on some controls
- **File:** `ops.css`.
- **Issue:** `:focus-visible` is styled only for `.ops-button`, `.ops-icon-button` and `.ops-page`. The text-link buttons (`Cancel order`, `Update`), the checkboxes and the toast close button rely on browser defaults, which are hard to see on the white card.
- **Fix:** `.ops-link-button:focus-visible, .ops-check:focus-visible, .ops-toast__close:focus-visible, .ops-ticket :focus-visible { outline: 3px solid var(--color-primary-600); outline-offset: 2px; }`. `primary-600` on white is 5.54:1.

### E. Slip and bag label

#### PC-16 · Major · Printing opens a new tab that hides the console
- **Files:** `packing_queues.html` (`target="_blank"`), `static/ops/js/slip.js`.
- **Issue:** "Print slip" opens a new tab, and staff must print and then switch back. On a shared tablet the slip tab is often left in front. The console is then hidden: background tabs throttle timers, the banner and title cue go unseen, and the sound may be suppressed.
- **Fix:** print **without leaving the console**. Load the slip URL into a hidden `<iframe>` and call `iframe.contentWindow.print()` once its QR has rendered (`slip.js` sends `postMessage("ready")`). Keep the new-tab link only as a fallback for browsers that block iframe printing. If the tab stays, add `window.addEventListener("afterprint", () => window.close())` to the slip page.

#### PC-17 · Major · Label and slip sizes are not defined for real printers
- **Files:** `static/ops/css/slip.css`, `templates/ops/store/slip.html`.
- **Issues:**
  1. The bag label and the order slip print on the same sheet. A label printer (4×6" / 100×150 mm, or 75×50 mm) gets both, so the slip overflows onto a second label.
  2. `max-width: 22rem` (about 93 mm) is wider than an 80 mm thermal roll (72 mm printable), so the right edge is clipped.
  3. There is no `@page` rule, so the browser adds its default margins and the URL/date header and footer.
- **Fix:**
  - Two print buttons on the ticket: "**Print bag label**" (primary) and "Print order slip" (secondary), sending `?part=label` and `?part=slip`. Until the store's printer is known, also offer "Print both".
  - `@page { size: 100mm 150mm; margin: 4mm; }` for the label (default). Use `size: 80mm auto; margin: 2mm` for thermal rolls, switched by a `?paper=` parameter. This later becomes a store setting (see "APIs required").
  - Print layout for the label, in mm: store code 10 pt; order number 16 pt / 700; **pickup code 48 pt / 800 mono, letter-spacing 0.2em** (the screen value of 3 rem is fine); QR **35 mm square** with a **4-module quiet zone** (`margin: 4` in `createSvgTag`, currently 2); item count 14 pt / 700; payment line 12 pt. Pure black on white only, with no greys, because thermal printers dither greys.
  - Payment line: keep "Cash on delivery" / "Paid online". Do **not** print the COD amount on the label, because the bag is handled in public. The rider app shows the amount.
  - The pickup alphabet already excludes look-alikes (`ACDEFGHJKLMNPQRTUVWXY34679`, no 0/O, 1/I, 2/Z, 5/S, 8/B), which is good for both legibility and typing.
- **Slip print layout:** 11 pt body, item name and variant on one line, "Pack N" column at 14 pt / 700 (PC-04). Lines that are entirely unavailable are omitted (as now), and a footer reads "2 lines not in this order".

#### PC-18 · Minor · On-screen print button
- **File:** `slip.css` `.slip-actions button`.
- **Fix:** make it 48 px high with an icon. If the iframe flow from PC-16 is used, the page needs no button except as a fallback.

### F. Store bar, live board and states

#### PC-19 · Minor · Stale data is not obvious
- **Files:** `packing_queues.html`, `live_board_columns.html`, `ops.js` (network error toasts).
- **Issue:** when polling fails, "Updated 14:02:10 IST" keeps its old time in 12 px subtle text. Every failed poll also adds a new "Network error" toast (one every 10 s).
- **Fix:** keep `lastOkAt` in JS. After 25 s without a successful poll, show a sticky warning bar: "**Not updating: check the connection.** Last update 14:02 IST." (`orange-800` on `orange-50`, 6.94:1, icon `wifi_off`, with a "Retry now" button that triggers `ops:refresh`). Hide the bar on the next success. Show at most one network toast per outage (dedupe by message).

#### PC-20 · Minor · Live board card details
- **File:** `templates/ops/partials/board_column.html`.
- **Issues:**
  - The card text is 12 px (`text-xs`) for payment and item count.
  - "COD" and "Online" are abbreviations, which the packing console avoids.
  - The cancel link is a 20 px text button.
  - Five columns at a 13 rem minimum scroll sideways on a tablet without any hint.
- **Fix:**
  - Card body 14 px.
  - Use the same LATE / DUE SOON badges as PC-06.
  - Cancel at 48 px (PC-05).
  - Add a right-edge fade and "Scroll for more columns →" below 1280 px.
  - Add a column summary row "**3 late**" in red-700 text with the `alarm` icon, so breaches are countable without reading cards.
  - The summary line "N past the SLA" is good. Make it 16 px.

#### PC-21 · Minor · "Pause orders" state
- **File:** `console.html`.
- **Issues:** the reload after toggling causes the PC-02 audio loss. The paused state is only a small label.
- **Fix:** swap the store bar with HTMX (`hx-target="#store-bar"`) instead of `window.location.reload()`. While paused, show a full-width bar above the queues: "**Paused: customers can't order from this store.**" (white on `red-700`, 6.42:1) with a 48 px "Resume orders" button. Staff forget a paused store more often than they forget anything else on this screen.

#### PC-22 · Minor · Packed queue has no rider or handover information
- **Screen:** Packed queue.
- **Issue:** 05 §1.3 "Handover" (the assigned rider and their status) is not shown yet. This is expected before P5, but the copy "Hand over when the rider shows this code or scans the bag label" will confuse staff at UAT if no rider ever appears.
- **Fix (P5):** a rider row with name, vehicle, "On the way · 3 min" or "**At store**" (badge with icon `two_wheeler`, not colour only). For P4 UAT, add "Rider assignment comes in the next phase" so testers don't file it as a bug.

---

## Contrast record (pairs used on these screens)

| Pair | Ratio | AA normal text (4.5) | AA large text / non-text (3) | Action |
|---|---|---|---|---|
| `base-500` #6a7282 subtle text on white | 4.84 | Pass | Pass | Keep |
| `base-500` on `base-50` #f9fafb (board column) | 4.63 | Pass | Pass | Keep |
| `orange-600` #f54a00 warning text on white | 3.58 | **Fail** | Pass | Use `orange-700` (5.22) or `orange-800` (7.37) |
| `orange-500` #ff6900 warning border on white | 2.89 | n/a | **Fail** | Use `orange-700` |
| `green-600` #00a63e success text on white | 3.22 | **Fail** | Pass | Use `green-700` (4.95) |
| `red-600` #e7000b danger text on white | 4.77 | Pass (margin is small) | Pass | Prefer `red-700` (6.42) |
| White on `primary-600` #9810fa (buttons) | 5.54 | Pass | Pass | Keep (unfold default purple; the brand colour waits for D-06) |
| White on `red-600` (danger button) | 4.77 | Pass | Pass | Prefer `red-700` (6.42) |
| `orange-800` #9f2d00 on `orange-50` #fff7ed (DUE SOON badge, stale bar) | 6.94 | Pass | Pass | New |
| White on `red-700` #c10007 (LATE badge, paused bar) | 6.42 | Pass | Pass | New |
| `base-600` #4a5565 on white (SKU, helper text) | 7.56 | Pass | Pass | New |
| Slip: #111 on white | 18.88 | Pass | Pass | Keep |

Dark mode was not audited in detail. The proposed tones must be re-checked against `base-900` before the dark variants ship.

## Proposed tokens (for `design/tokens/`, follow-up)

These are aliases over the unfold variables the Ops Console already loads, so `admin-panel-dev` can use them in `ops.css` today.

```css
:root {
  --ops-tone-warning-text: var(--color-orange-700);   /* 5.22:1 on white */
  --ops-tone-warning-border: var(--color-orange-700);
  --ops-tone-warning-badge-fg: var(--color-orange-800);
  --ops-tone-warning-badge-bg: var(--color-orange-50); /* 6.94:1 */
  --ops-tone-danger-text: var(--color-red-700);       /* 6.42:1 */
  --ops-tone-danger-badge-bg: var(--color-red-700);   /* white text 6.42:1 */
  --ops-tone-success-text: var(--color-green-700);    /* 4.95:1 */
  --ops-target-step: 56px;
  --ops-target-min: 48px;
  --ops-ticket-border: 6px;
  --ops-font-order-number: 18px;
  --ops-font-product: 18px;
  --ops-font-qty: 24px;
  --ops-font-rack: 16px;
  --ops-focus-ring: 3px solid var(--color-primary-600);
}
```

## APIs and data required (owner: django-backend-dev, through admin-panel-dev)

1. **New total and refund on the ticket (UAT-P4-06):** the console shows no amounts, so "the console shows the new total" cannot pass. Expose on the ticket context, as server-computed values: `order.grand_total`, the previous grand total after a T8a change (or the latest adjustment's `amount_refunded` / `cod_amount_due`), and the payment method. The success toast for "Can't supply" should then read: "Groundnut Oil 1 L: 1 unit removed. New total ₹498. ₹249 refunded to the customer." (or "Rider collects ₹498."), with values taken from the service's return value.
2. **Preview for the "Can't supply" dialog (optional, nice to have):** a read-only `preview_unavailable(order, item, total_unavailable)` returning the new grand total, the refund or new COD due, and `cancels_order: bool`, all from `compute_bill()`. Without it the dialog uses the generic consequence copy in PC-03.
3. **`line.to_pack`** (units to pack) and **`ticket.would_empty_if_all_removed`** per line, from `packing.py` (admin-panel-dev can add these; no backend change).
4. **Store printer profile** (P5): `DarkStore.label_paper` (`100x150`, `75x50`, `80mm-roll`), used by the slip `@page` rule.
5. **SLA value:** confirm `ORDER_ACCEPTANCE_SLA_SECONDS` for the UAT (the script says 60 s, the code defaults to 120 s).

## Implementation tasks: admin-panel-dev

| Priority | Task | Findings |
|---|---|---|
| Before UAT | Fix the polling guard (checkbox), add the 30 s cap | PC-01 |
| Before UAT | "Start shift" audio unlock, repeating alert, banner, tab title, focus on the safe button in danger confirms | PC-02, PC-03.3 |
| Before UAT | "Can't supply" dialog with chips, item and quantity in the copy, `min` = current value, irreversibility copy | PC-03 |
| Before UAT | Show "Pack N" in the pick list and on the slip | PC-04 |
| Before UAT | Target sizes (56 / 48 px), row-level tick hit area | PC-05 |
| Before UAT | LATE / DUE SOON badges, `data-left` on every ticket, contrast tokens | PC-06 |
| Phase 4 | Packing type scale, focus layout without sidebar | PC-07, PC-08 |
| Phase 4 | Cancel in overflow, dialog focus trap, keep open until the response | PC-09 |
| Phase 4 | `hx-disabled-elt`, busy labels, "N of M ticked" | PC-10, PC-11 |
| Phase 4 | Idiomorph swap, announcer live region | PC-12, PC-13, PC-15 |
| Phase 4 | Print through a hidden iframe, separate label and slip, `@page` sizes, QR quiet zone 4 | PC-16, PC-17, PC-18 |
| Phase 5 | Stale bar, board card details, paused bar, handover rider row, scan field | PC-14, PC-19 to PC-22 |

## Questions to add to the UAT-P4-13 questionnaire

1. Which printer and paper does the store have (A4 laser, 4×6 label, 80 mm thermal)?
2. Do staff wear gloves while using the tablet? Which tablet model, and is it mounted landscape?
3. Would a scanner or "type the code" box help at handover?
4. Was the alert sound loud and long enough in the store?
