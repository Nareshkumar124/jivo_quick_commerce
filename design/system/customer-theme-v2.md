# Customer theme v2: Jivo green + gold

- **Status:** ready for implementation. Version 1, 2026-11-14.
- **Owner:** ui-designer. **Implements:** flutter-customer-dev (a new customer-only theme, §8).
- **Why:** a test customer said the app "looks plain, no design, no colour". v2 adds colour, weight and depth without new images, new fonts or heavy effects.
- **Tokens:** `design/tokens/customer.tokens.json`. Token names below drop the `customer.color.` prefix. Every ratio on this page is recorded there and checked by `python -I design/tools/check_tokens.py` (54 pairs, 0 problems).
- **Placeholder until H-19 (D-06).** These are design colours, not Jivo's official brand kit. No logo, brand claim or brand font is invented. When the kit arrives, follow `design/tools/README.md`.
- **The rider app does not change.** `rider_app/lib/app/theme.dart` builds on `JivoTheme.light()`, so v2 must not change `JivoTheme.light()` or `JivoBrandColors.seed` (§8).
- **Screens:** the new Home and its components are in `design/screens/customer/home-v2.md`.

## 1. The idea

**A deep green band on top, a warm ivory canvas, white cards that float, and gold for "do this" and "save this".**

| Colour | It means | Where |
|---|---|---|
| Green | Jivo, where you are, what is already in your cart | header band, app bars, cart bar, quantity box, links, selected tab |
| Gold | an action or a saving | ADD, the main button on a screen, offers, coupons, bulk prices, discount badge |
| Ivory and white | calm space | screen background (ivory), cards and sheets (white) |
| Mint-aqua | fresh water | behind product photos only |

- **Balance:** about 60% ivory and white, 30% green, 10% gold. Gold is a highlight: one gold main button per screen area, and never gold text on a light background.
- **It grows from what customers already liked:** the gold cart savings card (`#FFE9A8 → #FFC24D`, ink `#3B2600`) and the referral banner (green + gold `#FFC83D`). Both colours are reused exactly.

**Not a Blinkit copy.** Blinkit's look is a yellow top area, a leaf-green outlined ADD on white, and their own illustrations. v2 is different on purpose:

| | Blinkit | Jivo v2 |
|---|---|---|
| Top of Home | yellow | deep emerald gradient band with 24 dp rounded bottom corners |
| ADD | white with a green outline | solid gold with an ink label; becomes a green quantity box |
| Green | leaf green | emerald / bottle green (`#0B7A47`, `#075C36`) |
| Background | white | warm ivory, white cards, mint-aqua image wells |
| Graphics | custom illustrations | none; Material rounded icons and Jivo's own product photos |

## 2. Palette

| Role | Token | Hex | Used for | Contrast (WCAG 2.x) |
|---|---|---|---|---|
| Jivo green | `brand.primary` | `#0B7A47` | quantity box, links, TextButton, OutlinedButton, selected tab, focus border | white on it **5.40**; it on white 5.40, on ivory 5.16 |
| Deep green | `brand.primaryDeep` | `#075C36` | app bars, header band start, cart bar | white on it **8.10**; gold on it 5.24 |
| Mint | `brand.primaryContainer` / `brand.onPrimaryContainer` | `#D6F3E1` / `#00391F` | pack-size pill, in-progress chips, OTP card | **11.07** |
| Jivo gold | `accent.gold` | `#FFC83D` | ADD, main CTA, View cart pill, discount badge | ink on it **9.28** |
| Ink | `accent.onGold` | `#3B2600` | every label and icon on gold | 14.35 on white |
| Gold light | `accent.goldLight` (= `brand.secondaryContainer`) | `#FFE9A8` | offer strip start, bulk-price pill, nav indicator, selected chips | ink 11.94 |
| Gold deep | `accent.goldDeep` | `#FFC24D` | offer strip end | ink 8.94 |
| Gold edge | `accent.goldEdge` | `#9E6A00` | 1 dp border around gold buttons | 4.65 on white, 4.44 on ivory, 3.01 against gold |
| Canvas | `surface.base` | `#FFF9F0` | scaffold background (warm ivory, not plain white) | text 16.35 |
| Card | `surface.card` (= `lowest`, `container`) | `#FFFFFF` | cards, sheets, nav bar, search field | text 17.12 |
| Chip / dialog | `surface.high` | `#F6EFE3` | unselected chips, dialogs | text 14.98 |
| Skeleton | `surface.highest` | `#ECE5D8` | skeletons, image placeholders, out-of-stock pill | text 13.66, muted 7.51 |
| Image well | `surface.imageWell` | `#E9F5F2` | behind product photos | decorative; no text on it |
| Text | `text.primary` | `#181D17` | body, titles, prices | 16.35 on ivory |
| Muted text | `text.secondary` | `#424840` | helper text, "/box", "Min 5" | 8.99 on ivory, 9.41 on white |
| Border | `outline.default` | `#73796F` | field borders, outlined buttons | 4.27 on ivory, 4.47 on white |
| Divider | `outline.decorative` | `#E5DCCB` | dividers only | 1.30: never for meaning |
| Success | `success.fg` | `#1B5E20` | You save, FREE delivery, coupon applied | 7.52 on ivory, 6.45 on `success.tint` `#E8EADB` |
| Warning | `warning.fg` | `#8A5300` | store closed, stars, notice icons | white on it 6.33 |
| Error | `danger.fg` | `#BA1A1A` | errors, "Only 2 left" | 6.17 on ivory, 6.46 on white |

