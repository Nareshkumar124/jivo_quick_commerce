# Screen spec: Product detail sticky action bar (part of screen 17)

- **Status:** ready for implementation, except the tax line marked **pending decision**. Version 1, 2026-11-10.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `customer_app/lib/features/catalog/presentation/product_detail_screen.dart` (`bottomNavigationBar`, and removing the in-page `AddStepper`)
  - a new widget, for example `features/catalog/presentation/widgets/pdp_action_bar.dart`
  - `customer_app/lib/features/cart/presentation/add_stepper.dart` (reused; the pending spinner from CA-17 and the out-of-stock pill from CA-11)
  - `customer_app/lib/features/cart/presentation/cart_bar.dart` (one small option, §2)
- **Sources:** `docs/03-customer-app.md` §2.5 (tiles, ADD, out of stock) and §2.6 (product detail, stock awareness). Audit findings CA-13 (this bar), CA-11 (out-of-stock pill), CA-17 (pending spinner) and CA-19 (price changes) in `design/audits/2026-11-10-customer-app.md`. Tokens are in `design/tokens/customer.tokens.json`; the token names below are its paths without the `customer.` prefix.
- **Rules:**
  - Every price, MRP and quantity cap is the server's. The bar formats amounts with `formatRupeesOrNull` and never computes one. Comparing two server strings to decide whether to show a notice (`isSameAmount`) is display logic, not money arithmetic.
  - The stepper caps at the server's `orderable_quantity` (`min(stock, max_qty_per_order)`); the app never sees exact stock.
  - **Pending decision (H-22, question 3):** whether product detail shows "MRP inclusive of all taxes". The place is reserved in §6; don't ship the line until Jivo legal answers.
- **Who sees it:** everyone on product detail once the product has loaded.

## 1. Layout

```
┌──────────────────────────────────────┐
│ AppBar                     [search]  │
│ gallery, name, pack-size chips,      │
│ price block (§6), highlights,        │
│ description, label info, nutrition,  │
│ similar products …   (scrolls)       │
├──────────────────────────────────────┤
│ [notice row: price updated] (§4)     │  only when needed
│ 1 L ▾            ┌────────────────┐  │  PDP ACTION BAR, min 72 dp
│ ₹249  ₹299       │   −   2   +    │  │  stepper 160 × 48 dp
│ Only 2 left      └────────────────┘  │  hint line (§3)
├──────────────────────────────────────┤
│ [🛍 2 items · ₹498        View cart ›]│  cart bar (unchanged), when not empty
└──────────────────────────────────────┘
```

- **The bar is always visible** while the product is shown, so the customer can add from anywhere on the page.
- **One ADD per screen:** remove the in-page `AddStepper` (`product_detail_screen.dart:231`). The in-page price block stays (§6).

## 2. Bar anatomy

| Part | Spec |
|---|---|
| Container | `surface.base`, a 1 dp top border in `outline.decorative` (decorative only) plus `Material` elevation 3; padding 12 dp vertical, 16 dp horizontal; min height **72 dp** (`size.pdpActionBar`); no fixed height |
| Left column (`Expanded`) | Line A: the pack size. Line B: the price. Line C: the hint (§3), when there is one |
| Line A: pack size | One variant: plain text "1 L" (`labelLarge`, `text.secondary`, 8.91:1). Several variants: a 48 dp `TextButton` "1 L ▾" that scrolls the page to the pack-size chips (`Scrollable.ensureVisible`) |
| Line B: price | Selling price `titleMedium` 16 sp / 700 (`text.primary`, 16.22:1), then the struck MRP `bodySmall` (`text.secondary`, line-through) when the server's values differ (the existing `PriceLine`). Screen reader: "Price ₹249, MRP ₹299". |
| Right | The action slot, 160 dp wide (`size.pdpStepperWidth`) and 48 dp high (§3) |
| With the cart bar | The PDP's `bottomNavigationBar` becomes a `Column(mainAxisSize: min)`: this bar, then `CartBar`. Wrap both in one `SafeArea(top: false)`, and give `CartBar` an option to skip its own `SafeArea` here, so the bottom inset isn't added twice. |
| Height cap | The whole bottom area (notice row, bar and cart bar) is at most 50% of the screen height. Inside the cap, the bar's content scrolls, and the action slot always stays visible. |

## 3. States

