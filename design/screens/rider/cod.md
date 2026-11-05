# Screen spec: COD collection (screen 12, after the OTP)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev in `at_customer_step.dart` (`_codStep`, `_confirmCash`, `_QrImage`).
- **Sources:** 04 §2.6 "COD collection", §2.7; audit RD-02, RD-03 and RD-10; [task-step-shell.md](task-step-shell.md); tokens `rider.tokens.json`.
- **Rules:**
  - The amount due is the server's `cod_amount_due`, formatted with the shared `en_IN` formatter: "₹1,240", paise only when non-zero ("₹1,240.50").
  - The app never computes, compares or edits an amount. Collection is either "Cash collected" (confirmed) or a UPI payment that the server confirms. Then one `deliver` call.

## 1. Layout (cash, the default)

```
Order JQ-1042
[Amount changed notice]   (§3, only after a change)
┌ COD block ───────────────────────────┐  cod.bg, 2 dp cod.border, radius 12, padding 16
│ Amount to collect          (18 sp)   │
│ ₹1,240                     (48 sp/800)│  rider.font.codAmount, tabular
│ Collect exactly this amount.          │  18 sp/600
│ Don't accept more or less.            │
└───────────────────────────────────────┘
[✓ Cash collected: ₹1,240]  (after confirm)
[Change the delivery code]   48 dp text button
───────────────── bottom ────────────────
[ Customer pays by UPI: show QR ]  56 dp outlined
[ CASH COLLECTED ₹1,240 ]          56 dp primary  → confirm dialog
```

| Element | Spec | Contrast |
|---|---|---|
| COD block | background `rider.color.cod.bg`, border `rider.border.codContainer` | border 5.78:1 (non-text) |
| Label | "Amount to collect", 18 sp, `rider.color.text.secondary` | 8.55:1 |
| Amount | `rider.font.codAmount` 48 sp / 800, `rider.color.cod.text`, tabular figures; `Semantics(label: 'Amount to collect: 1,240 rupees')` | 15.66:1 |
| Rule line | "**Collect exactly this amount.** Don't accept more or less." 18 sp | 15.66:1 |
| Primary | "**Cash collected ₹1,240**" (`codCashCollected`). After the confirmation: "**Mark delivered**". | 7.87:1 (white on `online.bg`) |
| Secondary | "Customer pays by UPI: show QR" (outlined, 56 dp, icon `qr_code_2`). Hidden after the cash is confirmed. | 17.16:1 |

## 2. Missing or unparseable amount

- **Trigger:** `cod_amount_due` is null, empty or not a money string on a COD task.
- **Display:** the COD block shows "**Can't load the amount to collect.** Pull down to refresh, or call support." (18 sp, `rider.color.danger` icon `error`).
- **Actions:** the primary is "**Refresh**" (`controller.load`). The cash and UPI actions are **hidden**. A secondary "Call support" appears when the support phone is set.
- **Never render a bare "₹"** anywhere: not on the button, not in the block and not in the dialog.

## 3. Amount changed notice ("collect ₹X (was ₹Y)")

