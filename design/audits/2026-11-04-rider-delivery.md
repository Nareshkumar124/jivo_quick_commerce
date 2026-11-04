# UX audit: rider app delivery flow

- **Date:** 2026-11-04 (ahead of the Phase 5 rider mini-UAT)
- **Auditor:** ui-designer
- **Scope:** online toggle and home, incoming offer, task flow (go to store → arrived → pickup code/QR → go to customer → arrived → delivery OTP → COD → delivered or failed → return), cash ledger, earnings, documents, the location disclosure and the permissions gate.
- **Build audited:** `.worktrees/rider/rider_app/lib/` (read-only), which runs against the fakes (DL-30). Also `packages/jivo_core/lib/src/theme/jivo_theme.dart` and `rider_app/lib/app/theme.dart`.
- **Method:** static review of widgets and `lib/l10n/app_en.arb` against `docs/04-rider-app.md`, the design rules (56 dp rider primary actions, WCAG AA, text scaling to 200%, no colour-only signals, server-sent money) and Google Play's prominent-disclosure requirements for background location. The app was not run, and the user's phone was not touched. The Flutter colour scheme is generated from the seed `#2E7D32` (placeholder, TODO(D-06)), so ratios for scheme roles are estimates; ratios for the proposed tokens below are computed exactly.
- **Users and context:** riders on budget Android phones mounted on a handlebar or held in one hand, outdoors in direct sun, often with gloves, hurried, and on patchy mobile data.

## Severity

| Severity | Meaning |
|---|---|
| **Blocker** | Would fail the P5 rider mini-UAT or a Play review, or risks a wrong cash collection. |
| **Major** | Causes errors or slow handling on the bike, or fails AA or the sunlight targets. |
| **Minor** | Polish, or a later-phase risk. |

**What already works well (keep it):**
- One primary action per step, pinned at the bottom (`PrimaryActionBar`, 56 dp from the rider theme).
- A full-screen offer with `PopScope(canPop: false)`.
- Server-driven step restore and the neutral "Couldn't confirm the last step" screen.
- An OTP field that is cleared after a wrong code while the cash confirmation is kept.
- Geofence errors that state the distance ("You're 340 m away").
- Pickup codes from an alphabet without look-alikes.
- A UPI QR loaded only from https.
- A cash confirmation dialog that repeats the amount.
- Ledger amounts that keep the server's sign.

---

## Top 5 fixes

| # | ID | Severity | Fix in one line |
|---|---|---|---|
| 1 | RD-01 | Blocker | The online toggle, today summary and current-task card are not built (home is a placeholder). Build them to the spec below before the P5 UAT. |
| 2 | RD-02 | Blocker | COD amounts show paise always ("₹249.00", while the customer app shows "₹249"), and a missing amount renders as "₹" with an enabled "Cash collected ₹" button. Use the shared `en_IN` formatter and block collection when the amount is missing. |
| 3 | RD-03 | Major | The COD amount can drop after the offer (store marks an item unavailable, T8a), but nothing tells the rider. Show "Amount changed" with both server values. |
| 4 | RD-04 | Major | Offer screen: Reject is the bottom-most (most reachable) button, and the countdown has no urgency change, no unit and no screen-reader label. Swap the order and add urgency cues. |
| 5 | RD-05 | Major | Sunlight legibility: secondary actions and the COD banner use low-contrast tonal colours, and ledger and helper text use 12 sp. Apply the rider high-contrast tokens below. |

---

## Findings

### A. Home and shift

