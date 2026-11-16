# Screen spec: Home v2 (screen 14) and its components

- **Status:** ready for implementation. Version 1, 2026-11-14.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev, in:
  - `features/home/presentation/home_screen.dart`: header band, layout, "All products" grid
  - `features/home/presentation/banner_carousel.dart`: static strip and a new full-screen viewer
  - `features/catalog/presentation/widgets/product_tile.dart`: a new `ProductCard` and `productCardExtent`
  - `features/cart/presentation/add_stepper.dart`: ADD and quantity box restyle
  - `features/cart/presentation/cart_bar.dart`
  - `app/app_shell.dart`: nav bar
  - a new `features/home/presentation/home_offer_strip.dart`
- **Visual system:** `design/system/customer-theme-v2.md`. Token names drop the `customer.color.` prefix; sizes are dp, fonts sp.
- **Sources:**
  - `docs/03-customer-app.md` §2.5
  - ADR 0001 (slab prices)
  - audit findings CA-03, CA-11, CA-14, CA-15, CA-16, CA-17
  - `home-active-order-card.md`
- **Rules:**
  - **Money:** every price is the server's string, formatted by `formatRupees`. The card never adds, multiplies or compares amounts. The only logic is sorting `price_tiers` by `min_order_units` (box counts), which the app already does in `priceTierRows`.
  - **No new API fields.** Home uses `GET /home/`, `GET /products/`, `GET /cart/coupons/` and `GET /account/referral/`, which all exist today.
  - **Wording:** the app's existing strings say "boxes" (the slab table, the cart nudge), so this spec says "box". If the PM prefers "carton", change every box string in `app_en.arb` together. Never mix the two words.

## 1. Layout (360 × 640 dp)

```
┌──────────────────────────────────────┐
│▓ status bar, light icons            ▓│
│▓ ⚡ Delivery in 14 mins        (👤)  ▓│  header band (§2), gradient.header
│▓ Home · 12 Mall Road, Ludhia… ⌄     ▓│
│▓ ┌──────────────────────────────────┐▓│
│▓ │ 🔍 Search products               │▓│  white search field, 52 dp
│▓ └──────────────────────────────────┘▓│
│ ╰───────── 24 dp corners ──────────╯ │
│ [pending payment] [active order card]│  unchanged, only when needed
│ [update prompt] [store closed]       │
│ ┌──────────────────────────────┐┌─┐  │  banner strip (§3), 2:1, next one peeks
│ │ banner                       ││ │  │
│ └──────────────────────────────┘└─┘  │
│              ━ ● ●                   │
│ All products                         │  titleLarge 22 / 800
│ ┌───────────────┐ ┌───────────────┐  │
│ │   (bottle)    │ │   (bottle)    │  │  product cards (§5)
│ │ Jivo Water    │ │ Jivo Water    │  │
│ │ (12 × 1 L)Min5│ │(24 × 500 ml)… │  │
│ │ ₹90 /box      │ │ ₹125 /box     │  │
│ │ ↘ ₹80 at 250+ │ │ ↘ ₹115 at 250+│  │
│ │ [   + ADD   ] │ │ [   10  ✎   ] │  │
│ └───────────────┘ └───────────────┘  │
│ ┌───────────────┐                    │
│ │ …             │                    │
│ ┌──────────────────────────────────┐ │  offer strip (§4)
│ │ 🏷 Flat ₹90 off      [WELCOME90 ⧉]│ │
│ └──────────────────────────────────┘ │
│ (collections, Previously bought)     │  unchanged rails, new card look
├──────────────────────────────────────┤
│ [🛍 2 items · ₹1,880   (View cart ›)]│  cart bar (§7)
│  Home   Categories  Order again  You │  nav bar (§8), 68 dp
└──────────────────────────────────────┘
```

**Sliver order:**
1. Header band
2. Pending-payment banner
3. Active order card (with its "+N more" row)
4. Update prompt
5. Store-closed banner
6. Banner strip
7. "All products" title and grid
8. Offer strip
9. "Shop by category" grid, **only when the feed has 2 or more categories** (today there is one, water, so it is hidden; the Categories tab still has it)
10. Collection rails and "Previously bought" (unchanged, below)
11. 24 dp bottom padding