The bar always shows the **selected** variant (the pack-size chip in the body). Its data comes from the newest server answer: the cart line for this variant (`cart.lineFor(variant.id)?.variant`) when the cart has one, otherwise the product detail (see §4).

| State | Action slot (right) | Hint line C (left) | Notes |
|---|---|---|---|
| **Loading** (product not loaded yet) | static skeleton 160 × 48 dp | skeleton | The bar shows as a 72 dp skeleton (`surface.highest`) so the page doesn't jump when it arrives. No shimmer. |
| **Product error / not found** | no bar | n/a | Only the cart bar shows, as today |
| **In stock, not in the cart** | **ADD** (`AddButton`: outlined, `brand.primary` label and border, 5.81:1 on `surface.card`, 6.08:1 on `surface.base`) | "Only {n} left" when the server says `LOW_STOCK` (`stock.lowFg`, 6.12:1, `labelMedium` / 600) | |
| **In the cart** | `QuantityStepper` with the quantity of this variant (`brand.primary` fill, `brand.onPrimary` 6.42:1) | as above | |
| **Change in flight > 300 ms** (CA-17) | the quantity (or the "ADD" label) is replaced by a 16 dp spinner; the slot keeps its size | unchanged | `Semantics(label: 'Updating quantity', liveRegion: true)`; `motion.pendingSpinnerDelay` |
| **At the cap** (quantity = `orderable_quantity`) | stepper as usual; + stays enabled | **"Only {n} available"** when `orderable_quantity < max_qty_per_order` (stock is the limit), otherwise **"Limit {n} per order"**. `text.secondary`, `labelMedium` / 600, icon `info_outline` 16 dp | Tapping + at the cap: a light haptic, the existing message ("You can add up to {n} of this item") in the hint line as a live region (not a snackbar, which would cover the bar), for 4 s |
| **Selected variant out of stock, not in the cart** | the out-of-stock pill (CA-11): 48 dp, `stock.outBg` with "**Out of stock**" in `stock.outFg` (13.27:1), icon `remove_shopping_cart` | when another variant is in stock: a 48 dp `TextButton` "Other pack sizes available" that scrolls to the chips | The price stays at full contrast |
| **All variants out of stock** | the out-of-stock pill | none | |
| **In the cart, but now out of stock** (stock dropped after adding) | stepper; − works; + shows the server's error message in the hint line | "**Out of stock now.** Check your cart." in `danger.fg` (6.12:1), icon `error_outline` | The cart screen flags the line with its fix, as today |
| **Cart not available in this build** (staging and prod until S3-B) | the existing "Cart coming soon" label (`text.secondary`) | none | |
| **Store closed** | unchanged (adding is allowed; checkout is blocked in the cart) | none | Add the existing `StoreClosedBanner` at the top of the page body, as the product list does |
| **Offline or a failed change** | unchanged | none | The existing error snackbar (`runCartChange`), shown above the bottom area |

- **Not colour alone:** "Out of stock", "Only 2 left", the cap and the price change are all words with an icon.
- **Low stock and the cap at once:** show the cap message (it is the more specific one).

## 4. Price-changed state

The product page can be several minutes old when the customer taps ADD or +. The cart's answer carries the variant's current price (`CartLine.variant.selling_price`).

- **Trigger:** after a cart change for the selected variant, when `isSameAmount(line.variant.sellingPrice, pageVariant.sellingPrice)` is false. Also when a quiet re-read of the product (below) returns a different price than the one on screen.
- **Notice row** directly above the bar (part of the bottom area): background `warning.tint` #FFF4D6, text `text.primary` (15.62:1), icon `info` in `warning.fg` (5.78:1), 12 dp padding, a close button (48 dp, tooltip "Dismiss"):
  - "**Price updated:** now ₹265 (was ₹249)." Both amounts are server strings: "now" from the cart line, "was" from the page.
  - `Semantics(liveRegion: true)`, announced once.
- **What else happens:** the bar's price line switches to the cart line's price at once; the page re-reads the product quietly (`ref.invalidate(productDetailProvider(slug))`, keeping the content while it loads), so the in-page price block matches.
- **When it goes away:** the close button, leaving the page, or selecting another pack size.
- **The same rule for the cap:** when the cart line's `orderable_quantity` differs from the page's, the bar uses the cart line's value silently (no notice).

## 5. Text scaling

