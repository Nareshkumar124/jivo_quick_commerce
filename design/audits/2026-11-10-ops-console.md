# UX audit: Ops Console and admin screens (everything except the packing console)

- **Date:** 2026-11-10
- **Auditor:** ui-designer
- **Scope:** the staff web panel screens not covered by `design/audits/2026-11-04-packing-console.md`:
  - Ops Console (`/ops/`): dashboard (KPIs, alerts, charts), live order board (status of the earlier findings only), dispatch board and task page, cash deposits, payouts, store returns, support tickets, reports and exports, the shared shell (header, sidebar, toasts, dialogs, polling).
  - Django Admin (unfold): order detail and the manual refund page, refund retry, riders and KYC documents, customers (masked PII, block, COD), ratings, CMS pages, FAQs and app configuration.
  - Every role: Super Admin, Ops / Dispatch, Store Manager, Store Staff, Support, Finance, Catalog Manager.
- **Not in scope:** the packing console itself, the slip and the "Can't supply" dialog (audited 2026-11-04; spec `design/screens/ops/cant-supply-dialog.md`).
- **Build audited:** `develop` 67e54d9 at `.worktrees/design/backend/` (read-only): `apps/ops_console/` (views, templates under `templates/ops/`), `static/ops/`, the `admin.py` files, `templates/admin/`, `config/admin_ui.py`.
- **Contract:** `docs/05-admin-and-store-panel.md` §1, §3 (role matrix and the phase permission notes), §4 and §5; decisions DL-35, DL-37, DL-39, DL-40 (and DL-59 and DL-61, which §3 cites).
- **Method:** static review of templates, CSS, JavaScript and views. **Nothing was run** (no server, no browser). Sizes come from the CSS. Contrast uses `design/tokens/ops.tokens.json` and the sRGB values of unfold's Tailwind colours, computed with `design/tools/hct.py`. Layout widths are worked out from the CSS for a 1280×720 laptop and a 1024×768 landscape tablet; each one says how sure it is.
- **Users and context:** Ops / Dispatch and Support at desktops or 1280 px laptops for whole shifts; Store Managers on the store's landscape tablet, standing, often in a hurry; Finance and Catalog Managers at desktops; Super Admin rarely, for configuration.

## Severity

| Severity | Meaning |
|---|---|
| **High** | Can move money or change access wrongly, fail silently, or block every app user. Fix before the next ops UAT. |
| **Medium** | Slows staff down, causes errors under pressure, loses typed work, or fails WCAG AA. Fix in the current phase if possible. |
| **Low** | Polish, or a later-phase risk. |

**What already works well (keep it):**
- **Permissions are enforced on the server for every screen and action** (`ops_view(capability=…)`, the services re-check), the sidebar shows only what a role may open, and another store's object is a 404.
- **Long lists are bounded everywhere:** board columns show the oldest cards plus "+ N more · See all", dispatch shows the oldest 100, cash the 100 riders with the most cash, tickets and payouts paginate, big reports switch to background exports.
- **Most risky Ops Console actions already have a confirmation that states the effect:** force offline ("Their shift ends and they get no more offers"), take the rider off, assign (names the rider and the order), unlock codes, mark delivery failed, void payout, receive return, cancel order (with a reason).
- **A danger confirmation opens with focus on Cancel**, so a stray Enter never confirms (from PC-03).
- **Privacy by design:** masked phones for limited roles, KYC files and numbers behind an audited POST, ticket photos as short-lived signed links, no PII in toasts, no htmx history cache.
- **Charts have a data table** ("Show data") and a text summary for screen readers; the board has polite and urgent announcers and a stale-data banner.
- **Money is never computed in the page:** every amount comes from the server and is only formatted.

## Status of the 2026-11-04 findings that touch the live board

| ID | Status on 67e54d9 | Where now |
|---|---|---|
| PC-05 targets | **Fixed** on the packing console and the board (`.ops-touch`, board buttons 48 px). Every other Ops screen still uses 38 px | OC-04 |
| PC-09 cancel dialog | **Open:** no initial focus, no focus trap, backdrop click discards the reason, and the dialog closes before the server answers (`orders.js:217-235`) | OC-03 |
| PC-10 double submit | **Fixed** on the packing steps (`hx-disabled-elt`); nowhere else | OC-01 |
| PC-12 focus lost on refresh | **Open** on the board (`live_board_columns.html:31-33`, `outerHTML`; only the banners restore focus, `orders.js:429-437`) | OC-03 |
| PC-13 announcements | **Fixed** (`live_board.html:21-22`) | n/a |
| PC-19 stale data | **Fixed** on the board and the console; the "one network toast per outage" part now hides failed actions | OC-01, OC-05 |
| PC-20 card details | **Mostly fixed** (14 px body, words instead of "COD", late counts, 48 px cancel). The sideways-scroll hint is missing, and at 1280 px the last column is off screen | OC-04 |

---

## Top 5 fixes (ranked by user impact)

