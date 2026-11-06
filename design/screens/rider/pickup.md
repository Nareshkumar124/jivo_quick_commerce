# Screen spec: Go to store, arrived, pickup (screen 10)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev in `task_screen.dart` (`_GoToStoreStep`, `_PickupStep`) and `pickup_scan_screen.dart`.
- **Sources:** 04 §2.5; audit RD-06 and RD-07; the shell in [task-step-shell.md](task-step-shell.md); tokens `rider.tokens.json`.

## 1. Go to store (status ASSIGNED)

```
Order JQ-1042
┌ Store card ───────────────────────────┐
│ [store] Sector 18 store   (20 sp/600) │
│ Plot 12, Sector 18, Noida  (18 sp)    │
└───────────────────────────────────────┘
[Store status banner]  (§3)
───────────────── bottom ────────────────
[ Navigate ]                 56 dp (quick row, single button)
[ ARRIVED AT STORE ]         56 dp primary
```

- The Navigate button moves **out of the card** into the quick row (RD-07).
- The "Arrived at store" geofence error keeps its existing copy with the distance ("You're 340 m away. Move closer and try again.").

## 2. Pickup (status AT_STORE)

### Order of content
1. Store status banner (§3).
2. Code field: label "Order code", helper "Scan the QR on the bag, or type the 4-character code printed on it." 18 sp.
   - **Field:** 64 dp high, centred, 32 sp / 700 mono, letter spacing 8; uppercase; only the pickup alphabet (letters and digits, as today); max 4 characters.
3. "**Check the bag: {n} items**" (18 sp / 600), then the item rows: quantity "2 ×" at 22 sp / 700, and the name at 18 sp with the unit at 16 sp secondary. The quantities are the server's (after any unavailable units).

### Bottom actions depend on the field

| Field | Primary (56 dp) | Secondary (56 dp, outlined) |
|---|---|---|
| Empty | **Scan bag QR** (icon `qr_code_scanner`) → scanner | **Type the code** → focuses the field |
| 1–3 characters | **Scan bag QR** | n/a (keyboard open). The hint line reads "Enter all 4 characters." |
| 4 characters | **Confirm pickup** (calls `pickup(code)`) | **Scan bag QR** |
| Busy | spinner | disabled |

- **Packing state:** while the store banner says "Store is packing", the primary stays enabled. Riders may scan early, and the server answers "The order isn't packed yet. Wait until the store marks it ready." That string already exists; the hint line repeats it.
- **Wrong code:** the existing error text, plus **select all** in the field so typing replaces it, and `HapticFeedback.mediumImpact`.
- **Success:** go to the next step (the existing behaviour).

## 3. Store status banner

A full-width banner, min height 56 dp, 12 dp radius, 16 dp padding, icon 28 dp, text 18 sp / 700. It replaces `_ProgressChip`.

| Store progress | Background / text | Icon | Copy | Ratio |
|---|---|---|---|---|
| Packing | `rider.color.neutral.container` / `rider.color.text.primary` | `hourglass_top` | **Store is packing**: wait here | 14.76:1 |
| Ready | `rider.color.online.bg` / `rider.color.online.fg` | `inventory_2` | **Ready for pickup** | 7.87:1 |

- `Semantics(liveRegion: true)` so the change to "Ready" is announced (the push arrives too).

## 4. Scanner screen

```
┌──────────────────────────────────────┐
│ AppBar: Scan the bag QR code         │
│                                      │
│        ┌──────────────┐              │  viewfinder 240 dp, 3 dp white
│        │              │              │  corners only or full square
│        └──────────────┘              │
│  Point at the QR on the bag label    │  18 sp white on black scrim
├──────────────────────────────────────┤
│ [ Light ] 56 dp      (icon flashlight)│  OutlinedButton, white 2 dp border
│ [ TYPE THE CODE INSTEAD ] 56 dp      │  FilledButton
└──────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Viewfinder | `rider.size.scanViewfinder` 240 dp square, 3 dp white stroke, outside area scrimmed at black 50% |
| Helper | "Point at the QR on the bag label", white on the scrim, 18 sp (contrast well above 7:1 on the black scrim) |
| Torch | `OutlinedButton.icon` 56 dp; label "**Light**" / "**Light on**"; icon `flashlight_on` / `flashlight_off`; calls `MobileScannerController.toggleTorch()`. The state is in words, so it is not colour only. Hide the button when the device has no torch. |
| Type instead | The existing `scanTypeInstead`, 56 dp, bottom-most |
| Not a Jivo QR | The existing snackbar "This QR isn't a Jivo order code." (once per distinct value) |
| Camera unavailable | The existing message, with the "Type the code instead" button still visible |

## 5. Acceptance checks

- [ ] With an empty field the primary is "Scan bag QR"; with 4 characters it is "Confirm pickup".
- [ ] The banner replaces the chip, and both states are written in words with an icon.
- [ ] The torch toggle works and labels its state.
- [ ] A wrong code selects all text in the field.