**Gradients** (text checked against both ends):
- `gradient.header`: `#075C36 → #0B7A47`, top-left to bottom-right. White text 8.10 / 5.40. The gold bolt icon 5.24 / 3.49 (icon only).
- `gradient.offer`: `#FFE9A8 → #FFC24D`. Ink text 11.94 / 8.94.

**Shadow colour:** `shadow` `#0B3B22` (a green-black; Flutter adds the transparency for each elevation).

**Never do this** (recorded in `contrast.rejected`):
- gold as text or an icon on white or ivory (1.55)
- white text on gold (1.55)
- green text on gold (3.49) or on gold-light (4.49)
- any text at 60% opacity (the out-of-stock rule, CA-11)
- a divider colour for a border or icon that carries meaning (1.30)

## 3. Typography

**Font:** Roboto, the Android system font. No download, and Hindi (Devanagari) falls back cleanly. The personality comes from weight (700 to 800) and bigger sizes, not a new font. A brand font waits for the kit (TODO(D-06)).

| Material role | Size sp / weight | Used for |
|---|---|---|
| `displaySmall` | 36 / 800 | delivery OTP |
| `headlineMedium` | 28 / 800 | product detail price |
| `headlineSmall` | 24 / 800 | "Delivery in 14 mins", order status headline |
| `titleLarge` | 22 / 800 | section titles ("All products"), price on product cards |
| `titleMedium` | 17 / 700 | card and sheet titles, offer strip title |
| `titleSmall` | 15 / 700 | product name on cards |
| `bodyLarge` | 16 / 400 | text fields, long text |
| `bodyMedium` | 14 / 400 | default text |
| `bodySmall` | 12 / 400 | helper text (the smallest size for information) |
| `labelLarge` | 15 / 700 | buttons (the gold CTA uses 16 / 800) |
| `labelMedium` | 12 / 700 | pills (pack size, bulk price), nav labels |
| `labelSmall` | 11 / 600 | badges that only repeat information |

- **Prices** use tabular figures (`FontFeature.tabularFigures()`), so digits line up. Format is unchanged: the server's string through `formatRupees` (₹, Indian grouping, no decimals unless paise are non-zero).
- **App bar title:** 20 / 800, white.
- **No negative letter spacing** (it hurts Hindi). Keep Material's default spacing.
- **Everything scales** with the phone's font size. Test at 1.0, 1.3 and 2.0 on a 360 × 640 dp screen (`textScale.*` tokens).

## 4. Shape, elevation, spacing

| Radius | dp | Used for |
|---|---|---|
| `radius.sm` | 8 | badges, small thumbnails (cart lines, orders) |
| `radius.md` | 12 | buttons, ADD, quantity box, text fields, cart bar, the image well inside product cards |
| `radius.lg` | 16 | cards, banners, Home search field, offer strips |
| `radius.xl` (new) | 24 | Home header band bottom corners, bottom sheet top corners |
| `radius.pill` (new) | 999 | chips, pack-size and bulk pills, View cart pill, nav indicator |

| Elevation | dp | Used for |
|---|---|---|
| `elevation.flat` | 0 | app bars, header band, chips, offer strips |
| `elevation.card` | 1 | product cards and every `Card` |
| `elevation.raised` | 3 | search field on the band, cart bar, nav bar |

