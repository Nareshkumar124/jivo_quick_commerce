# Screen spec: "Can't supply" dialog (packing console)

- **Status:** ready for implementation (Phase 4, before the mini-UAT). Version 1, 2026-11-04.
- **Owner:** ui-designer. **Implements:** admin-panel-dev.
- **Files to change:** `templates/ops/partials/packing_queues.html` (the trigger), a new `templates/ops/components/cant_supply_dialog.html`, `static/ops/js/orders.js` (Alpine store), `static/ops/css/ops.css`, `apps/ops_console/packing.py` (two line fields), and `apps/ops_console/forms.py` (`UnavailableForm` minimum).
- **Sources:** `docs/05` §1.3 "Item unavailable", `docs/08` T8a and §6.3, `apps/orders/store_ops.py` `mark_item_unavailable` (the unavailable count can only grow; the same value again changes nothing; nothing left cancels the order), and audit findings PC-03 and PC-04 in `design/audits/2026-11-04-packing-console.md`.
- **Tokens:** `design/tokens/ops.tokens.json`. The CSS variable names are the token paths with dots turned into dashes (`ops.target.step` → `--ops-target-step`).
- **Business rules:**
  - The page never computes money. Amounts appear only if the server provides them (§6, optional preview).
  - The only arithmetic in the page is unit counting for display and for building the posted total (`already + chosen`). The server re-validates that total.

## 1. Trigger (per pick-list line)

This replaces the inline "Unavailable [number] Update" form under every line.

| Property | Value |
|---|---|
| Element | `<button type="button" class="ops-button ops-button--secondary ops-button--cant-supply">` |
| Label | **Can't supply** |
| Icon | `remove_shopping_cart` (Material Symbols, 18 px, `aria-hidden`) |
| Size | min-height `ops.target.min` (48 px), `padding: 0 12px` |
| Placement | In the line row, after the quantity, right-aligned. Below 900 px it goes on its own row under the product. Keep at least `ops.target.gap` (8 px) from the tick hit area. |
| Shown when | `ticket.adjustable` (ACCEPTED or PACKING) **and** `line.to_pack > 0` **and** `actions.mark_unavailable` |
| Hidden when | The line is fully unavailable (the row shows "Not in this order", as in PC-04), or the order is PACKED |
| Accessible name | `aria-label="Can't supply {product_name} {variant_name}"` |
| Opens | `$store.cantSupply.ask({...line data...})`. Data comes from `data-*` attributes rendered by the server (§5). |

## 2. Dialog layout

