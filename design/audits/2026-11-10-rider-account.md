# UX audit: rider app account, onboarding and records screens

- **Date:** 2026-11-10
- **Auditor:** ui-designer
- **Scope:** every rider screen that is **not** the delivery flow: splash, force update (426) and maintenance; phone login and OTP; registration, KYC document upload and bank details; the application status screens; home and the online/offline control; the location disclosure and the permissions gate; earnings and payouts; cash in hand and the ledger; history and history detail; My rating; help, FAQs and tickets; legal pages; profile; the notifications inbox; and the shared widgets they use.
- **Not in scope:** the offer, pickup, delivery OTP, COD and fail/return screens. They were audited in `design/audits/2026-11-04-rider-delivery.md`. Where an earlier finding (RD-xx) touches these screens, its current status is in "Status of earlier findings" below.
- **Build audited:** `develop` f8db671 at `.worktrees/design/rider_app/lib/` (read-only). Also `packages/jivo_core/lib/src/theme/jivo_theme.dart`, `packages/jivo_core/lib/src/util/money_format.dart`, `rider_app/lib/app/theme.dart` and `rider_app/lib/l10n/app_en.arb`.
- **Method:** static review of the widgets and strings against `docs/04-rider-app.md`, `design/screens/rider/home.md`, `design/tokens/rider.tokens.json` and the design rules (56 dp rider primary actions, 48 dp minimum targets, WCAG AA, text scaling to 200%, no colour-only signals, server-sent money only). **Nothing was run:** no build, no test, no phone. Ratios for the rider tokens and for hard-coded colours are computed exactly. Ratios for Material colour roles generated from the placeholder seed `#2E7D32` (TODO(D-06)) are estimates. Overflow risks at 2.0× text are worked out from font sizes and widths on a 360×640 dp phone; each one is marked **Possibility** until a widget test confirms it.
- **Users and context:** new and active riders on budget Android phones, often with large system text, outdoors, on patchy mobile data. New riders fill long forms and photograph documents once; active riders check home, cash and earnings between orders, one-handed.

## Severity

| Severity | Meaning |
|---|---|
| **High** | Can leave a rider stuck, make them miss orders or money, or fail a Play or legal review. Fix before riders use the build. |
| **Medium** | Causes errors, confusion or slow handling, or fails WCAG AA or the text-scaling rule. Fix in the current phase if possible. |
| **Low** | Polish, consistency, or a later-phase risk. |

**What already works well (keep it):**
- Home is built to `design/screens/rider/home.md`: the 72 dp bottom-pinned online control (never a `Switch`), the status written in words with a decorative dot, the guard card as a live region, today tiles that show "–" (never 0) for an unknown value and switch to one column above 1.5× text, and the current-task card.
- The location disclosure now asks for affirmative consent ("I agree, turn on location"), mentions the "You're online" notification and leaves out distance pay (RD-13 is fixed).
- `PrimaryActionBar` never takes more than half the screen, scrolls at large text, keeps the primary button last, and shows errors with an icon in a live region (a "live region" is an area the screen reader reads out by itself when it changes).
- Document and bank numbers: readable while typing, hidden once the rider moves on, with only the masked form shown (`XXXX XXXX 1234`). Keyboard suggestions and learning are off, and the confirm field blocks paste.
- A photo taken while Android stopped the app (low memory) is recovered and goes to the right document.
- Every amount on earnings, payouts, cash and history is the server's string. The deposit banner follows the server's `deposit_required`, never a sum on the phone. Times and dates are shown in IST through one helper (`shared/format/ist_format.dart`).
- Logout is refused while online or during a task, with a clear reason.
- A 426 (update required) or 503 (maintenance) from any call moves the whole app to the update or maintenance screen through the route guard, and the forced update screen has no Back.
- Legal pages use the safe HTML reader with sensible fallbacks, and the disclosure page works offline.

## Status of earlier findings (from the 2026-11-04 audit)

| ID | Status on f8db671 | Where now |
|---|---|---|
| RD-01 (home) | **Fixed**, except the spec's "no network" row (§8) and the logout icon in the app bar | RA-10, RA-11 |
| RD-02 (money format) | **Fixed in behaviour**; the rider keeps its own copy of the formatter | RA-20 |
| RD-05 (document status icons) | **Partly open**: "In review" still has no status icon and shares the colour of "Approved" | RA-05 |
| RD-13 (disclosure copy) | **Fixed** | n/a |
| RD-14 (permissions gate) | **Partly open**: icons added, but the "Done" colour fails AA and rows are not tappable | RA-15 |
| RD-15 (cash ledger) | **Mostly fixed** (14 sp minimum, distinct icons, 18 sp / 700 amounts); the cash screen's deposit banner is still the old style | RA-17 |
| RD-16 (earnings chips) | **Fixed** (Material 3 choice chips show a check mark; padded 48 dp targets). Confirm the check mark on the phone | n/a |