- **Trigger:** the task carries `cod_amount_changed_from` (the previous amount string, see API #1 in the audit) that differs from `cod_amount_due`. Comparing two server strings for display is allowed; no arithmetic is done.
- **Placement:** the notice slot of the shell, at the top of the go-to-customer step and this step.
- **Style:** `rider.color.cod.bg`, 2 dp `rider.border.codContainer`, icon `info` 28 dp. Title 20 sp / 700, body 16 sp, `rider.color.cod.text` (15.66:1).
- **Copy:**
  - **Title:** "**Amount changed: collect ₹990**"
  - **Body:** "Was ₹1,240. The store couldn't supply {n} item(s)." If the server doesn't send the item count, use "The store couldn't supply some items."
- **Visual:** inside the COD block, show the old amount above the new one, struck through at 20 sp, `rider.color.text.secondary`, with the semantics label "previously 1,240 rupees".
- **Dismissal:** the notice stays for the whole task. It has no close button, because the rider must not forget it at the door.

## 4. Cash confirmation dialog

| Part | Spec |
|---|---|
| Title | "Collected **₹1,240**?" (24 sp / 700) |
| Body | "Count the cash before confirming. You can't change this after delivery." (18 sp) |
| Buttons | "**Not yet**" (TextButton, 48 dp) on the left and "**Yes, ₹1,240 collected**" (FilledButton, 56 dp) on the right. With a large text scale, stack them with Yes on the bottom. |
| Semantics | `AlertDialog` with the title as its label. Focus starts on "Not yet". |

- **Strings:** `codConfirmTitle` becomes "Collected {amount}?", `codConfirmBody` becomes the body above, `codConfirmYes` becomes "Yes, {amount} collected" and `codConfirmNo` becomes "Not yet".
- **After Yes:** the existing flow (`_cashConfirmed = true`, then `deliver`). Show the row "✓ Cash collected: ₹1,240" with the icon `check_circle` in `rider.color.online.bg`, as text.

## 5. UPI QR

```
[COD block, compact: Scan to pay ₹1,240]   22 sp/700
┌──────────────┐
│   QR image   │   240 dp, white quiet zone 16 dp
└──────────────┘
Waiting for payment… checking every 5 s    18 sp + 16 dp progress
───────────────── bottom ────────────────
[ Check payment ]            56 dp outlined
[ Customer pays cash instead ] 56 dp outlined
[ MARK DELIVERED ] (disabled until paid)   56 dp primary
```

| QR status | Status line | Primary | Secondaries |
|---|---|---|---|
| Pending | "Waiting for payment… checking every 5 s" with a 16 dp progress indicator | "Mark delivered", disabled; the hint line reads "Waiting for the payment…" | "Check payment", "Customer pays cash instead" |
| Paid | "**Payment received**" with a `check_circle` icon, 20 sp / 700 | "**Mark delivered**", enabled | none |
| Expired | "**QR expired.**" with an `error` icon | "**Show new QR**" | "Customer pays cash instead" |
| Image unavailable (non-https or load error) | "Couldn't show the QR code. Check payment again, or collect cash." (existing) | "Check payment" | "Customer pays cash instead" |

- **Brightness (optional):** raise the screen brightness to maximum while the QR is visible and restore it when it is hidden or the app goes to the background. This needs a pinned plugin; skip it if the PM doesn't approve the dependency.
- "Customer pays cash instead" is an **outlined 56 dp** button (not a text button).
- Poll every `rider.motion.upiPoll` (5 s), as today.

## 6. States summary

| State | Primary | Notes |
|---|---|---|
| Cash, not confirmed | Cash collected ₹X | the UPI secondary is shown |
| Cash confirmed | Mark delivered | the "✓ Cash collected" row |
| UPI pending / paid / expired | see §5 | n/a |
| Amount missing | Refresh | §2 |
| Deliver refused, amount mismatch (`VALIDATION_ERROR` on deliver) | unchanged | error line `codAmountMismatch`, then `controller.load()` to show the server's current amount |
| Wrong OTP returned by deliver | n/a | back to the OTP step; the collection is kept (existing) |
| Network error | Try again: {label} | offline banner |

## 7. Acceptance checks

- [ ] The amount is 48 sp / 800 in the COD block, formatted "₹1,240" (with no ".00").
- [ ] A missing amount hides the cash and UPI actions and never shows a bare "₹".
- [ ] "Amount changed: collect ₹X" with "Was ₹Y" shows on both the go-to-customer and COD steps when the server sends the previous amount.
- [ ] The confirmation dialog repeats the amount in its title and its Yes button, and focus starts on "Not yet".
- [ ] The UPI states match §5, and "Customer pays cash instead" is a 56 dp outlined button.
