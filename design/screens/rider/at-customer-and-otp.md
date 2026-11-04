# Screen spec: Go to customer, arrived, delivery OTP (screens 11–12)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev in `task_screen.dart` (`_GoToCustomerStep`) and `at_customer_step.dart` (`_otpStep`, `_Locked`).
- **Sources:** 04 §2.6; audit RD-07, RD-08, RD-09 and RD-03; [task-step-shell.md](task-step-shell.md); tokens `rider.tokens.json`. COD collection is in [cod.md](cod.md).

## 1. Go to customer (status PICKED_UP)

```
Order JQ-1042
[Amount changed notice]   (COD only, §1.1)
┌ Customer card ────────────────────────┐
│ [pin] Priya S.          (20 sp/600)   │
│ B-204, Sector 21, Noida  (18 sp)      │
│ Landmark: Near the temple (18 sp)     │  rider.font.addressDetail
│ Note: Ring twice        (18 sp)       │
└───────────────────────────────────────┘
[COD block: Collect ₹990 in cash]  (cod.md §2, compact)
───────────────── bottom ────────────────
[ Navigate ] [ Call ]          56 dp quick row
[ ARRIVED AT CUSTOMER ]        56 dp primary
[ Not at the pin? Arrive anyway ] 56 dp (only after OUTSIDE_GEOFENCE)
          24 dp
[report] Can't deliver…        48 dp text button
```

- The Navigate and Call buttons move out of the card into the quick row (RD-07).
- **Compact COD block:** `rider.color.cod.bg`, 2 dp `rider.border.codContainer`, "Collect **₹990** in cash" at 22 sp / 700. It replaces the `tertiaryContainer` card.
- **Geofence override:** the label "Not at the pin? Arrive anyway" replaces `arrivedOverride`'s text. The sheet reasons stay as they are, with 56 dp rows.

### 1.1 Amount changed notice (COD only)

The trigger, copy and style are defined in [cod.md](cod.md) §3. The same notice appears here and at the top of the COD step.

## 2. Delivery OTP (status AT_CUSTOMER, before collection)

```
Order JQ-1042
Ask the customer for the 4-digit code     18 sp
in their app or SMS.
┌──────────────────────────────────────┐
│            _ _ _ _                   │  64 dp field, 40 sp/700, spacing 12
└──────────────────────────────────────┘
[error] Wrong code. 3 tries left. …       error line (§2.2)
───────────────── bottom ────────────────
[ Call ]                               56 dp quick row (Call only)
[ MARK DELIVERED ] / [ CONTINUE ]      56 dp primary
          24 dp
[report] Can't deliver…                48 dp
```

### 2.1 Field

| Property | Value |
|---|---|
| Height and type | 64 dp field, centred digits at 40 sp / 700, letter spacing 12 |
| Keyboard | `TextInputType.number`, digits only, max length = the server's `otp_length` |
| Focus | `autofocus: true` when the step opens |
| Suggestions | `autocorrect: false`, `enableSuggestions: false` (as today) |
| Primary | Enabled only when the length is complete. The label is "**Mark delivered**" for prepaid and "**Continue**" for COD (as today). |

### 2.2 Wrong OTP (`DELIVERY_OTP_INVALID`)

1. Clear the field, call `requestFocus()` on it, and give `HapticFeedback.mediumImpact`.
2. Error line (danger, with an icon):
   - **with `attempts_remaining`:** "**Wrong code.** {n} tries left. Ask the customer to read it again from their app or SMS." Use the ICU plural for "1 try left".
   - **without it:** "**Wrong code.** Ask the customer to read it again from their app or SMS."
3. Show the count **whenever the server sends `attempts_remaining`**. Remove the comparison with `FakeTaskBackend.maxOtpAttempts`.
4. A cash confirmation already given is kept (current behaviour). After the code is accepted the rider is not asked again.

### 2.3 No network

- Show the offline banner and the "Try again: …" label from [task-step-shell.md](task-step-shell.md) §3.
- **Keep the typed code** on a network error; clear it only on a wrong-code answer.

### 2.4 Locked (`DELIVERY_OTP_LOCKED` or `otp_locked`)

| Element | Spec |
|---|---|
| Content | `lock` icon 72 dp in `rider.color.danger`; title "**Delivery code locked**" (22 sp / 700) |
| Body with a support phone | "Too many wrong codes. Jivo support has been alerted. Call support to continue." Primary **Call support** (56 dp). |
| Body without a support phone | "Too many wrong codes. Jivo support has been alerted. **Wait at the door for a call from support**, or choose Can't deliver." No disabled button. |
| Secondary | "Can't deliver…" (shell rule) |

## 3. Acceptance checks

- [ ] Navigate and Call sit in the sticky quick row on both steps.
- [ ] The OTP field autofocuses, and a wrong code clears it, refocuses it and vibrates.
- [ ] The attempts count comes only from the server.
- [ ] A network error keeps the typed code and relabels the primary "Try again: …".
- [ ] The locked state never shows a disabled button with no alternative.
