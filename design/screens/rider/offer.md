# Screen spec: Incoming offer (screen 9)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev in `features/offers/presentation/offer_screen.dart`.
- **Sources:** 04 §2.4; audit RD-04 (and RD-02 for the amount format); tokens `rider.tokens.json`.
- **Rules:**
  - The countdown follows the server's `expires_at`, as the controller does today.
  - Amounts are server strings formatted with the shared `en_IN` formatter.

## 1. Layout

```
┌──────────────────────────────────────┐
│            New order                 │  headlineMedium, 28 sp
│            ( 24 s )                  │  ring 120 dp (§2)
│ [store]   Sector 18 store            │  18 sp
│ [place]   Sector 21 · 3.2 km         │  locality + distance, 18 sp
│ ┌──────────────────────────────────┐ │
│ │ [₹] Cash ₹1,240 to collect       │ │  payment block (§3)
│ └──────────────────────────────────┘ │
│ [wallet]  You earn about ₹45         │  18 sp
├──────────────────────────────────────┤
│ [ Reject ]               56 dp       │  OutlinedButton
│            16 dp                     │
│ [ ACCEPT ORDER ]         64 dp       │  FilledButton, bottom-most
└──────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Accept | `FilledButton`, height `rider.size.offerAccept` (64 dp), full width, label "**Accept order**" at 20 sp / 700, background `rider.color.online.bg` (white text 7.87:1). It is the **bottom-most** control. |
| Reject | `OutlinedButton`, 56 dp, label "Reject", border `rider.border.outlinedButton`. It sits **above** Accept with a `rider.size.gapAcceptReject` (16 dp) gap. |
| Rows | Icon 28 dp in `rider.color.text.primary` (not the primary colour, for sun legibility), text 18 sp, row min height 48 dp |
| Drop row | "{locality} · {distance}". Merging locality and distance shortens the list on small phones. |
| Gestures | No swipe-to-accept. The back button is blocked (`PopScope`). |

## 2. Countdown

| Remaining | Ring colour (stroke 10 dp) | Number | Extra |
|---|---|---|---|
| > 10 s | `rider.color.online.bg` | "24" at 36 sp / 700 | n/a |
| ≤ 10 s (`rider.motion.offerUrgentFrom`) | `rider.color.danger` | "8 s" in `rider.color.danger` (6.46:1) | `HapticFeedback.selectionClick()` once per second; announce "10 seconds left" once |
| ≤ 5 s (`rider.motion.offerExpiringFrom`) | `rider.color.danger` | "4 s" | the label "**Expiring**" (18 sp / 700, danger) under the ring; announce "5 seconds left" once |
| 0 | n/a | n/a | the existing "Offer expired" screen |

- **Ring size:** `max(rider.size.offerRing, 72 × textScale)` dp. Alternatively, clamp the number's scale at 1.5×.
- **Semantics:** the ring is `Semantics(label: 'Time left to accept: {n} seconds')` without a live region; only the two announcements above are spoken.
- **Accept in flight:** the ring freezes at its current value and Accept shows the spinner. Never expire locally while the request is running (current behaviour).

## 3. Payment block (the fact riders decide on)

| Payment | Container | Text |
|---|---|---|
| COD | background `rider.color.cod.bg`, border `rider.border.codContainer` (2 dp), 12 dp radius, 16 dp padding, icon `payments` 28 dp | "**Cash ₹1,240 to collect**" in `rider.font.offerPayment` (22 sp / 700), `rider.color.cod.text` (15.66:1) |
| Prepaid | background `rider.color.neutral.container`, no border | "**Prepaid** · nothing to collect" at 22 sp / 700 (14.76:1) |

- **Strings:** `offerCod` becomes "Cash {amount} to collect"; `offerPrepaid` becomes "Prepaid · nothing to collect".
- **Missing COD amount:** "Cash on delivery: amount shown after you accept." Never a bare "₹".

## 4. Reject sheet

- Keep the existing reasons. Each row is 56 dp (already the case).
- Add a title row "Why are you rejecting? (optional)" that is not tappable.
- **Expiry while the sheet is open:** when the phase leaves `showing`, close the sheet (`Navigator.popUntil` back to the offer route), then show the end screen. Any later choice is dropped.

## 5. Sound

On the alarm stream, play a 5–8 s looping ringtone with the existing vibration pattern. Stop it on accept, reject, expiry or withdrawal. Until the custom tone exists, the default alarm sound is acceptable.

## 6. States

| State | What shows |
|---|---|
| Showing | §1 to §3 |
| Accepting | Accept shows the spinner; Reject is disabled; the ring freezes |
| Accept error (network) | Error line "No internet. Check your connection and try again." Accept is labelled "Try again: Accept order" while time remains. |
| Accept refused: taken or expired | The existing end screens ("Order taken" / "Offer expired") with an **OK** button (56 dp) |
| Withdrawn | "Order cancelled" end screen |

## 7. Acceptance checks

- [ ] Accept is bottom-most at 64 dp, and Reject is 16 dp above it.
- [ ] The last 10 s turn red with "s" and haptics, and the last 5 s show "Expiring".
- [ ] The payment block uses the COD container, and a missing amount never shows a bare "₹".
- [ ] An open reject sheet closes when the offer expires.