**The canvas is `surface.base`** (#FFF9F0). The gaps between blocks are 16 dp, with 24 dp above the section title.

**Home states that are not the feed** keep today's logic and copy, under the new header band:
- no location
- checking serviceability (`HomeSkeleton`)
- not serviceable
- serviceability error
- feed error
- empty feed

Empty and error views use the gold `FilledButton` from the theme.

## 2. Header band

| Part | Spec |
|---|---|
| Container | `gradient.header` (`brand.primaryDeep` #075C36 top-left → `brand.primary` #0B7A47 bottom-right). Bottom corners `radius.xl` 24. It extends under the status bar: top padding = `MediaQuery.paddingOf(context).top` + 8. Sides 16, bottom 16. **No fixed height**: it grows with the text. |
| Status bar | `AnnotatedRegion<SystemUiOverlayStyle>` with `SystemUiOverlayStyle.light` (white icons) and a transparent status bar colour. |
| Row 1, leading icon | 22 dp, `accent.gold`: `bolt_rounded` when the headline is "Delivery in N mins", `location_on_rounded` in every other state. `ExcludeSemantics`. Contrast: gold on the band 5.24 / 3.49 (icon, needs 3:1). |
| Row 1, headline | Today's `_HomeHeader` logic and strings (`deliveryIn`, `selectLocation`, `checkingDelivery`, `notDeliveringHere`, `storeClosedHeadline`). `headlineSmall` 24 / 800, white (8.10 / 5.40), max 2 lines. |
| Row 2, address | `{title} · {subtitle}` as today. `bodyMedium` 14 / 500, white, 1 line, ellipsis, then a 20 dp white `keyboard_arrow_down_rounded`. |
| Address button | Rows 1 and 2 together are one button (today's `home-address` InkWell, `changeLocationSemantics` hint), at least 48 dp tall, with a white ripple at 12%. |
| Account | `IconButton`, 48 × 48, `account_circle_rounded` 28 dp white, tooltip `accountTitle`. Top-right, aligned with row 1. |
| Search field | 16 dp under row 2. Full width, height `size.searchField` 52, `surface.card` white, `radius.lg` 16, `elevation.raised` 3 with `shadow`. Inside: a 24 dp `search_rounded` icon in `brand.primary` (5.40) and the hint `searchHint` in `bodyLarge` `text.secondary` (9.41). The whole field is one button that opens search (unchanged, key `home-search`). |

- **No skeleton:** the band shows "Checking delivery…" while serviceability loads.
- **Long addresses** are cut with an ellipsis at 1 line; the full address is in the switcher sheet.
- **At 2.0× text:** the headline wraps to 2 lines and the band grows. Nothing overlaps the account button: the headline column is `Expanded` and the button stays 48 dp.

## 3. Banner strip (static, swiped by hand)

| Part | Spec |
|---|---|
| Data | `feed.banners` (unchanged). Hidden when empty. |
| Pager | `PageView` with `PageController(viewportFraction: 0.9)` (`size.bannerViewport`), `padEnds: true`. Each page has 6 dp horizontal padding (a 12 dp gap), so the next banner peeks out and invites a swipe. |
| Banner | `AspectRatio(2)` (`image.bannerAspect` 2:1), `radius.lg` 16, clip, `BoxFit.cover`, decoded at layout size (`cacheWidth`, CA-15). |
| Loading / missing image | `surface.highest` box with a 32 dp `image_outlined` icon in `text.secondary`. On a load error, today's text fallback: `brand.primaryContainer` with the title in `titleLarge` `brand.onPrimaryContainer` (11.07). |
| Auto-scroll | **Off.** Remove the `Timer` and `bannerAutoScrollProvider` use (`motion.bannerAdvance` = 0). This also fixes CA-16. |
| Dots | Only with 2+ banners, 8 dp under the strip, `ExcludeSemantics`. Active: an 18 × 6 dp pill in `brand.primary`. Others: 6 × 6 dp in `outline.default`. |
| Tap | Opens the full-screen viewer (§3.1) at that banner. It no longer follows the link straight away; the viewer's button does. |
| Semantics | Button. Label `bannerSemantics(title)` ("Offer: …"), hint "Opens full screen" (new string `bannerOpenHint`). |

### 3.1 Full-screen banner viewer

- **Route:** a full-screen dialog route (`MaterialPageRoute(fullscreenDialog: true)` or `showGeneralDialog`). It needs no URL. Back or swipe-down closes it.
- **Background:** `inverse.surface` #2D322B, with light status bar icons.
- **Content:** a `PageView` of all banners, starting at the tapped one. Each image is `BoxFit.contain` inside an `InteractiveViewer` (pinch zoom, 1× to 3×).
- **Top bar:**
  - Close: an `IconButton` 48 dp with `close_rounded` in `text.onInverse` (11.54) and tooltip "Close".
  - A page counter "2 of 4" (new string `bannerPageCount`), `labelLarge` in `text.onInverse`.
- **Bottom:** only when the banner has a link. A full-width gold `FilledButton` (52 dp, 16 dp side margins, safe-area aware). Tapping it closes the viewer, then calls `openBannerLink`. The label depends on the link type (all new strings):

  | Link type | Label |
  |---|---|
  | category, collection | "Shop now" |
  | product | "View product" |
  | referral | "Invite friends" |
  | url | "Open link" (with an `open_in_new_rounded` icon) |

- **Motion:** a 200 ms fade in. With reduced motion, no animation.

## 4. Offer strip (welcome coupon or referral)

At most **one** strip, chosen in this order:

1. **Coupon strip**, from `cartCouponsProvider` (`GET /cart/coupons/`):
   - **Which coupon:** the first coupon, in the server's order, that is either eligible, or not eligible only because of `MIN_ORDER_VALUE` or `NO_ELIGIBLE_ITEMS`. Those two still apply once the cart grows. Coupons blocked by `FIRST_ORDER_ONLY` or `STORE` are skipped.
   - **Why this rule:** it shows WELCOME90 to a new customer and hides it after the first order, without the app knowing any coupon by name.
2. **Referral strip**, when no coupon qualifies and `currentReferralProvider` says `is_enabled`.
3. **Nothing** otherwise, or while loading, or on error. The strip is optional, so it has no skeleton and no error state.

| Part | Coupon strip | Referral strip |
|---|---|---|
| Background | `gradient.offer` (#FFE9A8 → #FFC24D), `radius.lg` 16 | `gradient.header` (#075C36 → #0B7A47), `radius.lg` 16 |
| Size | full width minus 16 dp gutters, min height `size.offerStrip` 72, padding 12 vertical / 16 horizontal | same |
| Leading | 40 dp white circle, `local_offer_rounded` 22 dp in `accent.onGold` | 40 dp `accent.goldLight` circle, `card_giftcard_rounded` 22 dp in `accent.onGold` |
| Title | coupon `title` ("Flat ₹90 off"), `titleMedium` 17 / 800, `accent.onGold` (11.94 / 8.94), max 2 lines | `referralTitle` ("Refer & earn"), `titleMedium` 17 / 800, white (8.10 / 5.40) |
| Line 2 | coupon `description`, `bodySmall` 12, `accent.onGold`, max 2 lines | `referralHeadline(referralRewardText(info))`, `bodySmall` 12, white, max 2 lines |
| Trailing | Code chip: white, 1.5 dp `accent.onGold` border, `radius.pill`, at least 48 dp tall. It shows the code in `labelLarge` 15 / 800 ink with letter spacing 1, plus an 18 dp `content_copy_rounded`. Tap: copies the code and shows the snackbar "Code {code} copied" (`referralCodeCopied`). Semantics: `couponCopySemantics`. | "Invite" pill (new string `homeReferralInvite`): `accent.gold`, 1 dp `accent.goldEdge`, ink `labelLarge` 15 / 800 (9.28), 48 dp tall. It opens `Routes.referral`. |
| Tap on the body | opens My coupons (`Routes.myCoupons`) | opens `Routes.referral` |

- **Contrast:**
  - Coupon strip: ink on both gradient ends 11.94 / 8.94, and ink on the white code chip 14.35.
  - Referral strip: white on both ends 8.10 / 5.40, and the gold pill's ink 9.28.
- **The code is never cut off** (codes are short). If the trailing part does not fit (at 1.5× text or more), it drops under the text, left-aligned, using a `Wrap`.
- **Each strip is a single semantics group with two actions:** the body action and the trailing action.

## 5. Product card (`ProductCard`)

Used in the Home grid, product lists, collections and search. Rails can use it too at a 160 dp width. On a 360 dp phone the card is 158 dp wide: (360 − 2 × 16 − 12) / 2.

```
┌──────────────────────────┐  surface.card white, radius 16, elevation.card 1
│ ┌──────────────────────┐ │  image well: surface.imageWell, radius 12, 128 dp tall
│ │[17% OFF]       [veg] │ │  badge top-left (gold), veg mark top-right
│ │       (bottle)       │ │  BoxFit.contain, 8 dp inset
│ │[Out of stock]        │ │  only when out of stock
│ └──────────────────────┘ │
│ Jivo Packaged Drinking   │  titleSmall 15 / 700, 2 lines
│ Water                    │
│ (12 × 1 L)  Min 5        │  pack-size pill + min hint (Wrap)
│ ₹90 /box  ₹100           │  price 22 / 800 + unit; MRP only if different
│ (↘ ₹80 at 250+ boxes)    │  bulk pill, only with slab prices
│ Only 3 left              │  only when low
│ ┌──────────────────────┐ │
│ │       + ADD          │ │  §6, 48 dp
│ └──────────────────────┘ │
└──────────────────────────┘
```

**Card:** padding 12 (`space.md`). Gaps: 8 under the image, 4 under the name, 6 under the pills row, 4 under the price, 8 above ADD.

| Part | Data (server) | Style | Content rules |
|---|---|---|---|
| Image | `variant.imageUrl ?? product.imageUrl` | well `surface.imageWell`, `radius.md` 12, height `size.productTileImage` 128, image `BoxFit.contain` with 8 dp inset, decoded at layout size | Missing or failed: today's `ProductImage` placeholder inside the well. Out of stock: image in greyscale at 50% opacity (only the image). |
| Discount badge | `discountPercent` > 0 | `discountBadge` gold / ink (9.28), `labelSmall` 11 / 700, `radius.sm` / 2, top-left 6 dp inset | Water has MRP = selling price, so it shows no badge today. |
| Veg mark | `isVeg` | unchanged, top-right 6 dp inset | |
| Name | `product.name` | `titleSmall` 15 / 700, `text.primary` (17.12) | Max 2 lines, ellipsis. The full name is in the semantics label. |
| Pack size | `variant.name` (e.g. "12 × 1 L"). With several variants, today's `variantOptions(name, count)` | pill: `brand.primaryContainer` / `brand.onPrimaryContainer` (11.07), `labelMedium` 12 / 700, 8 × 3 dp padding, `radius.pill` | 1 line, ellipsis inside the pill if longer than the card. |
| Min | `minQtyPerOrder` > 1 → `minQtyShort` ("Min 5") | `labelMedium` 12 / 600, `text.secondary` (9.41), beside the pill in a `Wrap` (6 dp spacing) | Semantics "Minimum 5 per order" (unchanged). |
| Price | `sellingPrice` → `formatRupees` | `titleLarge` 22 / 800, tabular figures, `text.primary` | One line, `FittedBox` scale-down, never ellipsis. |
| Unit | new string `perBox` "/box" | `font.priceUnit` 13 / 600, `text.secondary`, baseline-aligned with the price | Semantics: the price reads "₹90 per box" (new string `pricePerBoxSemantics`). |
| MRP | `mrp`, only when its formatted string differs from the price (today's `PriceLine` rule) | `bodySmall` 12, `text.secondary`, line-through | Semantics "MRP ₹100" (unchanged). |
| Bulk pill | `priceTiers`: sort by `minOrderUnits` (today's `priceTierRows`) and take the **last** row's `price` and `from`. Show it only with 2+ tiers and when that price string differs from the selling price string. | `accent.goldLight` / `accent.onGold` (11.94), `labelMedium` 12 / 700, 16 dp `trending_down_rounded`, `radius.pill`, 8 × 3 dp padding | New string `bulkPriceFrom`: "{price} at {count}+ boxes". All values come straight from the server. Tapping the card opens the full slab table on product detail. |
| Low stock | `lowStockUnits` → `onlyLeft` | `labelMedium` 12 / 700, `danger.fg` (6.46) | |
| Control | `AddStepper` / `_OptionsControl` | §6 | |

**Tap and semantics:**
- **Tap anywhere except the control:** opens product detail, as today.
- **Press:** the card scales to 0.97 (`motion.press`).
- **Screen reader:** one merged label, e.g. "Jivo Packaged Drinking Water, 12 × 1 L, ₹90 per box, ₹80 at 250+ boxes, minimum 5 per order, only 3 left". ADD is a separate button.

**Height:** `productCardExtent(context)` replaces `productTileExtent` for this card.
- **Formula:** fixed `236` + text `100 × scale` (name 40, pack pill 16, price 28, bulk pill 16). Add `16 × scale` when the min hint wraps under the pill, and `16 × scale` when any card in the row shows "Only N left". The fixed part covers the padding, image well, gaps, pill padding and the 48 dp control.
- **Example:** 336 dp at 1.0.
- **Verify** with widget tests at 1.0, 1.3 and 2.0 on 360 × 640: no overflow.

**Grid:** `SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200 × (scale ≥ 1.5 ? scale : 1))`, so there are two columns on phones and one column from 1.5× text (CA-14). Spacing 12 × 12, 16 dp side padding.

**"All products" data:**
- **Request:** `GET /products/` with the store header, no category, `sort=relevance` (in-stock first, admin order), `page_size=20`. Load the next page when the grid is 80% scrolled.
- **Title:** "All products" (new string `homeAllProducts`), `titleLarge` 22 / 800, as a semantics header.
- **Refresh:** pull to refresh reloads it with the feed. A failed refresh keeps the cards and shows the snackbar (CA-03).

**Card states:**

| State | Look |
|---|---|
| Loading | 4 skeleton cards: white card; image well, name bar (70%), pill bar (40%), price bar (50%) and a 48 dp control bar, all in `surface.highest`. Static, with one "Loading" announcement (today's `SkeletonSemantics`). |
| Empty (no products) | `EmptyView(message: homeEmpty)` in place of the grid. |
| Error (first load) | `ErrorRetryView` in place of the grid; the header band, banners and offer strip stay. |
| In stock | as drawn |
| In cart | the control is the green quantity box (§6) |
| Change in flight | dims at once; a spinner after 300 ms (CA-17) |
| Low stock | "Only N left" line |
| Out of stock | Image in greyscale at 50%. An "Out of stock" pill at the bottom-left of the well (`stock.outBg` / `stock.outFg`, 13.66, `labelMedium` 12 / 700). All text keeps full contrast (CA-11). The control shows `OutOfStockLabel`. The card can still be tapped. |
| Cart off (staging/prod until S3-B) | `CartComingSoonLabel` in place of ADD |
| Long name, pack size or price | 2 lines / 1-line pill / scale-down, as in the table |

## 6. ADD button and quantity box

| | ADD (not in cart) | Quantity box (in cart) |
|---|---|---|
| Widget | `AddButton`: a `FilledButton` (it gets the gold look from the theme) | `QuantityBox` (today's widget, restyled) |
| Size | full width of the card's inner area, height `size.addButton` 48, `radius.md` 12 | same |
| Fill / border | `accent.gold` #FFC83D, 1 dp `accent.goldEdge` #9E6A00 (4.65 on white) | `brand.primary` #0B7A47, no border |
| Content | 20 dp `add_rounded` + "ADD" (`addToCart`), 16 / 800, `accent.onGold` (9.28) | the quantity in `titleMedium` 17 / 800 + a 18 dp `edit_rounded`, white (5.40) |
| Pressed | ink overlay 12% + scale 0.97 | white overlay 12% + scale 0.97 |
| Focus (keyboard, switch access) | 2 dp `brand.primary` ring, 2 dp outside | 2 dp `accent.onGold` ring |
| Change in flight | whole control at 60% opacity, taps ignored; after 300 ms an 18 dp spinner in ink replaces the label, announced "Updating quantity" | same, with a white spinner |
| Switch between the two | `AnimatedSwitcher` 200 ms fade + scale (`motion.qtySwap`), none with reduced motion | |
| Semantics | unchanged: "Add {name} to cart" | unchanged: `quantityBoxLabel`, live region |

- **Behaviour is unchanged:** both still open the "Enter quantity" dialog. Only the look changes.
- **Product detail and the variant picker** use the same two looks at their own widths (160 / 128 dp).

## 7. Cart bar (restyle)

- **Container:** `brand.primaryDeep` #075C36 background, `radius.md` 12, `elevation.raised` 3 with `shadow`, min height 56. It is placed as today, above the nav bar.
- **Left side:** a 24 dp `shopping_bag_rounded` icon and the summary (today's text: item count · server item total) in `titleSmall` 15 / 700, white (8.10).
- **Right side:** a "View cart" pill (`viewCart`) with a 20 dp `chevron_right_rounded`. The pill is `accent.gold` with ink `labelLarge` 15 / 800 (9.28), `radius.pill`, 40 dp tall inside the 56 dp bar. The whole bar is still one button.
- **First appearance:** it slides up in 250 ms (`motion.cartBarEnter`). It only appears, never bounces.

## 8. Bottom navigation bar

| Part | Spec |
|---|---|
| Bar | `NavigationBar`, height `size.navBar` 68, white `surface.container`, `elevation.raised` 3, `shadow`, no surface tint (all from `navigationBarTheme`). |
| Indicator | `accent.goldLight` #FFE9A8 pill, 56 × 32 dp, `StadiumBorder`. |
| Icons (unselected → selected) | Home `home_outlined` → `home_rounded`; Categories `grid_view_outlined` → `grid_view_rounded`; Order again `replay_rounded` → `replay_circle_filled_rounded`; Account `person_outline_rounded` → `person_rounded`. 24 dp. Unselected `text.secondary` (9.41 on white); selected `brand.primary` (4.49 on the gold pill, needs 3:1 for an icon). |
| Labels | Always shown, 1 line. Selected `labelMedium` 12 / 700 `brand.primary` (5.40 on white); unselected 12 / 500 `text.secondary` (9.41). |
| Selection cue | Filled icon + gold pill + bold green label (not colour alone). |
| Text scaling | Clamp the label scale at 1.3× (`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` around the bar only). Turn the tooltips back on (tooltip = label), so a long-press shows the full label at the customer's size. English labels stay ≤ 12 characters; give Hindi translators the same limit. |
| Semantics | Material's own ("Home, tab 1 of 4, selected"). |

## 9. App bar (every inner screen)

| Part | Spec |
|---|---|
| Colours | From `appBarTheme`: background `brand.primaryDeep` #075C36, title and icons white (8.10), light status bar icons. |
| Size | `toolbarHeight` `size.appBar` 60. Title `appBarTitle` 20 / 800, 1 line with ellipsis (the full title is still read by the screen reader). |
| Leading / actions | the default back button; 48 dp `IconButton`s, white, each with a tooltip. Use `*_rounded` icons. |
| Elevation | 0, and no colour change on scroll (`scrolledUnderElevation` 0). |
| Search screen | The `TextField` in the title gets the theme's white fill, `radius.md` 12, 44 dp tall inside the 60 dp bar. The hint is `text.secondary` (9.41); the typed text is `text.primary`. |
| Home | Has no app bar: the header band (§2) plays that role. |

## 10. New strings (`app_en.arb`)

| Key | English | Notes |
|---|---|---|
| `homeAllProducts` | All products | section title |
| `perBox` | /box | after the price |
| `pricePerBoxSemantics` | {price} per box | screen reader |
| `bulkPriceFrom` | {price} at {count}+ boxes | `price` is the formatted server string |
| `homeReferralInvite` | Invite | referral strip pill |
| `bannerOpenHint` | Opens full screen | banner semantics hint |
| `bannerPageCount` | {index} of {count} | viewer counter |
| `bannerShopNow` / `bannerViewProduct` / `bannerInviteFriends` / `bannerOpenLink` | Shop now / View product / Invite friends / Open link | viewer button |

## 11. Data and API

- **API: no change needed.** Every field above is in the current schema: `VariantSummary.name`, `selling_price`, `mrp`, `price_tiers`, `min_qty_per_order`, `units_left`, `image_url`; `CouponOffer.code`, `title`, `description`, `is_eligible`, `ineligible_reason`; the referral `is_enabled` and reward fields; `HomeBanner.title`, `image_url` and link.
- **Data check for catalog-data (I could not confirm this):** the card shows the variant `name` as the pack size. The three water variants should be named "12 × 1 L", "24 × 500 ml" and "24 × 250 ml". I could not find the current names in `data/catalog/`, because the water SKUs were set up on the server.

## 12. Tests to add (flutter-customer-dev)

- Widget tests for Home and `ProductCard` at text scale 1.0, 1.3 and 2.0 on 360 × 640: no overflow; two columns, then one column at 2.0.
- Product card:
  - the bulk pill shows the last tier's server price and count
  - it is hidden with fewer than 2 tiers, or when that price equals the selling price
  - out of stock keeps the text at full opacity
- Offer strip:
  - the coupon is chosen by the reason rule (§4)
  - the referral strip shows when no coupon qualifies
  - nothing shows on error
- Banners: no timer runs; a tap opens the viewer; the viewer button follows the link.
- Theme: the rider app's existing tests still pass (`JivoTheme.light()` unchanged).