- **Shadows are Material elevation only** (one cheap shadow). No custom blur. The existing savings card keeps its own shadow.
- **Spacing** keeps the 4-point scale: `space.xs` 4, `sm` 8, `md` 12, `lg` 16, `xl` 24, `xxl` 32; page gutter 16. Card inner padding 12, gap between grid cards 12, 24 above a section title.

## 5. Icons

- **Material rounded icons** (`Icons.*_rounded`). They are in Flutter's built-in icon font: no extra download.
- Unselected tabs use the outlined icon; selected tabs use the filled rounded icon (a shape change, not only a colour change).
- **Sizes:** 24 dp normally, 20 dp inside pills and chips, 28 dp for the account button on the header band, 16 dp inside small badges.
- **Colours:** `text.secondary` or `brand.primary` on light surfaces; white or gold on green; ink on gold.
- Every icon-only button keeps its tooltip (it is also the screen-reader label).
- No emoji and no custom illustrations until the brand kit arrives.

## 6. Motion (subtle)

| What | How | Time (token) |
|---|---|---|
| Press on a product card or ADD | scale to 0.97 | 120 ms (`motion.press`) |
| ADD becomes the quantity box | `AnimatedSwitcher`, fade + scale 0.9 → 1 | 200 ms (`motion.qtySwap`) |
| Cart bar appears the first time | slide up + fade | 250 ms (`motion.cartBarEnter`) |
| Cart savings card | unchanged (slide in, one icon pulse) | 1000 ms |
| Home banners | no auto-scroll; the customer swipes | `motion.bannerAdvance` = 0 |

- Curve: `Curves.easeOutCubic` (`motion.curve`).
- All of it is skipped when `MediaQuery.disableAnimationsOf(context)` is true.
- No shimmer, parallax, springs or Lottie (budget phones). Skeletons stay as static `surface.highest` shapes.

## 7. Accessibility rules

- **Contrast:** every text/background pair passes WCAG AA (54 pairs in the token file). Text on a gradient is checked against both ends.
- **Touch targets:** at least 48 dp. ADD and the quantity box are 48 dp tall, the main CTA 52 dp, the nav bar 68 dp.
- **Never colour alone:**
  - ADD and "in cart" differ by label ("ADD" vs. the number with an edit icon), not just gold vs. green.
  - The selected tab has a filled icon and a bold label, not just colour.
  - Out of stock is a text pill.
- **Text scaling to 200%:** no fixed heights around text. The product grid becomes one column from 1.5×. The header band grows.
- **Hindi later (D-24):** leave room for strings about 40% longer. Buttons and pills may wrap to 2 lines instead of cutting text. Money is never cut off (`FittedBox` scale-down instead).

## 8. Flutter ThemeData changes (one place)

**Where:**
- Add a new file, `customer_app/lib/app/theme.dart`, with `ThemeData buildCustomerTheme()`. Build it on `JivoTheme.light()`, the same way `rider_app/lib/app/theme.dart` does.
- In `customer_app/lib/app/app.dart:96`, use `buildCustomerTheme()` instead of `JivoTheme.light()`.
- **Do not change** `JivoTheme.light()` or `JivoBrandColors` values in `jivo_core`, because the rider app builds on them.
- `jivo_core` gets only additive constants: `JivoRadii.xl = 24` and `JivoRadii.pill = 999`.

**New `CustomerColors` ThemeExtension** (in `customer_app`), read with `context.customerColors`:
- **Fields:** `primaryDeep`, `gold`, `onGold`, `goldLight`, `goldDeep`, `goldEdge`, `imageWell`, `shadow`, plus the two gradients.
- **Clean-up:** replace the hard-coded `_ink` and `_gradient` in `price_tier_nudge_card.dart` with these fields. The values are the same, so nothing changes visually.