#### RD-01 · Blocker (for P5 UAT) · Online toggle and home not built
- **Screen / file:** home, `features/shift/presentation/home_screen.dart`.
- **Issue:** home shows the build flavor, a placeholder sentence ("Login, shifts and order offers arrive in later phases."), the records menu and the dev tools. 04 §2.3 needs a large online/offline control, the guards, a today summary and a current-task card. This is scheduled for P5, but the UAT cannot run without it, so this spec is the target.
- **Fix (spec for flutter-rider-dev):**
  - **Layout (top to bottom):**
    1. App bar with the rider's name and a profile icon (48 dp).
    2. Status card.
    3. Today summary (2×2 grid).
    4. "Deposit cash" banner when the server sends `limit_reached`.
    5. Records list.
    6. **Bottom-pinned online control.**
  - **Online control:** a full-width button **72 dp** high at the bottom (thumb zone), not a `Switch`. A small switch is hard to hit and its state is hard to read in sun.
    | State | Label | Icon | Colours (token) | Ratio |
    |---|---|---|---|---|
    | Offline | "**Go online**" | `power_settings_new` | white on `rider.color.online.bg` #1B5E20 | 7.87:1 |
    | Going online / offline | "Going online…" plus spinner, disabled | n/a | same, at 60% | n/a |
    | Online | "**Go offline**" (outlined, 2 dp border `rider.color.text.primary`) | `power_off` | #1A1C19 on white | 17.16:1 |
  - **Status card above it, always in words:** "**You're online.** Waiting for orders near Sector 18 store." / "**You're offline.** You won't get orders." Add a coloured dot, but the words carry the state.
  - **Guard messages** (shown in the status card, each with one action button, 56 dp):
    | Guard | Copy | Action |
    |---|---|---|
    | Permissions missing | "Allow location and notifications to go online." | "Fix permissions" → gate |
    | Too far from store | "You're 3.4 km from your store. Go within 2 km to go online." (distance from the server error details) | "Navigate to store" |
    | Cash limit | "Cash in hand ₹5,200 is over your limit. You'll get **prepaid orders only** until you deposit." (both values from the server) | "See cash" |
    | Not active | "Your account isn't active yet." | "See status" |
  - **Going offline during a task** is refused. Copy: "Finish your current order first."
  - **Current task card:** if a task is active, it replaces the online control: "**Order JQ-1042 · Go to customer**" with a 56 dp "Continue" button.
  - **Today summary:** four tiles with server values only: Delivered (count), Earned (₹), Online time (h m), Cash in hand (₹). Label 14 sp, value 24 sp / 700.
  - The dev-flavor build label must stay out of staging and prod (already gated).

### B. Offer

#### RD-04 · Major · Offer buttons and countdown
- **Screen / file:** offer, `features/offers/presentation/offer_screen.dart`.
- **Issues:**
  1. In `PrimaryActionBar`, Accept sits above Reject with an 8 dp gap, both full width. For a thumb resting at the bottom edge, **Reject** is the nearest target. A rushed tap opens the reject sheet, and at worst "Reject without a reason" sits right where the thumb lands.
  2. The countdown ring and number never change: the same `primary` colour and size at 30 s and at 3 s. There is no haptic cue near the end, the number has no unit, and TalkBack hears "12" with no context.
  3. If the offer expires while the reject sheet is open, the sheet stays and the choice posts a reject for an expired offer.
  4. The ringtone is the default sound on the alarm stream. A custom loud ringtone is a P5 item.
