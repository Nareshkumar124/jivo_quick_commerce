# Screen spec: Rider task-step shell (shared by screens 9–14)

- **Status:** ready for implementation (P5). Version 1, 2026-11-04. **Implements:** flutter-rider-dev.
- **Sources:** `docs/04-rider-app.md` §2.4–§2.6, audit `design/audits/2026-11-04-rider-delivery.md` (RD-04 to RD-12), tokens `design/tokens/rider.tokens.json` (the names below are its paths).
- **Code today:** `TaskStepScaffold` and `PrimaryActionBar` in `rider_app/lib/features/task/presentation/task_screen.dart` and `shared/widgets/primary_action_bar.dart`. This spec changes them; the step specs build on it:
  - [offer.md](offer.md)
  - [pickup.md](pickup.md)
  - [at-customer-and-otp.md](at-customer-and-otp.md)
  - [cod.md](cod.md)
  - [fail-and-return.md](fail-and-return.md)

## 1. Anatomy

```
┌──────────────────────────────────────┐
│ AppBar: step title          [↻ 48dp] │  title 20 sp/600; refresh stays (pull also works)
├──────────────────────────────────────┤
│ [Offline banner]  (§3, only offline) │
│ Order JQ-1042                        │  18 sp/700 (was labelLarge)
│ [notice slot: amount changed, etc.]  │
│ … step content (scrolls) …           │  16 dp gutter
├──────────────────────────────────────┤
│ [Quick row: Navigate | Call] 56 dp   │  sticky, only on steps that list it
│ [error / hint line]                  │  role: live region
│ [ PRIMARY ACTION 56 dp ]             │  FilledButton, full width
│ [secondary 56 dp] …                  │  OutlinedButton, 8 dp apart
│ [Can't deliver…]  24 dp above        │  TextButton 48 dp, icon `report`
└──────────────────────────────────────┘
```

| Part | Spec |
|---|---|
| Text | Body uses `rider.font.bodyLarge` (18 sp) and `rider.color.text.primary`; helper text uses `rider.color.text.secondary`. Nothing below `rider.font.bodySmall` (14 sp). |
| Outlined buttons | `rider.border.outlinedButton` (2 dp, 17.16:1) |
| Primary action | `rider.size.primaryAction` 56 dp, full width, label `rider.font.actionLabel` 18 sp / 600; bottom-most of the main actions |
| Quick row | Two equal `OutlinedButton.icon`s, 56 dp, 8 dp apart (`rider.size.gap`), directly above the error line. Icons `navigation` and `call`. Labels **Navigate** and **Call**. |
| Destructive or exit link | "Can't deliver…" is a `TextButton.icon` (48 dp, icon `report`), separated from the button above it by `rider.size.gapDestructive` (24 dp) |
| Bottom area height | Capped at 50% of the screen height (`ConstrainedBox` + `SingleChildScrollView`), with the primary action always visible. Above a 1.5× text scale, the secondary actions move into the scrolling body. |

## 2. Error and hint line

- One line above the primary button. On an error it is `rider.color.danger` text (6.46:1) at 18 sp with a leading `error` icon, never colour alone. On a hint it is `rider.color.text.secondary` at 16 sp.
- Wrap it in `Semantics(liveRegion: true)` so a new error is announced.
- **Copy for errors comes only from `taskErrorText` / `taskLocalErrorText`** (the single mapping place). The new or changed strings are listed in each step spec.

## 3. Offline banner (all task steps)

- **Shown when** the last request failed with a network error, or connectivity reports none. Hidden on the next successful request.
- **Style:** full width under the app bar, `rider.color.cod.bg` with the text `rider.color.cod.text` (15.66:1), 2 dp bottom border `rider.color.cod.border`, icon `wifi_off`, 16 dp padding.
- **Copy:** "**No internet.** Your progress is saved on Jivo's server; tap the button again when you're back online."
- **The primary button label after a network error** becomes "**Try again: {label}**" (for example "Try again: Mark delivered") until the next success or the next change of step. The server and the "Couldn't confirm the last step" screen already make retries safe.

## 4. Busy state

While an action runs, the primary shows a 24 dp spinner with `Semantics(label: 'Working')`, and **all** buttons in the bar are disabled, so a double tap with gloves sends nothing twice.

## 5. Text scaling and accessibility

- Test every step at `TextScaler.linear(2.0)` on 360×640 (a widget test per step).
- Focus order: app bar, banner, order number, content, quick row, error line, primary, secondaries.
- Every icon-only control has a tooltip and a semantics label.
- Haptics: `HapticFeedback.mediumImpact` on each successful step change. Errors are covered in the OTP step.