---

## Top 5 fixes

| # | ID | Severity | Fix in one line |
|---|---|---|---|
| 1 | RA-10 | High | Home says "You're online. Waiting for orders" even with no internet, so riders miss orders without knowing. Show a "no internet" state on the status card and the home offline strip. |
| 2 | RA-01 | High | The force-update (426), maintenance and status screens do not scroll; at 2.0× text the only button can be pushed off a small screen. Make them scroll with the button pinned at the bottom. |
| 3 | RA-06 | Medium | "Documents under review" is a dead end: no expected time, no support, and no refresh when the rider comes back to the app. Re-check on resume and say how long it takes. |
| 4 | RA-04 | Medium | KYC upload on slow data shows only a spinner, and a rejected number gives the generic "Some details were not accepted". Show upload progress and say which field was not accepted. |
| 5 | RA-11 | Medium | Logout is one tap in the home app bar, next to Profile, with no confirmation. Move it to Profile and confirm it. |

---

## Findings

### A. Launch, update and login

#### RA-01 · High · Blocking screens do not scroll (force update, maintenance, errors)
- **Screen / file:** `features/launch/presentation/blocking_message.dart:25-49` (a `Column` with two `Spacer`s, no scrolling). It is used by the update screen (`update_screen.dart:53`), maintenance (`maintenance_screen.dart:40`), the splash error (`splash_screen.dart:53`), the static status screen (`onboarding/presentation/rider_status_screen.dart:62`), the registration placeholder (`register_placeholder_screen.dart:22`), the suspended and unknown states (`onboarding_status_screen.dart:255`, `:265`) and the documents load error (`documents_screen.dart:78`).
- **Issue:** the layout is icon (80 dp), title, body, then the buttons at the bottom, all in a fixed-height column. At 2.0× text on a 360×640 dp phone, the forced update screen needs about 650 dp (title about 116 dp, the 90-character body about 250 dp, "Update now" 56 dp, plus padding), but the safe area is about 570 dp. The column then overflows and the bottom of it, where "Update now" sits, is cut off. The maintenance screen is worse, because its body is the server's message, whose length the app does not control. On the 426 screen that button is the rider's only way forward. **Possibility** (calculated): confirm with a widget test.
- **Fix:**
  - **Recommended:** keep icon, title and body in a scrolling `ListView` (centred while it fits), and move the actions into `PrimaryActionBar` in `bottomNavigationBar`. The bar already caps its height and scrolls, and it keeps the primary button last.
    - Update (forced): primary "Update now" (56 dp). Update (optional): `secondaryAbove: true` with "Later" (outlined), so "Update now" stays the bottom-most button.
    - Maintenance: the load error goes into the bar's `error` slot (icon plus live region), and the primary is "Try again".
  - Hide the 80 dp icon above a 1.5× text scale. That saves about 100 dp.
  - **Other option:** `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight: maxHeight)` → `IntrinsicHeight` around the current column. It keeps the look but is harder to test.
  - **Tests (flutter-rider-dev):** at 360×640 with `TextScaler.linear(2.0)`, cover forced update, optional update, maintenance with a 300-character message, the splash error and the suspended status. Check that the primary button's whole rectangle is on screen.

#### RA-02 · Low · Splash error always says "Couldn't connect"
- **Screen / file:** `features/launch/presentation/splash_screen.dart:53-56`.
- **Issue:** any failure of `config/app` or `GET /me/` shows the `wifi_off` icon and the title "Couldn't connect", even when the phone is online and the server answered with a 5xx. The rider then checks their data plan for nothing.
- **Fix:** choose by error code. Network or timeout: icon `wifi_off`, title "No internet". Anything else: icon `cloud_off`, title "Couldn't load Jivo Rider". The body (`apiErrorMessage`) and "Try again" stay.

#### RA-03 · Low · Login: small consent links and silent errors
- **Screen / file:** `features/auth/presentation/phone_login_screen.dart:146-150` and `:207-240` (consent sentence with inline links), `:135-142` (server error under the field); `otp_screen.dart:158-165` (OTP error).
- **Issues:**
  1. "Terms of Use" and "Privacy Policy" are inline text links, about 20 dp tall. That is below the 48 dp target and hard to hit with a thumb.
  2. The phone and OTP errors are plain red text. They are not in a live region, so TalkBack (the Android screen reader) does not read "Wrong code. 2 attempts left." after the code is cleared.