- **Fix:**
  - **Button order:** Reject becomes a 56 dp `OutlinedButton` **above**, with 16 dp space. Accept becomes the **bottom-most** `FilledButton`, **64 dp** high and full width, labelled "**Accept order**". Do not use a swipe-to-accept. It is slower with gloves, and the 30 s window is short.
  - **Countdown:**
    - 0–20 s elapsed: ring in `rider.color.online.bg` (#1B5E20).
    - Last 10 s: ring and number switch to `rider.color.danger` (#BA1A1A, 6.46:1 on white), the number gets the suffix "s" ("8 s"), and the phone gives a light haptic each second (`HapticFeedback.selectionClick`).
    - Last 5 s: the label "**Expiring**" appears under the ring, as text and not only colour.
    - Semantics: `Semantics(label: 'Time left to accept: $seconds seconds', liveRegion: false)`. Announce only at 10 s and 5 s with `SemanticsService.announce`.
  - **Expiry:** close any open sheet (`Navigator.popUntil` on the offer route) when the phase leaves `showing`, then show the existing "Offer expired" screen.
  - **Content order** (already good, keep): store, drop locality, distance, payment, payout. Make the **payment row** the most prominent, as for COD, because it is the fact riders decide on: COD as "**Cash ₹1,240 to collect**" in 22 sp / 700 inside the COD container (RD-05). Prepaid as "Prepaid · nothing to collect".
  - **Ringtone (P5):** a 5–8 s looping tone on the alarm stream, plus the existing vibration pattern, stopped on accept, reject or expiry.

### C. Pickup

#### RD-06 · Major · Scanning should be the primary pickup action
- **Screen / file:** pickup step, `features/task/presentation/task_screen.dart` (`_PickupStep`) and `pickup_scan_screen.dart`.
- **Issues:**
  1. The primary button is "Picked up", which submits the typed code and is enabled while the field is empty. "Scan QR code" is secondary. Scanning is the faster, error-free path at the counter.
  2. The item list comes before the code field, so with the keyboard open the field and the list compete for a small screen.
  3. The scanner has no torch toggle and no viewfinder frame. Dark-store counters and night pickups are often dim.
  4. The progress chip ("Packing…" / "Ready for pickup") is a small Material chip, and its two states differ by icon and text only at chip size.
- **Fix:**
  - **When the code field is empty:** the primary button is "**Scan bag QR**" (icon `qr_code_scanner`, 56 dp), and the secondary is "Type the code" (outlined, 56 dp), which focuses the field.
  - **When 4 characters are typed:** the primary becomes "**Confirm pickup**". This is the existing `pickup(code)` call.
  - **Order of content:** status banner, then the code field, then the item list as "Check the bag: 3 items".
  - **Status banner** (full width, 56 dp tall, not a chip):
    - Packing: "**Store is packing**: wait here" with icon `hourglass_top`, #1A1C19 on `rider.color.neutral.container` #ECEFE7 (about 15:1).
    - Ready: "**Ready for pickup**" with icon `inventory_2`, white on #1B5E20 (7.87:1).
  - **Scanner:** a torch toggle (`MobileScannerController.toggleTorch`) as a 56 dp icon button with the label "Light". Add a 240 dp square viewfinder outline (3 dp, white) and the helper "Point at the QR on the bag label". Keep "Type the code instead" as is.
  - **Wrong code:** keep the copy. Also select all text in the field, so the rider can retype without deleting.

### D. Going to the customer and at the customer

#### RD-07 · Major · Navigate and Call are out of thumb reach
- **Screens / files:** go-to-store, go-to-customer and OTP steps. `_PlaceCard` and `at_customer_step.dart`.
- **Issue:** "Navigate" and "Call customer" sit inside the place card near the top of a scrolling list, the hardest area to reach one-handed on a 6.5" phone. On the move they are used more than the primary "Arrived" button. On the OTP step, "Call customer" is mid-list. The refresh icon is in the top-right corner (pull-to-refresh exists, which is fine).
- **Fix:** add a **sticky action row directly above the primary button** on the go-to-store, go-to-customer and OTP steps: two equal outlined buttons, 56 dp, 8 dp apart: [`navigation` **Navigate**] [`call` **Call**] (the store step shows only Navigate). Keep the address in the card. The landmark and instructions should be 18 sp, because riders read them at the gate.

#### RD-08 · Minor · "Can't deliver" sits right under the primary button
- **Files:** `task_screen.dart` (`_GoToCustomerStep`), `at_customer_step.dart` (`_otpStep`, `_Locked`).
- **Issue:** a `TextButton` 8 dp below "Arrived at customer" or "Continue". A mis-tap opens the fail screen. That is recoverable, but it costs time at the door.
- **Fix:** separate it by 24 dp and give it the warning icon `report` with the label "Can't deliver…" (the ellipsis signals a follow-up screen). Alternatively move it to an app bar overflow menu ("More → Can't deliver") on the OTP step only.

#### RD-09 · Major · Wrong OTP and network recovery
- **Screens / files:** OTP step (`at_customer_step.dart`), `PrimaryActionBar`, `task_text.dart`.
- **Issues:**
  1. After a wrong code, the field is cleared and the error shows in the bottom bar, but the field does not regain focus. The rider has to tap it again.
  2. The attempts line appears only when `left < FakeTaskBackend.maxOtpAttempts`, which ties the presentation to the fake's constant. In production the server's value must drive it.
  3. On no network, the error "No internet connection. Check your connection and try again." shows above an unchanged primary button. Nothing on screen says whether the step happened, and there is no persistent offline indicator.
  4. When OTP is locked and no support phone is configured, the "Call support" primary button is disabled with no alternative copy.
- **Fix:**
  - **Wrong code:** clear the field, `requestFocus()` on it, a medium haptic (`HapticFeedback.mediumImpact`), and the error as "**Wrong code.** 3 tries left. Ask the customer to read it again from their app or SMS." Show attempts left whenever the server sends `attempts_remaining`, without comparing to a client constant.
  - **Offline banner:** while connectivity is lost, show a full-width strip under the app bar on every task screen: "**No internet.** Your progress is saved on Jivo's server; tap the button again when you're back online." (#1A1C19 on #FFF4D6, 15.66:1, icon `wifi_off`). Use the existing connectivity source if there is one, or else the last request's network error.
  - **Primary label after a network error:** change it to "**Try again: Mark delivered**", so the rider knows a retry is safe. The server and the unconfirmed screen already handle duplicates.
  - **Locked with no phone:** the body reads "Too many wrong codes. Jivo support has been alerted. **Wait at the door for a call from support**, or choose Can't deliver." Hide the disabled button.
  - **Autofocus:** the OTP field gets `autofocus: true` when the step opens. The rider arrives with the phone already in hand.

### E. COD clarity

#### RD-02 · Blocker · COD amount format and missing-amount state
- **Screens / files:** offer (`offerCod`), go-to-customer COD banner, COD step (`codAmountDueLabel`, the "Cash collected ₹X" button, the confirm dialog), cash ledger and earnings. Formatter: `features/task/domain/task_rules.dart` `formatRupees`.
- **Issues:**
  1. The rider `formatRupees` keeps the fraction as sent, so `"249.00"` shows as **₹249.00**. The customer app's formatter (`customer_app/lib/shared/formatting/formatters.dart`) shows **₹249**, following 03 §4 (no decimals unless the paise are non-zero). The customer says "two forty-nine" while the rider reads "two forty-nine point zero zero". It is the same amount, but the mismatch causes doubt at the door, and the rule exists for this reason.
  2. `formatRupees(task.codAmountDue ?? '')` renders "**₹**" when the amount is missing. The primary button then reads "Cash collected ₹" and is enabled. The rider can confirm collecting an unknown amount. The server should refuse it, but only after the rider has handed back change.
- **Fix:**
  - Move one `en_IN` money formatter into `jivo_core` (owner flutter-customer-dev, additive), with the customer app's behaviour: Indian grouping, ₹, paise only when non-zero, sign preserved. The rider app uses it everywhere: offer, banner, COD step, dialog, delivered screen, ledger, earnings and payouts.
  - **Missing or unparseable `cod_amount_due` on a COD task:** do not show the COD step's cash or UPI actions. Show "**Can't load the amount to collect.** Pull down to refresh, or call support." with the primary "Refresh". Never render a bare "₹".
  - **COD step layout** (already close; adjust):
    - Label "Amount to collect" at 18 sp.
    - Amount at **48 sp / 800** (displayMedium), tabular figures.
    - Then "**Collect exactly this amount.** Don't accept more or less." at 18 sp.
    - Add a 2 dp border container in `rider.color.cod.*` (below) so the block reads as "money" at a glance.
  - **Confirm dialog:** title "Collected **₹1,240**?". Body "Count the cash before confirming. You can't change this after delivery." Buttons "Not yet" (left, text) and "**Yes, ₹1,240 collected**" (right, filled, 56 dp). Repeating the amount on the button prevents a reflex "Yes".

#### RD-03 · Major · The COD amount can change after the offer, silently
- **Screens / files:** go-to-customer banner and COD step.
- **Issue:** the offer says "Cash on delivery: collect ₹1,240". If the store then marks a unit unavailable (T8a, allowed until PACKED, which is usually after the rider accepted), the amount due drops. The task screens show the new value in the same style. Riders remember the offer amount and may ask the customer for the old figure.
- **Fix:** when the server reports a change, show a one-time notice on the go-to-customer step and at the top of the COD step: "**Amount changed: collect ₹990** (was ₹1,240). The store couldn't supply 1 item." Use `rider.color.cod` styling with the icon `info`. Both values come from the server. Comparing two server strings for display is not money arithmetic. Also send a push "Cash to collect changed to ₹990" (backend). See "APIs required".

#### RD-10 · Minor · UPI QR flow details
- **File:** `at_customer_step.dart` (`_codStep`, `_QrImage`).
- **Issues:**
  - The QR is 240 dp high. That is fine, but on a dim phone in sun the customer's scanner may fail.
  - The pending state is only "Waiting for the payment…".
  - "Customer pays cash instead" is a `TextButton` under the other actions.
- **Fix:**
  - While the QR is shown, raise screen brightness to maximum and restore it afterwards. This is a platform call (for example the `screen_brightness` package, pinned per the shared-version rule), so treat it as optional.
  - Show the amount above the QR: "Scan to pay **₹1,240**".
  - Pending: "Waiting for payment… checking every 5 s" with a small progress indicator.
  - Expired: "QR expired." with the primary button "**Show new QR**".
  - Keep "Customer pays cash instead" as an outlined 56 dp button.

### F. Failed delivery and return

#### RD-11 · Minor · "Return to store" has no confirmation
- **File:** `features/task/presentation/failed_delivery_screen.dart`.
- **Issue:** after choosing a reason, one tap ends the delivery attempt (T13), which cannot be undone. The reason selection and wait gate make an accident unlikely, but a wrong reason ("Refused" instead of "Not reachable") changes the refund and the customer's COD flag (08 §6.4).
- **Fix:** add a confirmation dialog. Title "Return the order to the store?". Body "Reason: **Customer refused the order**. The customer will be told. You can't undo this." Buttons "Go back" and "**Yes, return to store**".
  - **Wait timer:** show "Wait at the address: 06:12 left" at 22 sp / 700 with the icon `schedule`, because it is a countdown the rider glances at. The done state uses `check_circle` with the text "You waited 10 minutes", not only a colour change.

### G. Sunlight contrast and text scaling

#### RD-05 · Major · Low-contrast tonal colours and small text outdoors
- **Files:** `app/theme.dart`, `jivo_core` theme, the COD banner in `task_screen.dart` (`tertiaryContainer`), `cash_screen.dart` (`bodySmall`), `_ProgressChip`, and the document status colours.
- **Issues:**
  1. The colour scheme is generated from the placeholder seed. Outlined buttons use a 1 dp `outline` border (about #74796D, roughly 4.5:1), which washes out in sun.
  2. The COD banner is `tertiaryContainer`, a pale tone with almost no difference from the surface. Its text is readable, but the banner does not stand out as "money".
  3. Ledger time and balance lines and helper text are `bodySmall` (12 sp).
  4. The rider theme raises button height and label size but not body text.
  5. Documents: "In review" and "Approved" share the `primary` colour. The text differs, so this is not colour-only, but the "In review" icon is the same as the "needed" one.
- **Fix: rider high-contrast tokens** (proposed for `design/tokens/`, prefix `rider.`; brand hues remain TODO(D-06)):
  | Token | Value | Use | Ratio |
  |---|---|---|---|
  | `rider.color.text.primary` | #1A1C19 | all body and title text | 17.16:1 on white |
  | `rider.color.text.secondary` | #44483E | helper text (not lighter) | 9.37:1 on white |
  | `rider.color.online.bg` | #1B5E20 (= `JivoBrandColors.success`) | Go online, Ready for pickup, Accept ring | white text 7.87:1 |
  | `rider.color.cod.bg` | #FFF4D6 | COD banner, COD amount block | n/a |
  | `rider.color.cod.border` | #8A5300 (= `JivoBrandColors.warning`), 2 dp | COD container | 5.78:1 vs `cod.bg` (non-text) |
  | `rider.color.cod.text` | #1A1C19 | COD amount and copy | 15.66:1 on `cod.bg` |
  | `rider.color.danger` | #BA1A1A | errors, last 10 s of the countdown | 6.46:1 on white; 5.90:1 on `cod.bg` |
  | `rider.color.neutral.container` | #ECEFE7 | the "Store is packing" banner | text.primary about 15:1 |
  | `rider.border.outlinedButton` | 2 dp, `rider.color.text.primary` | all outlined buttons | 17.16:1 |
  - The target for primary information outdoors is **≥ 7:1** (AAA), not just 4.5:1. Every pair above except the COD border meets it for text.
  - **Text sizes in the rider theme** (`buildRiderTheme`): `bodyMedium` 16 sp, `bodyLarge` 18 sp, `bodySmall` 14 sp (never 12 sp on task, cash or earnings screens), `titleMedium` 18 sp / 600. Amounts on the ledger are 18 sp / 700.
  - **Documents:** "In review" uses the icon `hourglass_top`, "Approved" `verified` and "Rejected" `error` with the reviewer's note. The text label stays.
  - **Light theme only on task screens.** If dark mode is ever added, a sunlight-mode override keeps the light scheme while online.

#### RD-12 · Minor · Text scaling to 200%
- **Files:** `PrimaryActionBar`, the offer screen countdown, `TaskStepScaffold`.
- **Issue:** with bottom actions in `bottomNavigationBar`, a bar holding an error line, a primary button and two secondaries can exceed half the screen at 200% text. Flutter then overflows, because the bar is not scrollable. The countdown text sits in a fixed 120 dp box.
- **Fix:**
  - Wrap the bar's column in a `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * 0.5)` plus `SingleChildScrollView`, with the primary button always last and visible.
  - Above a 1.5× text scale, place the secondary actions in the scrollable body instead of the bar.
  - Countdown: size the box `max(120, 72 * textScale)` dp, or cap the number's scale at 1.5× (`MediaQuery.withClampedTextScaling`); it is already 36 sp.
  - Add a widget test per step at `textScaler: TextScaler.linear(2.0)` on a 360×640 surface (flutter-rider-dev).

### H. Location disclosure (Play User Data policy)

#### RD-13 · Major · Disclosure copy: affirmative consent and accuracy
- **Screen / file:** `features/permissions/presentation/location_disclosure_screen.dart`, with the strings `disclosure*` in `app_en.arb`.
- **What is right:**
  - The screen comes before the first location prompt, in the normal flow.
  - The body uses Play's required pattern ("collects location data to enable …, even when the app is closed or not in use").
  - It states the purposes, says collection happens only while online, and names who it is shared with.
  - "Not now" is a real decline.
- **Issues:**
  1. **Consent button.** "Continue" reads as navigation. Play requires consent through an affirmative action, and reviewers reject buttons that look like "next". Make the action explicitly about agreeing to location use.
  2. **Purpose accuracy.** "calculate your distance pay": if distance pay is computed from the store→drop distance on the server (04 §2.8 "distance pay") rather than from the GPS trail, this purpose is inaccurate. Play rejects disclosures that list purposes the app does not have. Confirm with the backend and keep this purpose only if location history feeds the pay.
  3. **The persistent notification and the off-switch** are not mentioned. They are not mandatory, but they help reviewers and riders.
  4. **The app name must match the Play listing.** "Jivo Rider" is assumed; confirm it (it is a store-listing decision, D-11).
- **Fix (proposed copy, for jivo-legal review, which the code already marks TODO):**
  - **Title:** "Jivo Rider uses your location in the background"
  - **Body:** "Jivo Rider collects location data to send you delivery offers near your store, guide you to customers, and show customers where their order is, **even when the app is closed or not in use**."
  - **Points:**
    - "Location is collected **only while you are online**. It stops as soon as you go offline."
    - "While you're online you'll see a 'You're online' notification."
    - "Your live location is shared with Jivo operations and with the customer whose order you are delivering."
    - Next step: "Next, allow location and then choose **Allow all the time**."
  - **Primary button:** "**I agree, turn on location**" (56 dp). **Secondary:** "Not now".
  - Add "calculate your distance pay" back to the body only if location history feeds the pay (point 2).
  - Keep the same screen and copy in the Play declaration video (D-11).

#### RD-14 · Minor · Permissions gate status relies on colour
- **File:** `features/permissions/presentation/permissions_gate_screen.dart` (`trailing: Text(status, style: TextStyle(color: color))`).
- **Issue:** each row's status is text, so it is not colour-only, but it has no icon, and the colours come from the scheme.
- **Fix:** add a leading icon per state: `check_circle` (done), `radio_button_unchecked` (to do) or `error` (blocked). Status text in `rider.color.text.primary` at 16 sp / 600. Row min-height 64 dp, with the whole row tappable to start that step.

### I. Earnings, cash and documents

#### RD-15 · Minor · Cash ledger readability
- **File:** `features/cash/presentation/cash_screen.dart`.
- **Issues:** each entry's time and "Balance ₹X" are 12 sp. Negative amounts are red and keep the server's minus sign (good). Deposits and collections use the same `primary` icon colour.
- **Fix:**
  - Time and balance at 14 sp in `rider.color.text.secondary`.
  - The amount at 18 sp / 700, with a word before it on narrow screens: "**+ ₹1,240** collected" / "**− ₹5,000** deposited". The sign and word come from the entry kind and the server's sign, never a calculation.
  - The deposit icon `account_balance`, the collection icon `payments`.
  - The limit banner (`errorContainer`) keeps its text. Add the icon `warning` and the action "How to deposit" (opens a short help sheet: "Hand the cash to your store manager. It shows here once they record it.").

#### RD-16 · Minor · Earnings period chips
- **File:** `features/earnings/presentation/earnings_screen.dart`.
- **Fix:** period selectors (Today / This week / Choose dates) at a 48 dp min height, with the selected state shown by a check icon as well as fill. Totals at 32 sp / 700, server values only (already done).

---

## APIs and data required

| # | Need | For | Owner |
|---|---|---|---|
| 1 | On the rider task: `cod_amount_due` is always present for COD tasks, plus `cod_amount_changed_from` (the previous amount, string) or `cod_amount_changed_at` when a T8a change happened after the offer | RD-02, RD-03 | django-backend-dev |
| 2 | A push to the assigned rider when the COD amount changes ("Cash to collect changed to ₹990") | RD-03 | django-backend-dev |
| 3 | Delivery OTP errors always include `attempts_remaining`, so the app never compares to a client constant | RD-09 | django-backend-dev (check the schema) |
| 4 | Go-online refusal details: `distance_m` and `radius_m` for "too far", and `cash_in_hand` and `cash_limit` for the limit guard | RD-01 | django-backend-dev |
| 5 | Confirmation of whether distance pay uses the GPS trail (decides the disclosure copy) | RD-13 | django-backend-dev, PM |
| 6 | Today summary on `GET /rider/me/` or a shift endpoint: delivered count, earned today, online time, cash in hand (server-computed) | RD-01 | django-backend-dev |

## Implementation tasks

**flutter-rider-dev**

| Priority | Task | Findings / tokens |
|---|---|---|
| P5, before UAT | Home: 72 dp online control, status card copy, guard messages, current-task card, today tiles | RD-01; `rider.color.online.bg`, `rider.color.text.*` |
| P5, before UAT | Use the shared `en_IN` money formatter; block COD actions when the amount is missing; COD block layout and confirm-dialog copy | RD-02; `rider.color.cod.*` |
| P5, before UAT | "Amount changed" notice | RD-03 (needs API #1) |
| P5, before UAT | Offer: Accept bottom-most at 64 dp, countdown urgency (colour, "s", haptic, "Expiring", semantics), close the sheet on expiry | RD-04; `rider.color.danger` |
| P5, before UAT | Rider theme text sizes, 2 dp outlined borders, COD container, the packing/ready banner | RD-05 |
| P5 | Pickup: scan as primary, banner, torch, viewfinder | RD-06 |
| P5 | Sticky Navigate / Call row | RD-07, RD-08 |
| P5 | Wrong OTP focus and haptic, offline banner, "Try again" label, locked copy, OTP autofocus | RD-09 |
| P5 | UPI QR details, return confirmation, wait timer styling | RD-10, RD-11 |
| P5 | 200% text tests and bar constraints | RD-12 |
| P5 | Disclosure copy (after legal review and the distance-pay answer), gate icons | RD-13, RD-14 |
| P5 | Ledger and earnings readability | RD-15, RD-16 |

**flutter-customer-dev** (owner of `jivo_core`)

- Promote the customer app's `formatRupees` to `jivo_core` (additive), so both apps share one `en_IN` rule (RD-02).
- Accept the `rider.*` and `ops.*` token proposals into `design/tokens/` and then `jivo_core` once the designer publishes the JSON.

## Questions for the P5 rider mini-UAT

1. How is the phone carried: handlebar mount, hand or pocket? Is it used with the left or the right thumb?
2. Can riders read the COD amount and the offer payment row in direct midday sun at full brightness?
3. Did anyone tap Reject by mistake, or miss an offer because of the sound?
4. At pickup, is scanning or typing the code faster at the counter?