| Text scale | Layout |
|---|---|
| Up to 1.3× | One row, as in §1. Line B wraps the MRP onto a second line if needed (the existing `Wrap` in `PriceLine`). |
| From 1.5× (`textScale.singleColumnFrom`) | Stacked: the left column on top (full width), then the action slot **full width**, 48 dp high (or taller if its label needs it). The notice row text is limited to 3 lines, with the full text in the semantics. |
| 2.0× on 360×640 | The stacked bar is about 180 dp and the cart bar about 100 dp: about 44% of the height, inside the 50% cap. With the notice row as well, the bar's content scrolls inside the cap and the action slot stays visible. |

## 6. In-page price block (body)

- Keep: the price and struck MRP (`PriceLine large: true`), the discount badge, the unit price ("₹24.90/100 ml"), "You save ₹50" (`success.fg`, 7.46:1) and "Only 2 left".
- Remove: the in-page `AddStepper` (the bar replaces it).
- **Pending decision (H-22, question 3):** under the price, "MRP inclusive of all taxes" (`bodySmall`, `text.secondary`). Reserve the line in the layout, behind a flag that stays off until Jivo legal answers.

## 7. Copy (new strings; suggested ARB keys)

| Key | Text |
|---|---|
| `pdpLimitPerOrder` | Limit {count} per order |
| `pdpOtherPackSizes` | Other pack sizes available |
| `pdpOutOfStockNow` | Out of stock now. Check your cart. |
| `pdpPriceUpdated` | Price updated: now {now} (was {was}). |
| `pdpPackSizeButtonSemantics` | Pack size {name}. Change pack size. |
| `pdpPriceUnavailable` | Price not available right now. |
| `dismiss` | Dismiss |
| `mrpInclusiveOfTaxes` (pending decision) | MRP inclusive of all taxes |

Reused: `addToCart` ("ADD"), `onlyLeft`, `onlyAvailable`, `maxQtyReached`, `outOfStock`, `cartComingSoonLabel`, `priceSemantics`, `mrpSemantics`, `stepperIncrease` / `stepperDecrease` / `stepperQuantity`.

## 8. Content rules

- **Pack size label:** 1 line, ellipsized after about 16 characters ("500 ml × 2 (pack of 2)" → "500 ml × 2 (pac…"); the full name is in the semantics.
- **Amounts:** `formatRupeesOrNull`. If the price can't be read, the price line shows "—" and the action slot shows ADD disabled with the hint "Price not available right now." (`pdpPriceUnavailable`), never "₹" alone. The hint goes away when a later read of the product (reopening the page, or the re-read in §4) brings a readable price.
- **Hindi (D-24):** "Limit 5 per order" and "Other pack sizes available" can be about 1.4× longer; line C wraps to 2 lines.

## 9. Accessibility

- **Focus order:** notice row (when shown), pack size, price, hint, action slot. The bar is one semantics container placed after the page content.
- **Touch targets:** the action slot 48 dp high (each stepper half 48 × 48 dp); the pack-size button, "Other pack sizes available" and the notice's close button 48 dp.
- **Contrast:** listed with each part above; every text pair is in the token contrast records.
- **Haptics:** a light haptic (`HapticFeedback.selectionClick`) when + is tapped at the cap; none on a normal add.

## 10. APIs required

None. Everything comes from `GET /products/{slug}/` and the cart responses (`CartLine.variant`), which the app already reads.

## 11. Acceptance checks (for the developer and QA)

- [ ] On product detail, the bar is visible at every scroll position, and the in-page ADD is gone.
- [ ] Not in the cart: ADD. In the cart: − qty +. A change slower than 300 ms shows a spinner without moving anything.
- [ ] At the server's cap, the hint says "Only N available" or "Limit N per order"; tapping + shows the message in the bar, not in a snackbar.
- [ ] An out-of-stock variant shows the "Out of stock" pill (13.27:1) and, when another pack size is in stock, "Other pack sizes available".
- [ ] After a cart change, a different server price shows "Price updated: now ₹X (was ₹Y)" and the page re-reads the product; nothing is computed.
- [ ] With the cart bar, the bottom inset is applied once, and the bottom area never exceeds 50% of the screen height.
- [ ] From 1.5× text the bar stacks with a full-width stepper; widget tests at 1.0×, 1.3× and 2.0× on 360×640 pass with no overflow.
- [ ] The tax line stays off until H-22 question 3 is answered.