| # | ID | Severity | Fix in one line |
|---|---|---|---|
| 1 | OC-17 | High | "Record deposit" asks to confirm without repeating the amount typed, so ₹5,200 typed as ₹520 (or the reverse, up to the cash in hand) is recorded, and only a Super Admin can correct it. Put the amount and the rider's current cash in the confirmation. |
| 2 | OC-01 | High | During a network drop, an action (assign, deposit, mark paid, receive return) fails with **no message at all**, because the network toast is shown once per outage; and no action except the packing steps shows a busy state. Always report a failed action, and add a busy state. |
| 3 | OC-11 | High | The manual refund page sends money with one click, without a confirmation step, and its limit text is wrong ("up to the role limit per refund"; the rule is ₹500 per order and ₹5,000 per day, DL-59). Add a confirm step that states amount, destination and timing, and show the agent's remaining allowance. |
| 4 | OC-23, OC-24 | High | "Allow cash on delivery again" in the Customers admin lifts COD blocks for Support too, bypassing the DL-61 d permission (`delivery.lift_cod_block`, Super Admin and Ops) and its audit entry; and block / unblock / COD actions run on the ticked rows with no confirmation. Route the lift through `lift_cod_block` and add a confirm page. |
| 5 | OC-30 | High | Saving App configuration with maintenance on (every app call answers 503, so riders can't finish deliveries) or a higher minimum version (forces everyone to update) takes effect at once with no confirmation. Add a confirm page with the live counts. |

The most important Medium is **OC-04**: on a 1280 px laptop the live board's fifth column ("Out for delivery") is off screen, and on the 1024 px store tablet the dispatch and cash tables hide their action buttons behind a sideways scroll.

---

## Findings

### A. Shell, actions and states (every Ops Console screen)

#### OC-01 · High · Failed actions are silent during an outage, and actions show no busy state
- **Screen / file:** `static/ops/js/ops.js:148-157` (`htmx:sendError` shows a toast only when `offline` is false; a failing poll sets it and only a successful request clears it). Forms without `hx-disabled-elt` or a busy label: `templates/ops/partials/dispatch_task.html:58-122` (take off, search again, unlocks, mark failed, assign), `dispatch_board.html:137-141` (force offline), `cash_riders.html:52-64` (record deposit), `payouts_list.html:54-65` (mark paid, void), `returns_list.html:112-128` (receive return), `payouts/index.html:11-17` (create batch).
- **Issue:**
  1. When the network drops, the first failing poll shows "Network error…" (it disappears after 6 s, OC-02) and sets `offline = true`. Every later failure is silent. A Store Manager who then records a deposit, or an Ops agent who assigns a rider, closes the confirmation and sees nothing: no error and no success. Both look the same at a glance, so the action can be assumed done.
  2. Apart from the packing steps (PC-10), no action button shows that it is working. On a slow connection, staff confirm again; a second "Assign" comes back as a red "refused" toast for an action that worked.
- **Fix:**
  - Keep the one-toast-per-outage rule **for polls only**. A request triggered by a user (any `hx-post`, or a request whose `event.detail.requestConfig.triggeringEvent` is a click or submit) always shows its own error: "**Not sent: no connection.** Assign Ravi Kumar to JQ-1042 was not saved. Try again when you're back online." (`role="alert"`).
  - On every action form: `hx-disabled-elt="find button[type=submit]"` and `hx-indicator`, with the button label switching to "Assigning…" / "Recording…" / "Saving…" and `aria-busy="true"`.
  - Keep the server keys that already make deposits idempotent.

#### OC-02 · Medium · Error toasts vanish after 6 seconds
- **Screen / file:** `static/ops/js/ops.js:14` (`TOAST_MS = 6000`) and `:36` (every toast, whatever its tone, is dismissed by a timer); `templates/ops/components/toasts.html`.
- **Issue:** refusals carry the important reason ("Support can refund at most ₹500 on this order", "The rider is no longer at the store"). They disappear after 6 s, often while the agent is reading another part of the screen. WCAG 2.2.1 (timing adjustable) also applies.
- **Fix:** success and info toasts keep 6 s; **warning and danger toasts stay until dismissed** (the 40 px close button exists). Keep at most 3 on screen (the oldest closes first). Pause the timer while the pointer or focus is on a toast.

#### OC-03 · Medium · Focus is lost after dialogs and HTMX swaps
- **Screen / file:**
  - `templates/ops/components/confirm_dialog.html:10-25` and `ops.js:43-68`: the shared confirmation focuses a button on open, but there is no focus trap, and on close focus is not returned to the trigger (it falls to `<body>`).
  - `cancel_dialog.html` and `orders.js:217-235` (PC-09, still open).
  - `components/pagination.html:164-166`: the clicked page link is part of the swapped region.
  - `partials/order_dashboard.html:171-172`: the filter form sits inside the section it replaces (also OC-09).
  - `partials/dispatch_task.html:14-15`, `cash_riders.html:29-30`, `returns_list.html:98-99`, `live_board_columns.html:31-33`: polls or `ops:refresh` replace the region that holds the focused control.
- **Issue:** a keyboard or screen-reader user who confirms "Assign", records a deposit or opens page 2 of a table lands at the top of the page and has to tab back through the sidebar.
- **Fix:**
  - Both dialogs: remember `document.activeElement` on open; trap Tab inside (vendor Alpine's `x-trap` plugin at a pinned version, like the other files in `static/ops/vendor/`); on close, focus the trigger if it still exists, else the region's heading.
  - Swaps: the idiomorph extension proposed in PC-12 (`hx-ext="morph"`), or a small `htmx:beforeSwap` / `htmx:afterSettle` pair that remembers the focused element's `id` (give every action button a stable id such as `assign-<task>-<rider>`) and refocuses it, else the region's `<h2>` (`tabindex="-1"`).
  - Pagination: after a page swap, focus the table's caption or first row, and announce "Page 2 of 7".

#### OC-04 · Medium · Layout on the 1280×720 laptop and the 1024×768 store tablet
- **Screen / file:** `static/ops/css/ops.css:10` (sidebar 272 px), `:15` (it only becomes a drawer below 1024 px), `:121` (board: 5 columns of at least 13 rem), `:307-308` (dispatch and cash: 2 columns from 1024 px), `:53` and `:63` (38 px icon buttons and buttons), `:78` (32 px page links); `.ops-touch` is used only by the packing console and returns.
- **Issue (worked out from the CSS; check on the devices):**
  | Device | Content width | What happens |
  |---|---|---|
  | 1280×720 laptop | 1280 − 272 − 32 = 976 px | The board needs 5 × 208 + 4 × 12 = 1,088 px, so "Out for delivery" is off screen with no hint (PC-20). |
  | 1024×768 tablet, landscape | 1024 − 272 − 32 = 720 px (the sidebar is still docked at exactly 1024 px) | The board shows about 3 columns. Dispatch and cash split into two ~350 px columns, so the 7-column riders table and the deposit form scroll sideways and hide **Force offline** and **Record**. |
  | Both | n/a | Buttons and icon buttons are 38 px and page links 32 px on dispatch, cash, payouts, support, reports and the dashboard, used by Store Managers on the tablet. |
- **Fix:**
  - Make the sidebar a drawer below **1280 px** (`max-width: 1279.98px`), with the menu button already in the header. That gives 1,248 px on the laptop and 992 px on the tablet.
  - Board: `minmax(11.5rem, 1fr)` columns (5 × 184 + 48 = 968 px fits the laptop). Below 1,000 px of content, keep the sideways scroll but add a right-edge fade and "Scroll for more columns →" (PC-20), and show the column counts in a sticky row so off-screen columns are still visible as numbers.
  - Dispatch and cash: **one column below 1280 px**; at any width the riders table keeps its action column visible (`position: sticky; right: 0` on the last cell, with a left border).
  - Apply `.ops-touch` (48 px buttons, 48 px inputs; tokens `ops.target.min`, `ops.target.step`) to dispatch, task, cash, returns and the store bar, and use 40 px page links (44 px in `.ops-touch`).

#### OC-05 · Medium · Stale data is not shown outside the board and the packing console
- **Screen / file:** the stale banner lives in `orders.js:371-380`, which renders into `#ops-alerts`; only `orders/live_board.html:20` and the packing console have that container. `dispatch/board.html`, `dispatch/task.html`, `dashboard.html` and `cash/index.html` don't. Their "Updated 14:02:10 IST" text (`dispatch_board.html:30`) simply stays old.
- **Issue:** a dispatcher watching "Waiting for a rider" during a Wi-Fi drop sees a quiet, normal-looking board for minutes.
- **Fix:** add `<div id="ops-alerts" class="ops-alerts" aria-live="off">` and the announcers to the dispatch board, the task page, cash and the dashboard (the dashboard's 60 s poll needs `STALE_AFTER_MS` of about 150 s). Same banner and copy as PC-19: "**Not updating: check the connection.** Last update 14:02 IST." (`ops.tone.warning.badgeFg` on `badgeBg`, 6.94:1, icon `wifi_off`, "Retry now").

#### OC-06 · Medium · Contrast failures outside the tokens
- **Screen / file:**
  - `static/ops/css/ops.css:322-323`: the live-feed label "Live" uses `green-600` (#00a63e, **3.22:1** on white) and "Connecting" / "Reconnecting" use `orange-600` (#f54a00, **3.58:1**), at 12 px. That label is the only sign of whether updates are live or polled. The ops tokens already rejected both colours.
  - `templates/ops/includes/sidebar.html:124`: the "opens in the admin" arrow is `base-400` (#99a1af, **2.60:1**). It carries meaning (the link leaves the console), so it needs 3:1.
- **Fix:** use `--ops-tone-success-text` (#008236, 4.95:1) and `--ops-tone-warning-text` (#ca3500, 5.22:1) for the live label, plus a different icon per state (`sensors` / `sync` / `sync_problem`) so the state isn't colour only. The arrow becomes `--ops-color-text-secondary` (#4a5565, 7.56:1) and gets the visually hidden text "(opens the admin)".

#### OC-07 · Medium · The 8-hour session cap ends a shift without warning
- **Screen / file:** 05 §5 and `config/settings/base.py:222` (8 h absolute cap for every staff session); `static/ops/js/ops.js:125-127` (a 401 from a poll navigates straight to the login page).
- **Issue:** on the shared store tablet or a dispatcher's laptop, hour 8 arrives mid-rush. The next poll silently navigates to the login page: alerts and sounds stop, the board disappears, and anything typed (a deposit, a reply) is lost.
- **Fix:** put the session's end time in the page (`data-session-ends-at`, from the stamp `apps.accounts.middleware` already sets at login). 15 minutes before, show a sticky banner: "**You'll be signed out at 18:05 IST.** Sign in again at a quiet moment to stay connected." with "Sign in again now" (opens login in a new tab and reloads on return). On a 401, don't navigate: show a full-page overlay "**Signed out.** Sign in to continue; this page stays as it is." with "Sign in".

#### OC-08 · Low · Access refused and the empty landing
- **Screen / file:** `templates/ops/errors/403.html`; `templates/ops/dashboard.html:5-7` and `apps/ops_console/views.py:43-61`.
- **Issue:** "Your role does not have access to this page." gives no next step. Store Staff, whose only Ops module is the packing console, land on a near-empty dashboard and must find their store in the menu.
- **Fix:** add "Ask a Super Admin if you need it. Your roles: Store Staff." to the 403 page. When a user's only Ops module is the packing console and they have one store, send `/ops/` straight to `/ops/store/<code>/`.

### B. Dashboard

#### OC-09 · Medium · The 60-second refresh replaces the filter the user is using
- **Screen / file:** `templates/ops/partials/order_dashboard.html:171-172` (`hx-trigger="change, every 60s"` on the form, `hx-swap="outerHTML"` of `#order-dashboard`, which contains the form itself).
- **Issue:** every minute the form is re-rendered. A store `<select>` that is open closes, keyboard focus drops to `<body>`, and a date being typed is replaced. The section also has no "Updated" time, so nobody can tell whether numbers are current (the other sections say "Refreshes every minute" but not when they last did).
- **Fix:** move the polling to a results-only wrapper (`#order-dashboard-results`) outside the form; the form triggers only on `change`. Pause the poll while the form has focus (the existing `opsPollAllowed` guard). Show "Updated 14:02 IST" next to the section title and in each polled section.

#### OC-10 · Low · Truncated KPI labels and ambiguous "Open" links
- **Screen / file:** `templates/ops/components/kpi_card.html:4` (`truncate` on the label); `partials/order_dashboard.html:200` (every alert row has a link named "Open").
- **Issue:** at the 1280 px width each KPI card is about 185 px, leaving about 127 px for the label, so "Avg acceptance time" and "Avg delivery time" end in "…". Screen readers list six links all called "Open".
- **Fix:** allow the label to wrap to 2 lines (remove `truncate`, keep `min-height`). Name the links: "Open orders waiting for acceptance" (visually "Open", with an `aria-label`).

### C. Orders and money (admin order page)

#### OC-11 · High · Manual refund: one click, no confirmation, and the limit text is wrong
- **Screen / file:** `templates/admin/orders/order/refund.html:25-42`; `apps/ops_console/forms.py:78-108` (`ManualRefundForm`: amount and an optional note); `apps/orders/admin.py:529-584`.
- **Issue:**
  1. "Refund this order" sends money at once. The amount is a free number field bounded only by "Can still be refunded", so ₹2,500 typed for ₹250 goes out if the order allows it. Refunds can't be undone.
  2. The help text says "Support can refund up to the role limit **per refund**". The rule (DL-59, 05 §3) is **₹500 in total per order and ₹5,000 per agent per IST day**. Agents can't see how much of either they have left, so they find out by being refused.
  3. The note is optional, so Finance can't tell why money went out.
  4. For a cash-on-delivery order, the amount field still shows under "Cash on delivery orders have no online payment to refund".
- **Fix:**
  - **Two steps.** Step 1 (the form): amount, a **required reason** (a short list from Finance plus "Other"), an optional note. Step 2 (a confirm panel on the same page, focus on "Go back"): "**Refund ₹250 to the customer's original payment** (paid online, via Razorpay)? It reaches them in 5–7 working days. **You can't undo this.**" Buttons "Go back" and "Refund ₹250" (danger style). The amount on the button repeats the typed value.
  - **Show the allowance** from the server under the amount: "Your limit on this order: ₹500 (₹200 already refunded by Support). Your limit today: ₹5,000 (₹1,300 used)." Finance and Super Admin see "No role limit."
  - Correct the help text to the actual rule.
  - COD orders: no form; show the note and "Nothing to refund online. Cash orders are settled at the door."

#### OC-12 · Medium · The order page lacks the actions and context staff need
- **Screen / file:** `apps/orders/admin.py:426` (`actions_detail = ["issue_refund"]` only) and `:429-471` (fieldsets: no delivery task, rider, notes or cancel). 05 §2 "Orders" lists the delivery task, rider, notes, cancel, refund and resend invoice.
- **Issue:** to handle one customer complaint, Support opens the order in the admin, goes to the live board to cancel, to the dispatch task page to see the rider and the codes, and to Payments → Refunds to retry a failed refund. Each move loses the context and costs time on the phone with the customer.
- **Fix:** an action bar on the order page, each button shown only when the role and the order's state allow it:
  - **Cancel order** (opens the same reason dialog as the board; before pickup only).
  - **Issue refund** (as today, with OC-11).
  - **Open delivery task** (link to `/ops/dispatch/tasks/<id>/`).
  - A "Delivery" fieldset: task status, rider name, pickup and OTP lock state (never the codes), last ping age.
  - **Notes:** 05 §1.2 and §2 list them, but there is no notes model yet (see APIs).

#### OC-13 · Medium · Refund retry is a hidden bulk action without a confirmation
- **Screen / file:** `apps/payments/admin.py:216` and `:244-269` ("Retry failed refund (send to the gateway again)", a changelist action on the Refunds list).
- **Issue:** to retry, staff must know to open Payments → Refunds, find and tick the row, pick the action and press Run. Nothing states the amount or the customer before sending. Non-failed rows are skipped with a warning, so a wrong tick is harmless, but the path is long and invisible from the order or from the `payment.refund_failed` alert.
- **Fix:** in the order page's Refunds section, a **Retry** button on each failed (or stuck pending) refund row, with a confirmation: "Send the ₹250 refund to Razorpay again? The customer is refunded once; a duplicate is refused." The alert's "Open order" link lands on that section (`#refunds`). Keep the bulk action for Finance clean-ups, behind an intermediate confirm page listing the refunds and the total.

### D. Dispatch and riders on the road

#### OC-14 · Medium · There is no rider map
- **Screen / file:** `apps/ops_console/urls.py` (no `/ops/riders/map/`); `templates/ops/partials/dispatch_board.html` (tables only). 05 §1.4 asks for a map with store markers, riders by status and drop pins, plus a rider's trip path. OpenLayers is already vendored (`static/ops/vendor/ol-7.2.2.min.js`, used by the admin's service-area map).
- **Issue:** dispatchers judge "who is near" only from the "From store" km column. Clusters, riders stuck in one place, or a rider heading the wrong way are invisible.
- **Fix (spec outline for admin-panel-dev):** a map panel at the top of the dispatch page (height 360 px; collapsible; one column below 1280 px). Store markers (square), riders as circles with a **letter and colour** per state (I idle, S to store, A at store, D delivering: never colour only), drop pins for active tasks. Clicking a rider highlights the row in the riders table and vice versa; the table stays the accessible alternative. Riders whose last ping is older than 2 minutes are drawn hollow with "last seen 3 min ago". Trip path: a "Show route" link on the task page draws the task's location history.

#### OC-15 · Medium · The task page refresh wipes a half-filled form
- **Screen / file:** `templates/ops/partials/dispatch_task.html:14-15` (the whole panel polls and swaps `outerHTML`), `:90-101` ("Mark delivery failed" in a `<details>` with a reason and a note), `:103-128` (assign candidates).
- **Issue:** the typing guard pauses polling only while focus is inside a text field. A dispatcher who opens "Mark delivery failed", picks a reason, then looks at the timeline (focus leaves the field) loses the open panel and the reason at the next 10 s refresh. The candidate list can also re-order between refreshes (distances and pings change), so the row under the pointer changes. The confirmation names the rider, which catches most mistakes.
- **Fix:** pause the poll while any `<details>` in the panel is open or any form in it is dirty (add the check to `idleAllowed`). Keep candidates in a stable order (by distance, ties by name) and highlight the row being hovered; morph instead of replace (OC-03).

#### OC-16 · Low · "Mark delivery failed" doesn't state this order's outcome
- **Screen / file:** `templates/ops/partials/dispatch_task.html:94`.
- **Issue:** "refunds follow the failed-delivery rules" leaves the dispatcher guessing what the customer gets.
- **Fix:** state the outcome from the server for the chosen reason: "Paid online ₹1,240: the customer is refunded {amount}." / "Cash on delivery: nothing was collected." The refund amounts depend on D-10 (see Questions).

### E. Cash, payouts and returns

#### OC-17 · High · "Record deposit" doesn't repeat the amount
- **Screen / file:** `templates/ops/partials/cash_riders.html:52-64` (`hx-confirm="Record the cash received from {name}? Count it first; the balance goes down at once."`).
- **Issue:** the amount is the one thing to check, and the confirmation doesn't show it. Typing ₹520 for ₹5,200 leaves the rider "over limit" with no COD orders; typing too much (up to the cash in hand) wipes a balance the rider still owes. Cash adjustments are Super Admin only (05 §3), so a store manager can't correct either.
- **Fix:**
  - Build the confirmation from the form (an `htmx:confirm` handler reading the amount field): title "**Record ₹5,200 from Ravi Kumar?**", body "Ravi has ₹5,200 in hand now. Count the cash before you confirm. Only a Super Admin can change a deposit afterwards." Buttons "Not yet" and "**Record ₹5,200**".
  - Keep the typed values when the list refreshes after another rider's deposit (OC-03).
  - Inputs and button 48 px (`.ops-touch`), `inputmode="decimal"` (already).

#### OC-18 · Medium · "Mark paid" has no confirmation, and the reference can't be corrected
- **Screen / file:** `templates/ops/partials/payouts_list.html:54-60`; `payouts/index.html:11-12` (create batch).
- **Issue:** a payout is marked paid with whatever was typed in the 144 px UTR field, in one click. A wrong UTR (or the wrong row) is permanent as far as the UI goes. "Create payouts" confirms without saying how many riders or how much.
- **Fix:** confirm "**Mark ₹3,450 paid to Ravi Kumar?** Reference UTR 4031 2287 9915. You can't change this afterwards." with focus on "Go back". Show a format hint under the field ("12–22 letters and digits from the bank transfer"). For "Create payouts", a server preview in the confirmation: "Creates 18 payouts, ₹62,300 in total, for 3–9 Nov." (see APIs).

#### OC-19 · Medium · "Receive return" doesn't list the counts entered
- **Screen / file:** `templates/ops/partials/returns_list.html:112-128`.
- **Issue:** the confirmation says "Good units go back into stock… This cannot be undone." but not how many. A damaged count left at 0 by mistake puts damaged items back on sale.
- **Fix:** build the confirmation from the inputs: "**Receive JQ-1042?** Back on the shelf: 3 units. Damaged: 1 unit (Jivo Canola Oil 1 L)." Replace the damaged number fields (30 px high) with 48 px − / + steppers like the "Can't supply" dialog.

#### OC-20 · Low · Day-end report: unexplained "difference", no deposit history
- **Screen / file:** `templates/ops/partials/cash_riders.html:86-93`.
- **Issue:** "difference ₹200" doesn't say which way (still with riders, or over-deposited), and there is no list of today's deposits (who recorded what, when) to check against the cash box.
- **Fix:** label each server figure by its meaning (for example "Not yet deposited"), as defined by the cash service, and add "Today's deposits" (time, rider, amount, recorded by) under the report.

### F. Riders and KYC (admin)

#### OC-21 · Medium · KYC: the document isn't visible where it is approved
- **Screen / file:** `apps/delivery/admin.py:497-518` ("Open file": a confirm page, then a redirect to the signed file in the same tab), `:552-571` ("Approve document": a page that says "Check the file before approving it" without the file), `templates/admin/delivery/action_form.html`.
- **Issue:** per document, the reviewer opens the document, confirms "Open file", leaves the admin to the image, comes back, opens "Approve", confirms. With 5–6 documents per rider that is about 20 page loads, and approving without looking is the easy path.
- **Fix:** a **"Review documents" page per rider**:
  - One audited click ("Show documents", POST, as today) renders every document of that rider side by side: image (signed URL, `img` with zoom on click), type, masked number, status.
  - Under each: **Approve** and **Reject** (reject opens preset reasons, OC-22).
  - At the bottom: **Approve rider** (enabled once every required document is approved and bank details exist; else a line saying what is missing).

#### OC-22 · Low · Reject and suspend look like normal actions; reasons are free text only
- **Screen / file:** `templates/admin/delivery/action_form.html:22` (the template ignores the `danger` flag the view passes); `apps/delivery/admin.py:100-105` (`ReasonForm`), `:354-364` (suspend).
- **Issue and fix:**
  - Reject and suspend use the same primary button as approve. Style them as danger (unfold's red button variant) and put focus on "Back".
  - The rejection reason is shown to the rider and written freehand each time. Offer presets ("Photo is blurred or cut off", "Name doesn't match", "Document expired", "Wrong document type") plus an optional note. That keeps rider-facing text consistent and translatable (Hindi later).
  - Suspend: if the rider is on a task, say so on the form ("Ravi is delivering JQ-1042 now."), followed by what `kyc.suspend_rider` actually does with an active task (the developer checks the service; the audit didn't confirm it).

### G. Customers (admin)

#### OC-23 · High · Lifting a COD block bypasses DL-61 d
- **Screen / file:** `apps/accounts/admin.py:630-632` ("Allow cash on delivery again") → `order_actions.set_cod_blocked` → `apps/accounts/services/customers.py:108-129`, which checks no permission of its own; the action needs only the Customer change permission, which Ops **and Support** hold (05 §3 Phase 1 note). DL-61 d puts the lift behind `delivery.lift_cod_block` (Super Admin, Ops) through `apps/delivery/services/ops.py:322-337`, which also stamps `cod_block_lifted_at` and writes the `accounts.cod_block_lifted` audit entry. The UI never calls it.
- **Issue:** Support can let a customer with repeated refused deliveries pay cash again, and the audit log has no `cod_block_lifted` record of it (only an admin LogEntry). **Conclusion** from the code; the PM should confirm which rule is meant (see Questions).
- **Fix:** "Allow cash on delivery again" calls `lift_cod_block` and is shown only to holders of `delivery.lift_cod_block`. Blocking can stay with `set_cod_blocked`. Show "Last lifted: 9 Nov 2026 by Asha (Ops)" from the audit entry.

#### OC-24 · High · Customer actions run on the ticked rows without a confirmation
- **Screen / file:** `apps/accounts/admin.py:458` (`actions = ["block", "unblock", "block_cod", "allow_cod", "anonymise_now"]`), `:590-632`.
- **Issue:** "Block: deactivate and sign out everywhere", "Block cash on delivery" and "Allow cash on delivery again" run as soon as Run is pressed, on every ticked row. A select-all on a page of 50 customers blocks 50 accounts and signs them out. Only "Anonymise now" has a confirmation page. The actions also exist only on the list, so to block one customer staff go back to the list, find and tick the row, which is how the wrong row gets ticked.
- **Fix:**
  - An intermediate confirmation page for each (reuse the anonymise pattern): the customers' names and masked phones, the count, the effect ("They are signed out on every device and can't log in until unblocked." / "Cash on delivery isn't offered at their next checkout; orders already placed don't change."), a **required reason**, and "Go back" focused.
  - The same actions as buttons on the customer's page (`actions_detail`), with the same confirmation.

### H. Support tickets (Ops Console)

#### OC-25 · Medium · Choosing a canned reply erases the typed reply
- **Screen / file:** `templates/ops/support/detail.html:44-54` (the select's `hx-get` replaces `#reply-body`); `apps/ops_console/support_views.py:300-314` (`canned_reply` renders a new form holding only the canned text).
- **Issue:** an agent who writes two sentences and then picks a canned reply to add the standard part loses the two sentences, with no undo.
- **Fix:** insert the canned text at the cursor (or append it after a blank line) in the page, without replacing the field: return the text only (or JSON) and insert it with a small script. If the field isn't empty and inserting isn't possible, ask "Replace your draft with this reply?" first. Reset the select to "Choose…" after inserting.

#### OC-26 · Medium · The ticket thread doesn't update, and two agents can reply at once
- **Screen / file:** `templates/ops/support/detail.html:19-38` (rendered once; no polling).
- **Issue:** a customer's new message (or a colleague's reply) appears only after a reload. The agent may answer an outdated question, or two agents may answer the same ticket.
- **Fix:** poll the thread (not the reply form) every 20 s while the page is open. When something new arrives, show "**New message from the customer** (14:05)" or "**Asha replied** (14:05)" above the reply box and scroll it into view. On send, include the `last_activity_at` the page was built with; if the server's is newer, keep the draft and show "Someone wrote since you opened this ticket. Read it, then send." (see APIs).

#### OC-27 · Medium · A reply can close the ticket for good without asking
- **Screen / file:** `apps/ops_console/support_views.py:86-91` (the reply form's "Then set status" offers every status, Closed included); `templates/ops/support/detail.html:55-56`; no double-submit protection on these plain forms (`submit_once.js` is loaded only on the refund page).
- **Issue:** Closed is terminal ("The customer can open a new one"). Choosing it in a dropdown next to "Send reply" ends the conversation in one click; a double click may also send the reply twice. **Possibility** for the duplicate: depends on the service.
- **Fix:** when the chosen status is Resolved or Closed, the button label changes to "Send and close" and a confirmation follows: "Close TK-1042 after sending? The customer can't reply to it any more." Add the one-time token and `submit_once.js` to the reply and status forms.

#### OC-28 · Low · Ticket photos are bare "Photo 1" links
- **Screen / file:** `templates/ops/support/detail.html:27-33`.
- **Issue:** the agent can't tell which photo is which before opening it, and the link opens a new tab without saying so.
- **Fix:** "Photo 1 (opens in a new tab)" with the file type and size from the upload record. Keep opening them on click, so each view stays audited (thumbnails would create an audit entry on every page load; see Questions).

### I. Reports

#### OC-29 · Low · Background exports don't refresh, and failures give no reason
- **Screen / file:** `templates/ops/reports/results.html:61-73`; `apps/ops_console/report_views.py:244-269`; `templates/ops/reports/report.html:20-21` (filters fire `change` with no `hx-sync`).
- **Issue:** "Export queued. It appears below when it is ready." but the list only changes on reload. A FAILED export says only "Failed". Fast filter changes can show an older response last.
- **Fix:** poll the exports list every 10 s while any export is pending or running; show "Failed: try again" with a retry button for a failed export. Add `hx-sync="this:replace"` to the filter form.

### J. CMS and app configuration (admin)

#### OC-30 · High · App configuration changes with platform-wide effect go live with no confirmation
- **Screen / file:** `apps/cms/admin.py:29-71` (`AppConfigAdmin`: maintenance, version policies inline, payment window, rider location intervals; a plain admin save).
- **Issue:** one save can block every customer and rider (maintenance: every app API call answers 503, so riders out on deliveries can't enter the OTP or record cash), or force every user of an older version to update (a mistyped minimum version such as "2.0.0"). The help text explains it, but nothing stops a slip.
- **Fix:** an intermediate confirmation on save when maintenance goes from off to on, or any minimum version goes up:
  - "**Turn maintenance on now?** Every customer and rider app stops working until you turn it off. Right now: **14 deliveries on the road, 37 active orders.**" (counts from the server).
  - "**Raise the minimum Android customer version to 1.4.0?** Users below it must update before they can order." When available, add how many active devices are below it.
  - Buttons "Go back" (focused) and the action. The change is written to the audit log as today.

#### OC-31 · Medium · CMS pages: raw HTML, silent clean-up, no preview
- **Screen / file:** `apps/cms/admin.py:90-106` (`PageAdmin`: a 24-row textarea for `body_html`); `apps/cms/html.py:49` (`Page.save()` sanitises with nh3). 05 §2 asks for a rich-text editor.
- **Issue:** legal pages (Terms, Privacy, Refund policy) are edited as raw HTML. On save, anything outside the allow-list (and links the apps don't follow) is removed without telling the editor, so a published page can differ from what was pasted.
- **Fix:** a **Preview** panel beside the textarea showing the sanitised result (render `sanitize_html(body)` on demand). After save, a message: "Saved. 3 items were removed because the apps can't show them: 2 links (http), 1 table." Publishing or unpublishing a legal page asks for confirmation ("Customers see this version at once."). A rich-text editor stays optional while the preview exists.

---

## Role check (who sees what, and the issues that touch them)

| Role | Ops Console modules (by capability) | Main issues |
|---|---|---|
| Super Admin | everything | OC-30 (config), OC-31 (CMS), OC-24 (customer actions) |
| Ops / Dispatch | dashboard, board, dispatch, cash, support, reports; admin: customers, riders, orders | OC-01, OC-04, OC-05, OC-14, OC-15, OC-21, OC-23 |
| Store Manager (own stores) | dashboard, board, packing, dispatch, cash, returns, reports, ratings | OC-04 (tablet), OC-17 (cash), OC-19 (returns), OC-07 (session) |
| Store Staff (own stores) | packing console only; no returns (needs `delivery.dispatch_order`) | OC-08 (landing); see Questions on returns |
| Support | board (view, cancel before pickup), support tickets, customers (full PII), orders, refunds ≤ ₹500 per order | OC-11, OC-23 (can lift COD today), OC-25, OC-26, OC-27, OC-12 |
| Finance | dashboard orders, refunds, payouts, cash (record and ledger), reports including finance, audit log (view) | OC-11, OC-13, OC-17, OC-18 |
| Catalog Manager | dashboard stock cards, catalog reports; admin catalog and coupons | OC-10; admin catalog screens not reviewed in depth here |

## APIs and data required

| # | Need | For | Owner |
|---|---|---|---|
| 1 | The refund allowance for the signed-in agent: remaining amount on this order and remaining today (Support limit, DL-59), or "no limit" | OC-11 | django-backend-dev (payments service), shown by admin-panel-dev |
| 2 | The session's end time in the page context | OC-07 | admin-panel-dev (stamp exists in `apps.accounts.middleware`) |
| 3 | A payout batch preview (rider count and total for a period) | OC-18 | django-backend-dev (payouts service) |
| 4 | Reply concurrency: `staff_reply` accepts the `last_activity_at` the page saw and refuses (or warns) when it changed | OC-26 | django-backend-dev (support services) |
| 5 | Counts for the maintenance confirmation: deliveries on the road, active orders | OC-30 | admin-panel-dev (selectors; the data exists) |
| 6 | Order notes (05 §1.2 "add note", §2 "notes"): model and service | OC-12 | django-backend-dev |
| 7 | The outcome of a failed delivery for a reason (refund amount, COD consequence) as a preview | OC-16 | django-backend-dev, after D-10 |
| 8 | What the sanitiser removed (`sanitize_html` returning a removal summary) | OC-31 | django-backend-dev (`apps.cms.html`) |

## Implementation tasks

**admin-panel-dev**

| Priority | Task | Findings / tokens |
|---|---|---|
| Before the next ops UAT | User-triggered requests always report errors; busy state on every action | OC-01 |
| Before the next ops UAT | Deposit confirmation with the amount and cash in hand | OC-17; `ops.target.min` |
| Before the next ops UAT | Refund confirm step, correct limit text, allowance (after API #1), required reason, no form for COD | OC-11 |
| Before the next ops UAT | COD lift through `lift_cod_block` with its permission; confirmation pages for block / unblock / COD; detail-page actions | OC-23, OC-24 |
| Before the next ops UAT | App configuration confirmation (maintenance on, minimum version up) | OC-30 |
| Current phase | Drawer sidebar below 1280 px, narrower board columns, one-column dispatch and cash below 1280 px, sticky action column, `.ops-touch` on store screens | OC-04; `ops.target.*` |
| Current phase | Stale banner on dispatch, task, cash and dashboard; dashboard poll moved off the form; "Updated" times | OC-05, OC-09 |
| Current phase | Dialog focus trap and return; focus restore after swaps (or idiomorph); pagination focus | OC-03 (closes PC-09, PC-12) |
| Current phase | Persistent error toasts | OC-02 |
| Current phase | Live label and admin-arrow colours from the ops tokens | OC-06; `ops.tone.success.text`, `ops.tone.warning.text`, `ops.color.text.secondary` |
| Current phase | Session-end banner and in-place sign-in overlay (after API #2) | OC-07 |
| Current phase | Order page action bar and delivery section; per-refund Retry | OC-12, OC-13 |
| Current phase | Task panel poll pause while a form is open; stable candidate order | OC-15 |
| Current phase | Mark paid confirmation; payout batch preview (after API #3) | OC-18 |
| Current phase | Return confirmation with counts; steppers | OC-19 |
| Current phase | KYC review page per rider | OC-21 |
| Current phase | Canned reply insert; thread polling and concurrency warning (after API #4); confirm on close; one-time token on support forms | OC-25, OC-26, OC-27 |
| Current phase | CMS preview and removal message (after API #8) | OC-31 |
| Later | Rider map and trip path | OC-14 |
| Later | Low findings | OC-08, OC-10, OC-16, OC-20, OC-22, OC-28, OC-29 |

**django-backend-dev:** API rows 1, 3, 4, 6, 7 and 8 above.

## Questions for the PM

1. **COD lift (OC-23):** should Support be able to let a customer pay cash again, or only Super Admin and Ops (DL-61 d)? Today the admin lets Support do it without the `cod_block_lifted` audit entry.
2. **Returns at the counter:** Store Staff can't receive returns (the capability needs `delivery.dispatch_order`, Store Manager and above), but returns arrive at the packing counter where staff work (05 §1.3). Is that intended?
3. **Refund reasons (OC-11):** which reason list does Finance want for manual refunds?
4. **Maintenance (OC-30):** should turning maintenance on be blocked while deliveries are on the road, or only warned?
5. **Failed delivery outcome (OC-16):** what may the dispatcher be told about the customer's refund for each failure reason (D-10)?
6. **Payout references (OC-18):** who may correct a wrong UTR on a paid payout, and how?
7. **Ticket photos (OC-28):** are thumbnails acceptable if each page view writes an audit entry, or should photos stay click-to-open?
