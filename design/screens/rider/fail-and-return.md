# Screen spec: Failed delivery and return to store (screens 13–14)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev in `failed_delivery_screen.dart` and `task_screen.dart` (`_ReturnStep`, `_EndScreen`).
- **Sources:** 04 §2.6 "Failed delivery"; 08 T13 and §6.4; audit RD-11; [task-step-shell.md](task-step-shell.md); tokens `rider.tokens.json`.

## 1. Can't deliver (reason screen)

```
AppBar: Can't deliver            [← back]
Why can't you deliver this order?  18 sp
( ) Customer not reachable        64 dp rows (radio)
( ) Customer refused the order
( ) Wrong address
( ) Other reason
── when "not reachable" ─────────────────
[✓/◷] Call the customer at least 2 times (1 done)
      [ Call ]  56 dp outlined
[✓/◷] Wait at the address: 06:12 left       22 sp/700
── always ───────────────────────────────
Note (optional | required for Other)        64 dp field, 18 sp
[ Add a photo (optional) ]  56 dp outlined
───────────────── bottom ────────────────
hint: Choose a reason.
[ RETURN TO STORE ]   56 dp primary → confirm dialog
```

| Element | Spec |
|---|---|
| Reason rows | `RadioListTile`, `minTileHeight` 64 (`rider.size.listRowMin`), title 18 sp. The whole row is the target. |
| Requirement rows | Icon 28 dp: `check_circle` in `rider.color.online.bg` when done, `schedule` in `rider.color.text.secondary` while pending. The text is the state ("1 done", "You waited 10 minutes"), never colour alone. |
| Wait timer | "Wait at the address: **06:12** left" in `rider.font.waitTimer` (22 sp / 700), tabular figures. It counts from the server's arrival time (current logic). When done: "You waited 10 minutes" with `check_circle`. When not arrived: the existing "Mark 'Arrived at customer' first". |
| Timer semantics | `Semantics(label: 'Wait time left: 6 minutes 12 seconds')`, with no live region. Announce once when the wait is complete ("You can now return the order"). |
| Call button | `OutlinedButton.icon` 56 dp under the calls requirement (existing placement) |
| Note | Label "Note (optional)" or "Note (required)" (existing). Min 2 lines, 18 sp. |
| Photo | The existing flow. When added: "Photo added" with "Remove" (48 dp text button). |
| Primary | "**Return to store**"; disabled with a hint until the rules pass (existing `block` logic). The hint uses the existing strings ("Choose a reason." / "You can choose this after the calls and the 10-minute wait."). |

### 1.1 Confirmation dialog (new)

| Part | Spec |
|---|---|
| Title | "Return the order to the store?" (22 sp / 700) |
| Body | "Reason: **{reason text}**. The customer will be told. You can't undo this." (18 sp). Add "Note: {note}" when one is given (2 lines max, ellipsized). |
| Buttons | "**Go back**" (TextButton 48 dp, initial focus) and "**Yes, return to store**" (FilledButton 56 dp, `rider.color.danger` background, white text 6.46:1) |
| After Yes | The existing `fail` call. Busy shows on the dialog's Yes button; the dialog closes on the server's answer. Errors show in the screen's error line. |

## 2. Return to store (status FAILED / RETURNING)

```
AppBar: Return to store
Order JQ-1042
┌ Notice ───────────────────────────────┐  neutral.container, icon assignment_return
│ Take the items back to the store.     │  18 sp
│ Store staff will mark them received.  │
└───────────────────────────────────────┘
┌ Store card: Sector 18 store, address ─┐
───────────────── bottom ────────────────
[ Navigate ]                 56 dp quick row
[ CHECK STATUS ]             56 dp primary
```

- If the delivery was **COD**, the notice adds a line: "**Don't collect any cash.** Nothing is due for this order." (18 sp / 700). This is stated because the rider has just been at the door with a COD amount.
- Status is server-driven. When the store marks the items received, the "Items returned" end screen follows (existing).

## 3. End screens

`BlockingMessage` pattern, with an icon of 72 dp, the title at 24 sp / 700 and the body at 18 sp. The **Done** button is 56 dp, full width and bottom-pinned.

| Screen | Icon (colour) | Title | Body |
|---|---|---|---|
| Delivered | `check_circle` (`rider.color.online.bg`) | Delivered! | "You earned **₹45** for this order." (server payout) or "Great job. Wait for the next order." |
| Items returned | `assignment_return` (`rider.color.text.primary`) | Items returned | existing |
| Order cancelled | `cancel` (`rider.color.text.primary`) | Order cancelled | existing |
| Reassigned | `swap_horiz` (`rider.color.text.primary`) | Order reassigned | existing |

## 4. Acceptance checks

- [ ] Reason rows are 64 dp, and requirement states are written in words with icons.
- [ ] The wait timer is 22 sp / 700 and announces only when complete.
- [ ] "Return to store" opens the confirmation, which names the reason and starts with focus on "Go back".
- [ ] The return step shows "Don't collect any cash" for COD orders.