| ThemeData part | Values (token → hex) |
|---|---|
| `colorScheme` | `ColorScheme.fromSeed(seedColor: #0B7A47).copyWith(...)` pinning: `primary` #0B7A47, `onPrimary` #FFFFFF, `primaryContainer` #D6F3E1, `onPrimaryContainer` #00391F, `secondary` #FFC83D, `onSecondary` #3B2600, `secondaryContainer` #FFE9A8, `onSecondaryContainer` #3B2600, `surface` #FFF9F0, `onSurface` #181D17, `onSurfaceVariant` #424840, `surfaceContainerLowest` / `Low` / `surfaceContainer` #FFFFFF, `surfaceContainerHigh` #F6EFE3, `surfaceContainerHighest` #ECE5D8, `outline` #73796F, `outlineVariant` #E5DCCB, `inverseSurface` #2D322B, `onInverseSurface` #EEF2E8, `error` #BA1A1A, `onError` #FFFFFF, `errorContainer` #FFDAD6, `onErrorContainer` #410002, `shadow` #0B3B22, `surfaceTint` `Colors.transparent` |
| `scaffoldBackgroundColor` | `surface.base` #FFF9F0 |
| `textTheme` | `base.textTheme.copyWith(...)` with the §3 sizes and weights, then `.apply(bodyColor: #181D17, displayColor: #181D17)` |
| `appBarTheme` | `backgroundColor` `brand.primaryDeep` #075C36, `foregroundColor` #FFFFFF, `elevation` 0, `scrolledUnderElevation` 0, `surfaceTintColor` transparent, `centerTitle` false, `toolbarHeight` 60, `titleTextStyle` 20 / 800 white, `iconTheme` / `actionsIconTheme` white 24, `systemOverlayStyle` `SystemUiOverlayStyle.light` with a transparent status bar |
| `cardTheme` | `color` #FFFFFF, `surfaceTintColor` transparent, `elevation` 1, `shadowColor` #0B3B22, `shape` radius 16. Keep the default margin (changing it would move every layout). |
| `filledButtonTheme` | `backgroundColor` gold #FFC83D, `foregroundColor` ink #3B2600, `side` 1 dp `accent.goldEdge` #9E6A00, `minimumSize` (64, 52), radius 12, `textStyle` 16 / 800, `elevation` 0, overlay ink at 8% hover / 12% pressed. Disabled: Material's default (12% / 38% `onSurface`) with no border. |
| `elevatedButtonTheme` | the same as `filledButtonTheme`. The app has no `ElevatedButton` today; a future one gets the main CTA look. |
| `outlinedButtonTheme` | `foregroundColor` #0B7A47, `side` 1.5 dp #0B7A47, `minimumSize` (64, 48), radius 12, `textStyle` 15 / 700 |
| `textButtonTheme` | `foregroundColor` #0B7A47, `minimumSize` (48, 48), `textStyle` 15 / 700 |
| `navigationBarTheme` | `backgroundColor` #FFFFFF, `elevation` 3, `shadowColor` #0B3B22, `surfaceTintColor` transparent, `height` 68, `indicatorColor` #FFE9A8, `indicatorShape` `StadiumBorder()`, `labelBehavior` always show. `iconTheme`: selected #0B7A47 24 dp, unselected #424840 24 dp. `labelTextStyle`: selected 12 / 700 #0B7A47, unselected 12 / 500 #424840. |
| `inputDecorationTheme` | `filled` true, `fillColor` #FFFFFF, `contentPadding` 16 horizontal / 14 vertical, radius 12. Borders: enabled 1 dp #73796F, focused 2 dp #0B7A47, error 1 dp and focused error 2 dp #BA1A1A. `hintStyle` #424840, `floatingLabelStyle` #0B7A47 w600, `prefixIconColor` #424840. |
| `chipTheme` | `backgroundColor` #F6EFE3, `selectedColor` #FFE9A8, `side` 1 dp #E5DCCB (selected: 1 dp #9E6A00), `shape` `StadiumBorder()`, `labelStyle` 13 / 600 #181D17, `secondaryLabelStyle` 13 / 700 #3B2600, `checkmarkColor` #3B2600, `padding` 12 horizontal, `iconTheme` 18 dp |
| `bottomSheetTheme` (extra) | `backgroundColor` #FFFFFF, `surfaceTintColor` transparent, top radius 24, `showDragHandle` true, `dragHandleColor` #73796F |
| `dividerTheme` (extra) | `color` #E5DCCB, `thickness` 1 |

**What changes everywhere without touching screens** (after the theme switch):

| What | How many uses (counted in the code) | New look |
|---|---|---|
| `FilledButton` and `BusyButton` | about 40 | gold |
| `AppBar` | 34 | green |
| Cards | all | white on ivory |
| Chips | 21 | warm, gold when selected |
| Text fields | 17 | white fill |
| Nav bar | 1 | white with a gold indicator |

**Check after applying:**
- **Search screen:** the `TextField` sits in the green app bar. The white fill and dark text are fine.
- **Pale-gold cards:** the delivery stage card and the session-expired card (`secondaryContainer`) turn pale gold with ink text (11.94).
- **Rider app:** must look exactly as before. Run its tests.