```
┌────────────────────────────────────────────────────┐
│ Can't supply Jivo Cold Pressed Groundnut Oil?      │  title 18px/700
│ 1 L · SKU JV-GO-1L                                 │  variant 15px/500 · sku 13px
│                                                    │
│ The customer ordered 2. How many can't you supply? │  body 16px
│ (1 already marked unavailable)                     │  only if already > 0, 14px secondary
│                                                    │
│  ┌────┐ ┌────┐ ┌──────────┐                        │  radio chips 56×56 min
│  │ 1  │ │ 2  │ │ 3 (all)  │                        │
│  └────┘ └────┘ └──────────┘                        │
│                                                    │
│ ┌────────────────────────────────────────────────┐ │
│ │ Customer will get 1 of 3.                      │ │  consequence box (§4)
│ │ Paid online: the difference is refunded.       │ │
│ └────────────────────────────────────────────────┘ │
│ You can't undo this.                               │  14px/600 danger text
│                                                    │
│ [error line, role=alert]                           │  only on failure
│                                                    │
│            [ Go back ]   [ Remove 1 unit ]         │  48px · 48px
└────────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Container | The existing `.ops-dialog` / `.ops-dialog-backdrop`. `max-width: 32rem` (28rem is too narrow for the chips), `padding: 24px`, `role="alertdialog"`, `aria-modal="true"`, `aria-labelledby` = the title id, `aria-describedby` = the body id plus the consequence id |
| Title | "Can't supply **{product_name}**?" `ops.font.product` at 700 weight, `ops.color.text.primary`. **Do not truncate:** wrap the full name (unlike the 2-line clamp in the list). |
| Variant line | "{variant_name} · SKU {sku}". The variant uses `ops.font.variant` and the SKU uses `ops.font.sku` in `ops.color.text.secondary` (7.56:1). |
| Body | "The customer ordered **{quantity}**. How many can't you supply?" at 16 px. If `already > 0`, add a second line: "({already} already marked unavailable)" at 14 px, `ops.color.text.secondary`. |
| Chips | A `role="radiogroup"` with `aria-labelledby` pointing at the body question. Each chip is a native `<input type="radio" name="chosen">` inside a `<label>`, so arrow keys and screen readers work. **Values:** `1 … remaining`, where `remaining = quantity − already` (= `line.to_pack`). The last chip reads "{remaining} (all)". Size: min 56 × 56 px (`ops.target.step`), padding 0 16px, gap 8 px, wrapping. Unselected: white background, 2 px `ops.color.text.secondary` border, 20 px / 700 number. Selected: `ops.color.primary` background with `ops.color.onPrimary` text (5.54:1), plus a `check` icon before the number (not colour only). Focus: `ops.border.focus` with a 2 px offset. |
| More than 6 remaining | Instead of chips, show a stepper: [−] [number] [+], with the buttons 56 × 56 px and the number field 80 px wide, 24 px / 700, `inputmode="numeric"`, min 1, max `remaining`, starting at 1, plus an "All {remaining}" chip next to it. |
| Consequence box | `aria-live="polite"`, updates when the choice changes. Background `ops.tone.warning.badgeBg`, text `ops.tone.warning.badgeFg` (6.94:1), radius 6 px, padding 12 px, icon `info`. When the choice cancels the order, use the danger variant: white on `ops.tone.danger.badgeBg` (6.42:1) with the icon `warning`. Copy in §4. |
| Irreversible line | "You can't undo this." at 14 px / 600 in `ops.tone.danger.text` (6.42:1). Always shown. |
| Error line | Hidden until a failure. `role="alert"`, `ops.tone.danger.text`, icon `error`, 14 px. Copy in §7. |
| Buttons | Right-aligned row with a 12 px gap, buttons at least 48 px high (`ops.target.min`). **Go back** is secondary. **Primary**: `ops-button--danger` (white on `ops.tone.danger.badgeBg`, 6.42:1). Its label is in §3. Below 480 px, stack the buttons full width with Go back **below** the primary, and keep 16 px between them. |

## 3. Primary button label

The label always repeats the chosen number, so a reflex click still states what it does.

| Choice | Order still has other units? | Label | Enabled |
|---|---|---|---|
| None chosen (only possible when `remaining > 1`) | n/a | **Choose how many** | no (`aria-disabled="true"`; a click focuses the radiogroup) |
| 1 | yes | **Remove 1 unit** | yes |
| n > 1 | yes | **Remove {n} units** | yes |
| n = remaining **and** `line.would_empty_if_all_removed` | no | **Remove {n} and cancel order** | yes |
| Submitting | n/a | **Removing…** plus a spinner, `aria-busy="true"` | no, and Go back is disabled too |

- **Default selection:** when `remaining == 1`, pre-select chip 1, because there is only one possible answer. Otherwise select nothing, so staff must choose deliberately.

## 4. Consequence copy

The text depends on the payment method and on whether the choice empties the order. Without the optional preview (§6), it uses no amounts.

| Situation | Copy |
|---|---|
| Nothing chosen | "Choose how many units you can't supply." |
| Partial, ONLINE | "Customer will get **{to_pack − n} of {quantity}**. Paid online: the difference is refunded and the customer is told." |
| Partial, COD | "Customer will get **{to_pack − n} of {quantity}**. Cash on delivery: the rider collects less and the customer is told." |
| Empties the line only (n = remaining, other lines left) | "**{product_name}** will not be in this order. The customer is told." Then the ONLINE or COD sentence as above. |
| Empties the order (n = remaining and `would_empty_if_all_removed`), ONLINE | "**This cancels the whole order.** Nothing else is left to pack. Paid online: refunded in full." |
| Empties the order, COD | "**This cancels the whole order.** Nothing else is left to pack. Cash on delivery: nothing to collect." |

- `{to_pack − n}` is a units count for display (`line.to_pack` comes from the server).
- With the optional preview (§6), append the server's amounts, for example "Refund **₹249**." or "Rider collects **₹990**.", formatted `en_IN` without paise when the paise are zero.

## 5. Data the server renders on the trigger

These are `data-*` attributes from `packing.py` / `Ticket`, filled per line. None is computed in JS.

| Attribute | Meaning |
|---|---|
| `data-url` | `ops:packing-unavailable` URL for the order |
| `data-item` | line pk |
| `data-product`, `data-variant`, `data-sku` | names, escaped by the template |
| `data-quantity` | units ordered |
| `data-already` | `line.quantity_unavailable` |
| `data-to-pack` | `line.to_pack` = units still to pack (new `packing.py` field, PC-04) |
| `data-would-empty` | `"1"` if every **other** line is fully unavailable, so removing all of this line's units cancels the order (new `packing.py` field) |
| `data-payment` | `ONLINE` / `COD` |

## 6. Submit

- **Request:** `POST data-url` with `item` and `quantity_unavailable = already + chosen` (the **total**, matching `UnavailableForm` and the service). Send it with `htmx.ajax` (CSRF from `<body hx-headers>`), as the cancel dialog does.
- **Form change:** `UnavailableForm.quantity_unavailable` gets `min_value` = the line's current `quantity_unavailable` (as in audit PC-03; sending the same value again is a no-op in the service, which makes a retry after a lost response safe). The docstring loses "0 undoes". The server's refusal of a decrease stays as it is.
- **Optional preview** (an API request; the dialog ships without it): `GET …/unavailable/preview?item=&total=` returns `{grand_total, refund_amount | cod_amount_due, cancels_order}` from `compute_bill()`. When it is available, call it on each choice change (debounced 250 ms) and show its amounts in the consequence box. If it fails, fall back to the copy without amounts.
- **The dialog stays open** until the response arrives (no optimistic close).

## 7. States

| State | Behaviour |
|---|---|
| Opening | Store `cantSupply.open = true`. **Focus goes to "Go back"** (`x-ref="back"`). `opsPollAllowed` returns false while the dialog is open (add `cantSupply` beside `confirm` and `cancelOrder`). |
| Choosing | The chips or stepper update the consequence box and the primary label. |
| Submitting | The primary shows "Removing…"; both buttons are disabled; Escape and backdrop clicks are ignored. |
| Success (204 + `HX-Trigger`) | Close, then return focus to the ticket's next step button (or the ticket heading if the order was cancelled). The server toast is shown. Its copy should name the item and count, and the amounts when the service returns them, e.g. "Groundnut Oil 1 L: 1 unit removed. ₹249 refunded." `ops:refresh` re-renders the queue. When the order was cancelled, the toast reads "Order {number} cancelled: nothing left to pack." |
| Refused: order moved on (409 / `INVALID_STATE_TRANSITION`, e.g. already PACKED or cancelled by the customer) | Stay open. Error line: "**This order changed** (it's now {status}). Nothing was removed." Hide the primary, rename Go back to **Close**, and trigger `ops:refresh`. |
| Refused: validation (400, e.g. a stale `already` because another tablet marked units first) | Stay open. Error line: "Someone already updated this item. Close and check the latest count." The primary is hidden and the button reads **Close**. |
| Refused: permission (403) | Error line: "Your role can't change orders." The button reads **Close**. |
| Network error or timeout | Stay open and keep the choice. Error line: "**Not sent: check the connection.** Nothing was removed. Try again." The primary label returns to its normal text, so a retry is one click. |
| Closing without submitting | "Go back", Escape and the backdrop all close the dialog, discarding the choice (nothing was sent, so no confirmation is needed). Focus returns to the trigger. |

## 8. Keyboard and scanner

- **Tab order:** title (not focusable), radiogroup (one tab stop; arrow keys move between options), Go back, primary. Trap Tab inside the dialog.
- **Enter in the radiogroup** does **not** submit. Only an explicit activation of the primary button submits, because a scanner that ends with Enter must never confirm. Implement this with the chips outside a `<form>`, or with `@keydown.enter.prevent` on the group.
- **Escape** is the same as Go back, except while submitting.

## 9. Content rules

- **Long product names:** wrap them in full in the title (with no clamp), and keep the dialog to at most 85vh with the body scrolling. The buttons stay visible in a sticky footer.
- **Missing variant:** omit the "·" separator. **Missing SKU:** show the variant only.
- **Quantities:** plain integers. The "(all)" suffix appears only on the last chip.
- **Hindi (D-24):** labels wrap. The chips keep their numeric width, the buttons may grow to 2 lines, and the min height stays 48 px.

## 10. Contrast record (all from `ops.tokens.json`)

| Pair | Ratio |
|---|---|
| `ops.color.text.primary` on white (title) | 17.74 |
| `ops.color.text.secondary` on white (SKU, already line) | 7.56 |
| `ops.color.onPrimary` on `ops.color.primary` (selected chip) | 5.54 |
| `ops.tone.warning.badgeFg` on `ops.tone.warning.badgeBg` (consequence) | 6.94 |
| white on `ops.tone.danger.badgeBg` (cancel consequence, primary button) | 6.42 |
| `ops.tone.danger.text` on white (irreversible line, errors) | 6.42 |
| `ops.color.primary` focus ring on white (non-text) | 5.54 |
| `ops.color.text.secondary` chip border on white (non-text) | 7.56 |

## 11. Acceptance checks

- [ ] No inline number field remains under the pick-list lines.
- [ ] The dialog names the product, variant and ordered quantity. The chips run from 1 to the remaining units, and the last chip reads "(all)".
- [ ] Focus starts on Go back, and Enter in the chip group does not submit.
- [ ] The primary label repeats the number, and reads "… and cancel order" when the choice empties the order.
- [ ] "You can't undo this." is always visible.
- [ ] The POST sends the **total** (`already + chosen`), and the server refuses decreases.
- [ ] Polling pauses while the dialog is open and resumes after it closes.
- [ ] Every refusal and network error keeps the dialog open with the §7 copy, and nothing is removed twice on retry (the service ignores the same total).
- [ ] UAT-P4-06 (remove 1 of 2) and UAT-P4-07 (remove everything → order cancelled and gone from the queue) both pass through this dialog.