- **Fix:**
  - Keep the sentence, and add a row of two `TextButton`s under it ("Terms of Use" · "Privacy Policy", 48 dp each) that open the same links. The inline spans can stay as extra targets.
  - Show both errors like `PrimaryActionBar` does: icon `error` in `rider.color.danger` (#BA1A1A, 6.46:1 on white), 16 sp / 600 text, wrapped in `Semantics(liveRegion: true)`.
  - Whether "By continuing, you agree…" (no checkbox) is valid consent is a legal question; see Question 1.

### B. Registration, KYC, bank details and status

#### RA-04 · Medium · KYC upload on slow data, and unclear rejections
- **Screen / file:** `features/onboarding/presentation/document_capture_screen.dart:224-243` (upload bar); `onboarding_text.dart:69-74` (`onboardingErrorText`).
- **Issues:**
  1. Each photo is up to 1 MB. On a weak 3G/2G signal one upload can take a minute. The only feedback is a spinner on the button: no percentage, no "slow connection" hint. Riders tap Back or kill the app, thinking it froze.
  2. When the server refuses a number (for example, a PAN it can't accept), the code is `VALIDATION_ERROR` and the rider sees "Some details were not accepted. Check them and try again." The screen has one photo and one number, so the rider cannot tell which is wrong.
- **Fix:**
  - **Progress:** pass `onSendProgress` from the upload call to the controller. While busy, the primary reads "**Uploading… 45%**", and a `LinearProgressIndicator` (4 dp) shows above the bar. If no progress arrives for 15 s, the hint line says "Slow connection. Keep this screen open; the upload continues." After a failure, the photo and the typed number are kept (they already are) and the primary reads "Try again: Upload" (the existing `PrimaryActionRetry` label).
  - **Field errors:** map the error's `details` keys to the app's own strings (server text is still never shown). `number` → under the number field: "Jivo couldn't accept this {document} number. Check it against the card." `image` → in the bar: "This photo wasn't accepted. Take a new photo." Use the generic text only for unknown keys. This needs the error shape confirmed (API #2).

#### RA-05 · Medium · Document tiles: squeezed at large text, and review states look alike
- **Screen / file:** `features/onboarding/presentation/documents_screen.dart:186-258` (`_DocumentTile`); string `documentsProfileIntro` (`app_en.arb:873`).
- **Issues:**
  1. Each tile is one `Row`: icon, the name column, and a trailing action word ("Upload", "Replace", "Upload again") that does not shrink. At 2.0× the action takes about 170 dp, leaving about 60 dp for "Aadhaar card: front", which then wraps to three or four letters a line. At 1.3× the name still wraps to two or three lines.
  2. "In review" and "Approved" are both in the `primary` colour. Approved gets a trailing `verified` icon, but "In review" has no status icon (RD-05 point 5). The words differ, so this is not colour only, but the states are hard to scan.
  3. The profile intro says "Upload again any document marked **Rejected**", but the label on the tile reads "**Not accepted**: upload again".
- **Fix:**
  - **Layout:** line 1 is the document name (`titleMedium`, wraps freely). Line 2 is the status with a 20 dp icon. Line 3 is the masked number, then the reviewer's note. The trailing area holds only a `chevron_right` (or nothing for approved documents). The whole card is the button, with the semantics label "Aadhaar card: front, in review. Double tap to replace."
  - **Status styles** (rider tokens; the text always stays):
    | Status | Icon | Colour | Ratio on white |
    |---|---|---|---|
    | Needed | `radio_button_unchecked` | `rider.color.text.secondary` #44483E | 9.37:1 |
    | In review | `hourglass_top` | `rider.color.text.primary` #1A1C19 | 17.16:1 |
    | Approved | `verified` | `rider.color.online.bg` #1B5E20 | 7.87:1 |
    | Not accepted | `error` | `rider.color.danger` #BA1A1A, plus the 2 dp red card border already there | 6.46:1 |
  - **Copy:** "…Upload again any document marked **Not accepted**."

#### RA-06 · Medium · "Documents under review" is a dead end
- **Screen / file:** `features/onboarding/presentation/onboarding_status_screen.dart:155-178` (in review), `:116-132` (support only on rejected); `rider_status_screen.dart:66-80` (staging and prod: `PENDING_KYC` hides "Call support" and has no "Check status").
- **Issues:**
  1. The rider is told Jivo is checking, but not how long that usually takes.
  2. The status reloads only when the rider taps "Check status" or pulls down. Coming back to the app the next morning still shows "under review" even if they were approved. Push notifications are a no-op until D-19, so nothing else tells them.
  3. There is no way to ask for help from this screen (call support appears only on the rejected state).
  4. In staging and prod builds (the static `RiderStatusScreen`), there is no refresh at all: the rider has to close and reopen the app.
- **Fix:**
  - Reload the profile when the screen opens and on every app resume (an `AppLifecycleListener`, as the permissions gate does at `permissions_gate_screen.dart:30`).
  - **Body:** "Jivo is checking your documents. This usually takes **{n} working days**. We'll show it here as soon as you're approved." `{n}` comes from the server or config (Question 2, API #1). Without it, drop that sentence.
  - Under the button, a muted line: "Last checked 11:40 AM" (IST, `rider.color.text.secondary`, 14 sp).
  - Secondary action "Call support" when `support.phone` is set (as on the rejected state).
  - In `RiderStatusScreen`, add a primary "**Check status**" (56 dp) that calls `riderAccountController.load()`.

#### RA-07 · Low · Registration: vehicle choice and long-form safety
- **Screen / file:** `features/onboarding/presentation/registration_screen.dart:399-437` (`_VehicleChoice`).
- **Issues:**
  1. The selected vehicle tile is shown by a thicker border and a fill. That works, but a quick glance in sun can miss it.
  2. The form lives only in the screen's memory. If the rider leaves to look at their RC and Android stops the app (common on budget phones), everything typed is lost. **Possibility**: needs checking on a low-RAM phone.
- **Fix:**
  - Add a 20 dp `check_circle` in the tile's top-right corner when it is selected (it is already `Semantics(selected: true)`).
  - Keep the draft (name, date of birth, emergency contact, store, vehicle) in `SharedPreferences` until the registration succeeds, and clear it then. No document numbers are in this form.

#### RA-08 · Medium · An active rider cannot change bank details
- **Screen / file:** `features/profile/presentation/profile_screen.dart:168-174` (bank row, no `onTap`); `app/route_guard.dart:85-90` (only `PENDING_KYC` and `REJECTED` riders may open the application sub-routes, which include `/rider-status/bank`).
- **Issue:** the profile shows "Saved account XXXXXXXX1234 · HDFC0001234" but offers no way to change it, and no hint about what to do. A rider who changes banks, or who typed a wrong account, has no path, and their payouts can fail.
- **Fix (until Question 3 is decided):** make the row tappable (with a chevron). It opens a bottom sheet: "To change your bank account, raise a ticket under **My account**. Payouts go to the saved account until Jivo updates it." Its action is "Raise a ticket" (56 dp), which opens `Routes.newTicket(topic: account)`. If product allows changes in the app, route to `BankDetailsScreen` instead, with the payout-hold copy product decides.

#### RA-09 · Low · Bank form gives no confirmation of the IFSC or the name rule
- **Screen / file:** `features/onboarding/presentation/bank_details_screen.dart:133-190`.
- **Issue:** a typo in a valid-looking IFSC (for example `HDFC0001243` instead of `…1234`) passes the format check and sends payouts to a wrong branch code. The holder name is prefilled with the rider's full name, but nothing says it must match the bank's records.
- **Fix:**
  - Helper under the holder name: "Exactly as in your passbook or bank app."
  - **Optional (API #4):** after 11 valid characters, show the bank and branch under the IFSC ("HDFC Bank · Sector 18, Noida") from a server lookup. If the lookup fails, show nothing and allow saving.

### C. Home and the online control

#### RA-10 · High · "You're online" while the phone has no internet
- **Screen / file:** `features/shift/presentation/online_toggle.dart:104-117` (`ShiftStatusCard`, online branch). The socket state exists (`realtime/presentation/rider_socket_providers.dart:106`, `riderSocketControllerProvider`) but home does not watch it. Home spec §8 asks for an offline strip on home; today it exists only on task screens (`task/presentation/task_screen.dart:162`, `_OfflineBanner` at `:182`).
- **Issue:** when mobile data drops, home keeps saying "**You're online.** Waiting for orders near {store}." Offers cannot reach the phone, and the rider waits for nothing. If no location reaches the server for 10 minutes, the server sets them offline, and the rider learns it only afterwards. This costs riders orders and money, and it makes the app look broken.
- **Fix:**
  - **When:** the rider is online, and the rider socket has not been `connected` for 10 s or more, or the last location upload failed with a network error. Clear it as soon as either works again. The app never changes the shift state itself; the server still decides auto-offline.
  - **Status card state** (add a row to home spec §3):
    | State | Background | Icon | Title | Body |
    |---|---|---|---|---|
    | Online, no connection | `rider.color.cod.bg` with `rider.border.codContainer` | `wifi_off` in `rider.color.cod.border` (5.78:1, non-text) | **You're online, but there's no internet** | New orders can't reach you until the connection is back. Your location is saved and sent when you're back online. |
    Text is `rider.color.cod.text` on `rider.color.cod.bg` (15.66:1). The card is already a live region, so TalkBack reads the change.
  - **Offline strip:** move `_OfflineBanner` into `shared/widgets/` with a message parameter. Show it under the home app bar with the spec §8 text: "**No internet.** You stay online; orders arrive when you're back."
  - **Test:** a widget test that flips the socket status to disconnected while online and expects the new title within 10 s (fake clock).

#### RA-11 · Medium · One-tap logout in the home app bar
- **Screen / file:** `features/shift/presentation/home_screen.dart:116` (and `:53` on the placeholder home); `features/auth/presentation/logout_button.dart:15-20` (icon button) and `:25-38` (`logoutWithFeedback`, no confirmation); `features/profile/presentation/profile_screen.dart:269-277`.
- **Issue:** the logout icon sits right next to the Profile icon. While offline, one mis-tap logs the rider out at once, and getting back in needs a new OTP (with SMS delays, and rate limits after a few tries). Home spec §1 has only the profile icon in the app bar.
- **Fix:**
  - Remove `LogoutButton` from the work home's app bar (keep the inbox bell and Profile, 48 dp each).
  - Before logging out (from Profile, and from the placeholder home, which has no Profile), show a dialog. **Title:** "Log out of Jivo Rider?" **Body:** "You'll need a new OTP to log in again." **Buttons:** "Cancel" (text, gets focus first) and "Log out" (filled, 56 dp).

#### RA-12 · Medium · "Try again" on the general guard only hides the card
- **Screen / file:** `features/shift/presentation/online_toggle.dart:354` (`HomeGuard.other => (l10n.retry, controller.dismissProblem)`).
- **Issue:** after "Location tracking couldn't start" or an unexpected server refusal, the card's button says "Try again", but it only dismisses the card. Nothing is retried, and the rider thinks the retry failed silently. The network guard (`:348-353`) does retry, so the same label behaves two ways.
- **Fix:** for `HomeGuard.other`, run `goOnlineFromHome(ref, l10n)` (as the network guard does), with a busy state on the button. Add a separate close icon button (48 dp, tooltip "Dismiss") at the card's top-right for riders who don't want to retry now.

#### RA-13 · Low · Home text at large scale and in Hindi
- **Screen / file:** `features/shift/presentation/online_toggle.dart:157-158` (status body capped at 2 lines with an ellipsis), `:830-842` (deposit banner title in a `Row` without `Expanded`).
- **Issue:** at 1.3× to 2.0×, or in Hindi (about 1.4× longer), "Waiting for orders near Sector 18 Noida Dark Store." is cut with "…". The banner title "Deposit cash" is short in English, but a longer translation has no room to wrap and would overflow.
- **Fix:** status body `maxLines: 3`, and keep the full text in the semantics label. Wrap the banner title in `Expanded`.

#### RA-14 · Medium · Staging and prod still show Phase 1 placeholder screens
- **Screen / file:** `features/shift/presentation/home_screen.dart:42-47` and `:49-81` (placeholder home with "Build: {flavor}" and `homePlaceholderBody`, `app_en.arb:17`: "Login, shifts and order offers arrive in later phases."); `features/onboarding/presentation/register_placeholder_screen.dart:11-30` (`registerBody`, `app_en.arb:242`); `rider_status_screen.dart` (no Check status, see RA-06).
- **Issue:** onboarding, the work home and the records are switched on only in the dev flavor (DL-30). That is a PM gate, not a bug. But the staging and prod builds that any tester or rider installs show developer wording ("later phases", "Build: staging"), and a new rider is told to wait for "an upcoming update". The home spec (§1, "Visibility") says the build label appears only in the dev flavor.
- **Fix:**
  - Show the build label only in the dev flavor, on both homes.
  - Before the PM opens staging to real riders, either switch these builds to the real screens or replace the copy. Proposed placeholder home text: "Orders on Jivo Rider start soon. You can already see Help and My rating." Product owns the final words (Question 5).

### D. Permissions gate

#### RA-15 · Medium · Gate rows: "Done" fails AA, the status squeezes the title, and rows are not tappable
- **Screen / file:** `features/permissions/presentation/permissions_gate_screen.dart:243-255` (`_GateRow`); OEM guidance at `:162-177`.
- **Issues:**
  1. "Done" uses `Colors.green.shade700` (#388E3C) at 14 sp on white: **4.12:1**, below the 4.5:1 AA minimum for normal text. It is also the only hard-coded colour outside the rider tokens.
  2. The status is a trailing text. "Blocked: open settings" at 1.3× is about 200 dp wide, leaving about 55 dp for the title. At 2.0× it can take the whole row; `ListTile` then has no width left for the title, which is a layout error. **Possibility**: confirm with a widget test.
  3. Rows are not tappable (RD-14 asked for the whole row to start its step). Only the bottom button works, so a rider who wants to fix notifications first cannot.
  4. The OEM auto-start texts are still marked `TODO(P5)` placeholders.
- **Fix:**
  - Status moves under the title as the subtitle: icon (20 dp) plus words, 16 sp / 600 in `rider.color.text.primary` (17.16:1). The leading 32 dp icon keeps its shape per state: `check_circle` in `rider.color.online.bg` #1B5E20 (7.87:1), `block` in `rider.color.danger` (6.46:1), `radio_button_unchecked` in `rider.color.text.secondary` (9.37:1). No trailing text.
  - `minTileHeight: 64` (`rider.size.listRowMin`) and `onTap` that fixes that item (the same call the bottom button makes for `next`). Done rows have no tap action.
  - Verify the OEM texts on the real-device matrix (QA, 10 §4) before the Play submission.

### E. Earnings, payouts, cash and history

#### RA-16 · Medium · Label-and-value rows can overflow at 2.0× text
- **Screen / file:** `features/history/presentation/history_detail_screen.dart:107-117` (time rows), and the same pattern in `features/earnings/presentation/earnings_screen.dart:274-287` (`_AmountRow`), `features/cash/presentation/cash_screen.dart:172-201`, `features/earnings/presentation/payouts_screen.dart:60-91` and `features/history/presentation/history_screen.dart:67-104`.
- **Issue:** each row is an `Expanded` label plus a value `Text` that does not shrink. A non-shrinking text in a `Row` takes its full one-line width. "Nov 2, 2026 11:40 AM" at 2.0× (32 sp) is about 320 dp, and the row has about 328 dp. The label then gets about 8 dp, and anything longer overflows (a red-and-yellow stripe in debug, clipped text in release). Short amounts are fine today; dates and long amounts are the risk. **Possibility**: confirm with a widget test.
- **Fix:** above a 1.5× text scale, stack the value under the label (the same switch the today tiles use at `online_toggle.dart:671`). Below that, wrap the value in `Flexible` with `textAlign: TextAlign.end`. Add 2.0× widget tests at 360×640 for history detail, earnings, cash and payouts.

#### RA-17 · Low · The cash screen's deposit banner doesn't match home
- **Screen / file:** `features/cash/presentation/cash_screen.dart:56-83` versus home's `CashLimitBanner` at `features/shift/presentation/online_toggle.dart:810-892`.
- **Issue:** on home the banner uses the COD style (`rider.color.cod.*`, `warning` icon, "How to deposit"). On the cash screen the same message is a plain `errorContainer` card with no icon and no help. The text is readable (about 13:1, estimate), but the same alert looks like two different things.
- **Fix:** extract one `DepositCashBanner` widget (COD style, `warning` icon, title 18 sp / 700, body 16 sp in `rider.color.cod.text` on `rider.color.cod.bg`, 15.66:1) and use it on both screens. On the cash screen, the sheet's "See cash ledger" button is not needed.

#### RA-18 · Low · List loading, empty and error states are bare
- **Screen / file:** `shared/widgets/paged_list_view.dart:328-359` (used by cash, history, payouts, tickets, My rating and the inbox).
- **Issue:** the first load is a centred spinner (rule 4 asks for skeleton rows). An empty list is one line of text with no icon and no next step. A failed "Load more" shows red text with no icon, outside a live region.
- **Fix:**
  - **Loading:** three static skeleton cards (no shimmer, which is heavy on budget phones), in `rider.color.neutral.container`.
  - **Empty:** a 48 dp icon, the existing text, and one action where it helps: tickets → "Raise a ticket"; history and earnings → none; inbox → none.
  - **Load-more error:** icon `error` plus text in `rider.color.danger`, in `Semantics(liveRegion: true)`.

#### RA-19 · Low · History marks every non-delivered task in red
- **Screen / file:** `features/history/presentation/history_screen.dart:75-83`.
- **Issue:** "Cancelled" (often the store or the customer cancelled before pickup) is red like "Not delivered". It reads as the rider's fault.
- **Fix:** add an icon and use calmer colours, keeping the words.
  | Status | Icon | Colour (ratio on white) |
  |---|---|---|
  | Delivered | `check_circle` | `rider.color.online.bg` (7.87:1) |
  | Cancelled | `cancel` | `rider.color.text.secondary` (9.37:1) |
  | Not delivered / Returned | `undo` | `rider.color.danger` (6.46:1) |

#### RA-20 · Low · The rider app keeps its own copy of the money formatter
- **Screen / file:** `features/task/domain/task_rules.dart:21-31` (`tryFormatRupees`, with `TODO(jivo_core)`) and `:35` (`formatRupees` falls back to the raw string); the shared formatter is `packages/jivo_core/lib/src/util/money_format.dart` (`formatRupeeAmount`), already exported by `jivo_core`.
- **Issue:** both copies follow the 03 §4 rule today, but two copies can drift apart. `formatRupees` shows a malformed server value as it was sent (for example `"1240.5.0"`), which the home spec §9 says should be "–".
- **Fix:** replace `tryFormatRupees` with `formatRupeeAmount` everywhere, and make `formatRupees` return "–" for an unparseable amount. No change to `jivo_core` is needed.

### F. My rating, help and tickets, inbox, profile, status

#### RA-21 · Medium · Rating stars are too faint, and ratings read badly aloud
- **Screen / file:** `features/rating/presentation/my_rating_screen.dart:54-66` (`_Stars`, colour #F2A100), `:153-160` (each rating row); `features/profile/presentation/profile_screen.dart:163-165` (`profileRatingValue`, "{rating} ★").
- **Issues:**
  1. #F2A100 on white is **2.13:1** (cards are slightly tinted, so a little lower). Non-text graphics need 3:1. Empty stars (outline only) are hard to tell from full ones in sun. In each rating row the stars are the only visible value.
  2. TalkBack reads the profile value "4.6 ★" as "4.6 black star".
- **Fix:**
  - Stars in `rider.color.cod.border` #8A5300 (6.33:1 on white) for full, half and empty, or keep the amber fill and give every star a 1 dp #8A5300 outline.
  - In each rating row, add the number after the stars: "**4**/5" (16 sp / 600, `rider.color.text.primary`).
  - Semantics: the summary reads "Average rating 4.6 out of 5, from 23 ratings"; the profile row reads "Rating 4.6 out of 5".

#### RA-22 · Medium · A ticket thread never shows new replies
- **Screen / file:** `features/support/presentation/ticket_screens.dart:473-527` (`_ThreadBody`: no `RefreshIndicator`, no polling), `:664-672` (photos as "Photo 1" links).
- **Issues:**
  1. Support replies appear only after the rider leaves the thread and opens it again. Push is a no-op until D-19, so nothing tells them a reply arrived. A rider waiting about a payout keeps staring at an unchanged screen.
  2. The thread opens at the top (oldest first), so in a long thread the newest reply is off screen.
  3. Photos show as "Photo 1" links that leave the app. The customer app shows thumbnails.
- **Fix:**
  - Pull to refresh on the message list. Re-read on app resume and every 30 s while the thread is open and in the foreground (stop in the background).
  - On open and after each new message, scroll to the newest message.
  - Thumbnails (64 dp, from the signed URL, with a placeholder icon when the URL has expired) that open the photo full screen. Keep the "Photo 1" semantics label.

#### RA-23 · Low · Inbox: unread state is visual only
- **Screen / file:** `features/notifications/presentation/inbox_screen.dart:66-70` (category icons), `:98-123` (bold title and 12 dp dot).
- **Issue:** unread entries differ only by weight and a dot, and TalkBack is not told which entries are unread. Rider categories (task, cash, ticket) all fall back to the generic `info_outline` icon.
- **Fix:** wrap each tile in `Semantics(label: 'Unread. {title}')` when unread. Add icons for the rider categories: task `two_wheeler`, cash `payments`, ticket `forum`, account `badge` (category names to be confirmed, API #6).

#### RA-24 · Low · Suspended and unknown-status riders have no way forward
- **Screen / file:** `features/onboarding/presentation/onboarding_status_screen.dart:252-271`; `rider_status_screen.dart:66-80`; `app/route_guard.dart:83` (Help is reachable only for ACTIVE riders).
- **Issue:** "Account suspended. Contact Jivo support to continue." shows a "Call support" button only when `config/app` has a support phone. Without one, the screen offers nothing but Logout. The unknown-status screen says "Update the app or contact support" but has no Update button.
- **Fix:** unknown status: add "Update app" (opens the store URL, as the update screen does). Suspended: always offer one contact path: the phone when set, otherwise "Raise a ticket", if product lets non-active riders open Help (Question 4).

---

## APIs and data required

| # | Need | For | Owner |
|---|---|---|---|
| 1 | The usual KYC review time (for example `kyc_review_days` on `config/app`), so the status screen can say "usually takes N working days" | RA-06 | django-backend-dev, after the PM decides the promise (Question 2) |
| 2 | `VALIDATION_ERROR` details with field keys on `rider_register`, `rider_documents_create` and `rider_bank_account_update` (for example `{"number": [...]}`, `{"image": [...]}`), so the app can point to the field | RA-04 | django-backend-dev (check the schema) |
| 3 | A push to the rider when the application status changes (approved, rejected), once the Firebase projects exist (D-19) | RA-06 | django-backend-dev |
| 4 | Optional IFSC lookup: bank and branch name for an IFSC | RA-09 | django-backend-dev (optional) |
| 5 | A rule and endpoint for an ACTIVE rider's bank change (or confirmation that it stays ticket-only) | RA-08 | django-backend-dev, PM (Question 3) |
| 6 | The list of inbox `category` values the rider app receives | RA-23 | django-backend-dev |

## Implementation tasks

**flutter-rider-dev**

| Priority | Task | Findings / tokens |
|---|---|---|
| Before riders use the build | "Online, no connection" status card state and the home offline strip (shared `OfflineBanner`) | RA-10; `rider.color.cod.*` |
| Before riders use the build | Scrollable blocking screens with actions in `PrimaryActionBar`; 2.0× tests | RA-01 |
| Before riders use the build | Status screen: reload on resume, review-time copy, "Last checked", Call support; "Check status" on the static screen | RA-06 |
| Before riders use the build | Upload progress, slow-connection hint, field-level rejection messages | RA-04 (needs API #2) |
| Before riders use the build | Logout only in Profile, with a confirmation dialog | RA-11 |
| Current phase | Guard "Try again" really retries, plus a close button | RA-12 |
| Current phase | Document tile layout and status icons; intro copy | RA-05; `rider.color.online.bg`, `rider.color.danger`, `rider.color.text.*` |
| Current phase | Permissions gate rows: status as subtitle, token colours, tappable rows | RA-15; `rider.size.listRowMin` |
| Current phase | Stacked label/value rows above 1.5×; 2.0× tests | RA-16 |
| Current phase | Rating star colour, "N/5" text, semantics | RA-21; `rider.color.cod.border` |
| Current phase | Ticket thread refresh, scroll to newest, thumbnails | RA-22 |
| Current phase | Bank row → "change via ticket" sheet | RA-08 |
| Before staging opens | Build label dev-only; placeholder copy | RA-14 |
| Later | Splash error by code; login link targets and live-region errors; vehicle check icon and draft; bank helper; home text wrap; shared deposit banner; list skeletons and empty states; history status icons; shared money formatter; inbox semantics; suspended/unknown actions | RA-02, RA-03, RA-07, RA-09, RA-13, RA-17, RA-18, RA-19, RA-20, RA-23, RA-24 |

**flutter-customer-dev** (owner of `jivo_core`)

- No `jivo_core` change is needed: RA-20 uses the existing `formatRupeeAmount`.
- The customer app has its own force-update and maintenance screens. Check them for the same 2.0× problem as RA-01 (outside this audit's scope).

## Questions for the PM

1. **Login consent (DPDP, legal):** the rider login uses "By continuing, you agree to the Terms of Use and the Privacy Policy" with no checkbox. `03 §2.2` says "consent checkbox/text". Is passive consent acceptable for riders, or does jivo-legal want an explicit checkbox? (RA-03)
2. **KYC review time:** what may the app promise ("usually within 2 working days")? Or should it say nothing? (RA-06)
3. **Bank changes for active riders:** may an ACTIVE rider change the payout account in the app? If yes, do payouts pause until ops re-verifies it? (RA-08)
4. **Help for non-active riders:** should SUSPENDED, PENDING_KYC and REJECTED riders be able to open Help and raise tickets? Today only ACTIVE riders can. (RA-24)
5. **Staging opening (DL-30):** when will staging and prod show onboarding and the work home to real riders? The placeholder copy must be replaced before then. (RA-14)
