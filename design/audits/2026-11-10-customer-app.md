# UX audit: customer app, end to end

- **Date:** 2026-11-10
- **Auditor:** ui-designer
- **Scope:** every customer screen in `docs/03-customer-app.md` §3: splash, onboarding, force update and maintenance; phone login and OTP; location, map pin, "not serviceable" and store closed; home; categories, product list, collection and product detail; search; cart (bill, coupons, tip, instructions, stock and price changes); checkout (address, payment method, COD, payment failure and retry, order success); orders list and detail; live tracking (rider, ETA, delivery OTP, socket-drop fallback); cancel and refund states; rating; help, FAQs and tickets; CMS pages; account, addresses, notifications inbox and delete account. For each screen: loading, empty, error, offline, slow network and the 426 force update. Plus accessibility: touch targets, contrast, text scaling at 1.3× and 2.0×, screen-reader labels, and money formatting.
- **Build audited:** `develop` f8db671 at `.worktrees/design/customer_app/lib/` (read-only). Also `packages/jivo_core/lib/src/theme/jivo_theme.dart`, `packages/jivo_core/lib/src/util/money_format.dart`, `customer_app/lib/l10n/app_en.arb` and `backend/openapi/schema.yaml` (to check which fields the app already receives).
- **Method:** static review of the widgets and strings against `docs/03`, `docs/08` (money and status rules), `docs/09` §4 and §6, and the design rules (48 dp targets, WCAG AA, text scaling to 200%, no colour-only signals, server-sent money only). **Nothing was run:** no build, no test, no phone (another PM session is changing `customer_app/` on its own branch, so line numbers may move). The colour roles were recomputed from the placeholder seed `#2E7D32` with a CAM16/HCT script and checked against Material's published baseline (within about 2 units per channel), so the ratios below are exact for the values in `design/tokens/customer.tokens.json`. Overflow risks are worked out from font sizes and widths on a 360×640 dp phone; each one says how sure it is.
- **Users and context:** shoppers on budget and mid-range Android phones (iOS later), often on patchy 3G/4G, many with large system text, ordering in a hurry and checking the order again and again until it arrives. Some read English as a second language; Hindi comes later (D-24).

## Severity

| Severity | Meaning |
|---|---|
| **High** | Can send an order to the wrong place, lose a customer's money or trust, or fail a store or legal review. Fix before the app reaches real customers. |
| **Medium** | Causes errors, confusion or abandoned orders, or fails WCAG AA or the text-scaling rule. Fix in the current phase if possible. |
| **Low** | Polish, consistency, or a later-phase risk. |

**What already works well (keep it):**
- **Money is never computed.** Every amount (bill rows, cart bar, line totals, COD due, refunds, coupon savings, "add ₹X more") is the server's string, formatted by jivo_core's `formatRupeeAmount` (₹, Indian grouping, paise only when non-zero). Zero rows are hidden by checking the server's value, not by arithmetic. "Proceed" and "Place order" follow the server's `checkout.can_place_order`, and the first server blocker explains why not.
- **Order statuses use the `08 §1` labels** ("Completing payment…", "Packed, rider on the way to store", "Delivery unsuccessful"), and every status chip is text plus colour, never colour alone. The timeline uses different icon shapes for done, current and upcoming.
- **Every list has loading (skeleton), empty and error-with-retry states**, and every button that calls the network shows progress and is disabled meanwhile (`BusyButton`).
- **Text scales everywhere:** there is no hard-coded font size in the app. Product tiles and category tiles compute their height from the text scale (`productTileExtent`, `categoryTileExtent`), so grids grow instead of overflowing.
- **Every icon-only button has a tooltip** (which is also its screen-reader label); the delivery OTP is read digit by digit; skeletons announce "loading" once and hide their shapes; the stepper announces the new quantity.
- **Payment safety:** double-tap protection, Back blocked while paying, one Idempotency-Key per attempt, the payment-failed screen reads the server status before allowing Retry, and an order left in `PAYMENT_PENDING` reopens by itself once after an app restart.
- **Socket with polling fallback** on tracking, order detail and My orders, with a capped number of sockets.
- **Store closed** is a banner with the opening time in IST (white on `#8A5300`, 6.33:1), and checkout is blocked with a reason.
- **Delete account** explains the 30-day grace period and confirms by OTP, and the destructive button is red (6.46:1).
- **CMS pages** render a safe subset of HTML with no web view, with a browser fallback for missing pages.

---

## Top 5 fixes (ranked by user impact)

| # | ID | Severity | Fix in one line |
|---|---|---|---|
| 1 | CA-07 | High | A new address's pin is always the phone's current GPS position. A customer adding "Home" from the office pins the office, so the wrong store, fees and rider route follow. Make the map pin the first step of the address form, and carry over the pin the customer already chose. |
| 2 | CA-10 | Medium | After leaving the "Order placed" screen, the only way back to a live order is Account → My orders → the order (3 taps), and push is off until D-19. Add an "active order" card on Home with status, arrival time and a Track button. |
| 3 | CA-03 | Medium | On a weak network, pulling to refresh Home or a product grid replaces everything already on screen with a full-screen error. Keep the content, show "Couldn't refresh" instead, and retry by itself when the connection comes back (CA-02). |
| 4 | CA-21 | Medium | When Cash on Delivery isn't allowed, the option simply disappears, although the server sends the reason. Show COD greyed out with the reason ("Available on orders up to ₹2,000"). Needs a PM decision (03 §2.9 says "hide"). |
| 5 | CA-17 | Medium | On slow data, tapping ADD or + gives no visible feedback for 1–3 seconds (the buttons only dim), so customers tap again and think the app froze. Show a small spinner in the stepper after 300 ms. |

---

## Findings

### A. Launch, app control and offline

#### CA-01 · Low · Force-update screen: no fallback link and no version detail
- **Screen / file:** `features/launch/presentation/app_control_screens.dart:17-37` (`ForceUpdateScreen`).
- **Issue:** the "Update now" button exists only when the 426 response carries `store_url`. Today the backend always sends it (`apps/cms/models.py` requires it), so this is a guard, not a live bug. But if the link is missing or fails to open, the customer is stuck on a screen with no action at all. The screen also doesn't say which version is needed, which helps when the Play Store still shows the old version (staged rollouts).
- **Fix:**
  - Button source, in order: the 426 `store_url` → `config/app` `store_url` (already loaded, `launch.config?.storeUrl`) → the platform store page for the app id. Never render the screen without a button.
  - Body: "This version of Jivo is no longer supported. Update to version **1.4.0** or later to continue." (the version from the 426 `details.min_supported_version`; omit the sentence when missing).
  - If opening the store fails, keep today's snackbar and add a secondary "Try again" button (48 dp).

#### CA-02 · Medium · No automatic retry when the connection comes back, and "connected but no internet" is not detected
- **Screen / file:** `shared/connectivity/connectivity.dart:9-26`, `shared/widgets/offline_banner.dart:17`. Nothing else in the app listens to `isOfflineProvider`.
- **Issue:**
  1. `03 §2.1` asks for "Retry on reconnect". Today, a screen that failed while offline (home, categories, product grid, cart, order detail) stays on its error until the customer finds and taps Retry, even after the "No internet connection" banner has gone.
  2. The banner only knows whether a network interface is on (`connectivity_plus`). Wi-Fi without internet, or mobile data with no signal, counts as "online", so the banner never shows while every request times out. This is common on Indian mobile networks.
- **Fix:**
  - Add a `reconnectProvider` (jivo_core or the app) that fires on an offline → online change. Screens in an error state retry once by themselves: `ErrorRetryView` gets an optional `retryOnReconnect: true` (default on), and the cart, track and order providers re-read. Also re-run `pendingPaymentProvider.check()` and `deliveryProvider.refresh()` if they failed.
  - Show the banner also after **2 network errors in a row** (`ApiErrorCode.network` or `timeout`) and hide it after the next success. Copy: "**No internet connection.** We'll update as soon as you're back online."
  - Banner style stays as it is (`customer.color.inverse.surface` / `text.onInverse`, 11.54:1, icon `wifi_off`, live region).

#### CA-03 · Medium · A failed refresh wipes the content already on screen
- **Screen / file:** home `features/home/presentation/home_screen.dart:152-166`; product grids `features/catalog/presentation/widgets/paged_product_grid.dart:52`; categories `features/catalog/presentation/categories_screen.dart:47`; order again `features/orders/presentation/order_again_screen.dart:50`.
- **Issue:** these screens `switch` on the provider state and send `AsyncError` to a full-screen `ErrorRetryView`. After a pull-to-refresh fails, Riverpod's state is an `AsyncError` that still holds the previous data (`hasValue` is true), but the `switch` ignores it. So on a weak network, a customer who pulls to refresh loses the home, categories or product list they were looking at. **Conclusion** from the code; a widget test should confirm it. `03 §2.1` also asks for "cached home/catalog shown read-only" offline; nothing is cached on disk yet (later, see Questions).
- **Fix:**
  - Rule for every list screen: **show the full-screen error only when there is no data.** When `state.hasError && state.hasValue`, keep the content and show a snackbar "**Couldn't refresh.** Check your connection." with the action "Retry".
  - Pattern for the developer: match `AsyncValue(:final value?, :final error?)` (data and error) before `AsyncError`.
  - Add a widget test per screen: load data, make the refresh fail, expect the content to stay.

#### CA-04 · Low · Onboarding: no position indicator, and brand claims need Jivo's approval
- **Screen / file:** `features/launch/presentation/onboarding_screen.dart:59-108`; strings `l10n/app_en.arb:27-37`.
- **Issue:** the three slides have no page dots, so customers don't know how many are left (most tap Skip). The copy makes product claims ("Genuine products, fresh stock, fair prices", "at your door in minutes") that Jivo Marketing has not approved. The design rules say not to invent brand claims until the brand kit arrives (D-06).
- **Fix:** add 3 page dots (8 dp, current one 16 dp wide, `ExcludeSemantics`) and give the page `Semantics(label: 'Slide 2 of 3')`. Keep the copy, but send it to Jivo Marketing with the brand kit request (see Questions).

### B. Login and OTP

#### CA-05 · Low · Login: the field doesn't open the keyboard, and consent can show without its links
- **Screen / file:** `features/auth/presentation/login_screen.dart:85-130`.
- **Issue:**
  1. The phone field has no `autofocus`. Every customer must tap it before typing.
  2. The consent line "By continuing, you agree to our" shows even when `config/app` has no `policies`; then the sentence ends with no links, so the customer agrees to documents they can't open.
- **Fix:** `autofocus: true` on the phone field. When `policies` is null, link to the in-app CMS pages (`Routes.page(CmsSlugs.terms)` and `privacy`) instead of hiding the links. Whether consent needs a checkbox is a legal question (03 §2.2 says "checkbox/text"), see Questions.

#### CA-06 · Low · OTP: a wrong code stays in the field
- **Screen / file:** `features/auth/presentation/otp_screen.dart:137-145`.
- **Issue:** after a wrong OTP, the error shows but the 6 wrong digits stay, so the customer must delete them one by one. Auto-verify on the 6th digit and SMS autofill are good; keep them.
- **Fix:** on `OTP_INVALID`, clear the field, keep focus in it, give a light haptic (`HapticFeedback.mediumImpact`) and keep the error text ("That OTP is incorrect. 2 attempts left." already comes from jivo_core).

### C. Location, serviceability and addresses

#### CA-07 · High · A new address is pinned wherever the phone is, with no map
- **Screen / file:** `features/addresses/presentation/address_screens.dart:158-160` (comment: "No map in Phase 1: the pin is the device location"), `:331-372` ("Location captured" tick and "Use current location", the only way to set the pin), `:447` (Save disabled until it is set). The cart and checkout ask to "Save this location as an address, or choose a saved one" (`features/cart/presentation/widgets/delivery_address_card.dart`), but the form never receives the location the customer already pinned.
- **Issue:**
  - The only way to set an address's pin is the phone's current GPS position. A customer at work who adds "Home" saves the office location. A customer who carefully pinned their gate on the map (`map_picker_screen.dart`) and then taps "Save this location" must capture GPS again, and the careful pin is lost.
  - The pin decides the serving store and serviceability (prices, stock and fees are per store) and where the rider navigates. A wrong pin means a wrong store, a refused or late delivery, and possibly a COD flag after a failed delivery.
  - The form shows only "Location captured" with a tick: the customer can't see where the pin is.
  - `03 §2.4` lists "map pin (required)" and `03 §3` #10 is "Add/Edit address (with map)". The map picker exists since Phase 2, so this is a gap, not a missing feature.
- **Fix (spec for flutter-customer-dev):**
  1. **Pin first.** The form opens with a "Delivery location" card at the top:
     - With a known pin (coming from "Save this location", or editing an address): a 140 dp map preview (or, without the Mappls config, the reverse-geocoded line plus the coordinates), the address line under it, and a 48 dp outlined button "**Adjust pin**" that opens `MapPickerScreen` at that point.
     - Without a pin: a filled button "**Set location on map**" (opens the map picker at the current delivery location, else the GPS fix), and a text button "Use my current location".
     - Without Mappls (map not available): keep "Use my current location", and add the warning line "Use this only when you are at this address now." in `text.secondary`.
  2. **Carry the pin over.** `Routes.newAddress` accepts an initial `DeliveryLocation` (point plus geocoded text) as `extra`. "Save this location" passes the selected delivery location.
  3. **Prefill** area, city, state and pincode from the reverse geocoder when the fields are empty. Every field stays editable.
  4. **Editing an address** shows its saved pin the same way (today the form re-captures GPS).
  5. After saving from the cart or checkout flow, select the new address as the delivery location (it re-runs serviceability through `chooseDeliveryLocation`), so the customer lands back where they were with the address set.
  6. Save stays disabled until a pin exists, with the reason next to the button: "Set the delivery location on the map first."

#### CA-08 · Medium · Address list: the label row overflows at 1.3× text, and the menu has no address name
- **Screen / file:** `features/addresses/presentation/address_screens.dart:103-121` (title `Row` with the label and up to two `Chip`s), `:123` (`PopupMenuButton`).
- **Issue:**
  - The label is `Flexible`, but the "Not serviceable" and "Default" chips are fixed width. In a `ListTile` title on a 360 dp phone (about 240 dp wide), the two chips need about 320 dp at 1.3× text. **Likely overflow** at 1.3× and certain at 2.0× (estimate from font sizes; confirm with a widget test). In a release build the overflow is clipped, so the label disappears.
  - The trailing menu button announces only "Show menu", so a screen-reader user can't tell which address it belongs to.
- **Fix:** replace the `Row` with `Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: center)`. Give the chips text and an icon (`location_off` for not serviceable, `star` for default), so the meaning doesn't rest on the chip colour. Set `PopupMenuButton(tooltip: 'More options for Home')` (the address label). Add a 1.3× and 2.0× widget test.

#### CA-09 · Low · Detecting location: progress has no words, and a failed cart clear is silent
- **Screen / file:** `features/location/presentation/location_options.dart:106` (`LinearProgressIndicator` only); `features/location/presentation/location_flow.dart:80` (`controller.select(..., clearCart: true)`).
- **Issue:**
  1. GPS on a budget phone indoors can take the full 15 s limit. The customer sees only a thin bar at the top of the list.
  2. When the store changes and the customer confirms clearing the cart, `cart.clear()` can fail (no network). The error isn't caught in `chooseDeliveryLocation`, so nothing happens and no message shows. **Possibility** (read from the code; a test should confirm the uncaught error).
- **Fix:** under the "Detect my location" row, while busy, show "Finding your location… This can take a few seconds." (`bodyMedium`, live region). Wrap the store-change `select` in try/catch and show the mapped error ("No internet connection…"); keep the old location selected.

### D. Home and catalog

#### CA-10 · Medium · An active order can't be found from Home
- **Screen / file:** `features/home/presentation/home_screen.dart:91-92`. Home shows the update prompt and the pending-payment banner, but nothing for an order that is placed, packing or on the way.
- **Issue:** after the "Order placed" screen, the only way back to a live order is Account → My orders → the order (3 taps on 2 screens). In quick commerce, customers check their order many times in 10–30 minutes, and need the delivery OTP at the door. Push notifications are a no-op until the Firebase projects exist (D-19), so nothing else brings them back.
- **Fix (spec):**
  - An **active order card** under the search bar, above the banners. It reuses the call Home already makes (`orderRepository.activeOrders()` in `PendingPaymentController.check`), so no new API is needed.
  - Content: status label from `08 §1` (`titleSmall` / 700), "Arriving by 3:45 pm" (server `eta_at`, IST), and while `OUT_FOR_DELIVERY` a second line "**Delivery OTP ready**: open to see it" (never the OTP itself on Home). Trailing button "Track" (48 dp). The whole card (min 64 dp) opens tracking, or the order detail before tracking is available.
  - Colours: `customer.color.brand.primaryContainer` with `text.primary` (13.27:1). Icon `delivery_dining`.
  - Two or more active orders: "2 orders in progress" opening My orders.
  - It refreshes with the Home pull-to-refresh and on the order socket's status events (the same listener My orders uses). Hide it when the order is delivered, cancelled or failed.
  - A `PAYMENT_PENDING` order keeps today's pending-payment banner instead.

#### CA-11 · Medium · Out-of-stock tiles fail contrast because the whole card is dimmed
- **Screen / file:** `features/catalog/presentation/widgets/product_tile.dart:102-103` (`Opacity(opacity: product.inStock ? 1 : 0.6)` around the whole card); the label `features/cart/presentation/add_stepper.dart:132-150` (`OutOfStockLabel`, `onSurfaceVariant`).
- **Issue:** at 60% opacity on the card colour:
  | Text | Effective colour | Ratio | Needs |
  |---|---|---|---|
  | "Out of stock" label, variant name, MRP (`text.secondary`) | #888D84 | **3.07:1** | 4.5:1 |
  | "Only 2 left" (`danger.fg`) | #D0726E | **3.01:1** | 4.5:1 |
  | Product name (`text.primary`, 14 sp) | #6F736C | **4.37:1** | 4.5:1 |
  The label that says the product can't be bought is the least readable text on the tile. `Opacity` on a whole card also forces an extra offscreen layer per tile, which costs frame time on budget phones while scrolling.
- **Fix:**
  - No opacity on text. Grey only the image: `ColorFiltered` with a saturation-0 matrix plus `Opacity(0.5)` on the `ProductImage` alone.
  - Replace `OutOfStockLabel` with a 48 dp high, full-width pill: background `customer.color.stock.outBg` #E0E4DA, text "**Out of stock**" in `customer.color.stock.outFg` #181D17 (**13.27:1**), 14 sp / 600, leading icon `remove_shopping_cart` (20 dp, `text.secondary`). The pill sits where ADD would be, so the layout doesn't jump.
  - Keep the price and MRP at full contrast (customers still compare prices).
  - Same rule on the product detail and the variant picker.

#### CA-12 · Medium · The veg and non-veg marks differ only by colour
- **Screen / file:** `features/catalog/presentation/widgets/price_tags.dart:8-37` (`VegMark`: both are a square with a filled **circle**, green `#138808` or brown `#8B4513`).
- **Issue:** a customer with red-green colour blindness sees two almost identical marks. The screen-reader label is right ("Vegetarian" / "Non-vegetarian"), but sighted users get colour only. Also, as far as I know, the FSSAI (Labelling and Display) Regulations 2020 changed the non-veg symbol to a **brown triangle** inside a brown square. Jivo regulatory should confirm (see Questions).
- **Fix:** non-veg draws a filled triangle (pointing up, 55% of the box) instead of the circle. Keep the colours (veg 4.37:1, non-veg 6.73:1 on `surface.base`, both above the 3:1 needed for graphics), the 1.5 dp border and the labels. On product detail, add the word next to the 18 dp mark: "Veg" / "Non-veg" (`labelMedium`).

#### CA-13 · Medium · Product detail: ADD scrolls out of view, and the tax line for MRP is missing
- **Screen / file:** `features/catalog/presentation/product_detail_screen.dart:197-235` (price, then `AddStepper` in the middle of the scrolling list), `:41` (`bottomNavigationBar` is only the cart bar).
- **Issue:**
  1. The ADD stepper sits under the price, before highlights, description, ingredients, nutrition and similar products. Once the customer scrolls down to read (the reason to open the detail page), ADD is gone and they must scroll back up.
  2. The price shows the selling price and the struck MRP, but no "inclusive of all taxes" line. E-commerce listings in India usually show "MRP (incl. of all taxes)" under Legal Metrology. This is a legal question for Jivo (see Questions).
- **Fix:**
  - A **sticky action bar** at the bottom (`customer.size.pdpActionBar`, 72 dp, `surface.base`, elevation 3), above the cart bar when the cart isn't empty:
    - Left: the selected variant name ("1 L"), the price (`titleMedium` / 700) and the struck MRP (`bodySmall`, `text.secondary`).
    - Right: the ADD stepper, 160 dp wide (`customer.size.pdpStepperWidth`), or the out-of-stock pill (CA-11).
    - At ≥ 1.5× text, the bar stacks: the price line on top and a full-width stepper below.
  - Keep the in-page price block and "You save ₹X", and remove the in-page stepper (one ADD per screen).
  - Under the in-page price: "MRP inclusive of all taxes" (`bodySmall`, `text.secondary`), if Jivo legal confirms.

#### CA-14 · Medium · At large text, product names shrink to a few characters per line
- **Screen / file:** `features/catalog/presentation/product_list_screen.dart:172` (76 dp sub-category rail), `:234-236` (rail labels `labelSmall`, 11 sp, 2 lines); `features/catalog/presentation/widgets/product_tile.dart:286` (`maxCrossAxisExtent: 200`).
- **Issue:** on a 360 dp phone the product list is a 76 dp rail plus a 2-column grid of about 137 dp tiles. At 2.0× text, a tile fits about 8 characters per name line (2 lines, then "…"), so "Jivo Cold Pressed Canola Oil" reads "Jivo Cold / Pressed…", and the rail fits about 5 characters ("Cooki…"). Nothing overflows (the tile height grows with text, good), but customers who need large text can't tell products apart.
- **Fix:**
  - From `customer.textScale.singleColumnFrom` (1.5×): `maxCrossAxisExtent = 200 × textScale`, so the grid becomes 1 column (tiles become wide). The home rails keep their horizontal scroll; tile width becomes `150 × min(textScale, 1.5)`.
  - From 1.5×: the sub-category rail becomes a horizontal, scrollable row of `ChoiceChip`s under the app bar (48 dp, selected chip with a check icon), and the grid takes the full width.
  - Rail labels: 12 sp minimum (`customer.font.subCategoryLabel`).
  - Widget tests at 1.0×, 1.3× and 2.0× on 360×640.

#### CA-15 · Low · Images are decoded at full size, and banner crops are undefined
- **Screen / file:** `shared/widgets/product_image.dart:28-35` (`Image.network` with no `cacheWidth`, no disk cache yet); `features/home/presentation/banner_carousel.dart:87` (fixed 150 dp height), `:124` (`BoxFit.cover`).
- **Issue:** a 1000×1000 px product photo shown in a 56 dp cart thumbnail is decoded at full size. On a 3 GB phone scrolling a grid of 20+ tiles, this costs memory and can cause jank. **Possibility**: the size of the images the API serves isn't fixed yet (catalog-data). Banners are 150 dp high at any width, so a 2:1 banner is cropped differently on every phone and text baked into the image can be cut off.
- **Fix:** pass `cacheWidth: (layoutWidth × devicePixelRatio).round()` from a `LayoutBuilder` in `ProductImage` (`customer.image.decodeAtLayoutSize`). Banners: `AspectRatio(aspectRatio: 2)` (`customer.image.bannerAspect`), and tell catalog-data and ops to export banners at 1200×600 px with text in the middle 80%. Product images stay 1:1 with `BoxFit.contain`. The planned `cached_network_image` disk cache also helps the offline case (CA-03).

#### CA-16 · Low · The banner carousel keeps moving
- **Screen / file:** `features/home/presentation/banner_carousel.dart:51-59` (`Timer.periodic` every 4 s).
- **Issue:** auto-scroll stops for "reduce motion" (good), but not while the customer touches or reads a banner, and not when a screen reader is on. WCAG 2.2.2 (Pause, Stop, Hide) asks for a way to stop content that moves for more than 5 seconds. The dots are hidden from screen readers, so a screen-reader user doesn't know there are more banners.
- **Fix:** pause the timer on pointer down and for 8 s after the last touch; don't start it when `MediaQuery.accessibleNavigationOf(context)` is true. Give each banner `Semantics(label: '<title>, banner 2 of 5')`.

### E. Cart

#### CA-17 · Medium · ADD and the stepper give no feedback on slow data
- **Screen / file:** `features/cart/presentation/add_stepper.dart:60-80` (buttons disabled while `pending`), `:222` (disabled icons at 60%); `features/cart/presentation/cart_controller.dart:218` (`_set`: the quantity changes only when the server answers).
- **Issue:** the cart is server-side, so the number changes only after `POST /cart/items/` returns. On 3G that takes 1–3 seconds. Meanwhile the only feedback is that the + and − icons fade a little. Customers tap again (ignored), or think the app froze. The ADD button shows nothing at all while pending.
- **Fix:**
  - When a change for a variant is still pending after 300 ms (`customer.motion.pendingSpinnerDelay`), replace the quantity number (or the "ADD" label) with a 16 dp `CircularProgressIndicator` (stroke 2, colour `brand.onPrimary` on the stepper, `brand.primary` on ADD). Keep the size, so nothing jumps.
  - Keep semantics: `Semantics(label: 'Updating quantity', liveRegion: true)` while pending.
  - Don't show the new number before the server confirms (stock is the server's decision). A failure keeps today's snackbar.

#### CA-18 · Low · Cart line at large text, and Remove has no undo
- **Screen / file:** `features/cart/presentation/widgets/cart_line_tile.dart:42-139` (`Row`: 56 dp image, info, then a trailing column with the 112 dp stepper, line total and delete icon).
- **Issue:** at 2.0× text the trailing column grows to the width of the line total (about 140 dp for "₹1,24,999"), leaving about 88 dp for the product name, which then shows about 5 characters per line. The delete icon removes the line at once, with no undo. An out-of-stock line still shows its line total, and it isn't clear whether that amount is part of "To pay" (see Questions).
- **Fix:** from 1.3× text, stack the line: image + name/variant/price on the first row, then a row with the stepper (left) and the line total (right), then the issue text and fix button. After Remove, show a snackbar "Removed Jivo Canola Oil 1 L" with the action "**Undo**" (re-sets the old quantity through the same server call; the server still checks stock).

#### CA-19 · Medium · Price changes are easy to miss
- **Screen / file:** checkout `features/checkout/presentation/checkout_screen.dart:55-75` (`PRICE_CHANGED` shows only a snackbar); cart lines `features/cart/presentation/widgets/cart_line_tile.dart:72` (the line shows the current price, with no "changed" flag).
- **Issue:**
  1. When the total changes at "Place order", the customer sees "Your total changed from ₹X to ₹Y…" for about 4 seconds in a snackbar, at the bottom of the screen, near the Pay button. The button label already shows the new amount ("Pay ₹Y"), but a customer looking at the button can miss why.
  2. The server cart survives for days. If a price went up since the customer added an item, the cart just shows the new price with no flag.
- **Fix:**
  - **Checkout:** a persistent notice above the payment methods, until the next successful place or a change of method: background `customer.color.warning.tint` #FFF4D6, text `text.primary` (15.62:1), icon `info` in `warning.fg`: "**Your total changed** from ₹1,240 to ₹1,265. Check the bill below, then pay." Both values are the error's `details` (server strings). Keep the snackbar off for this case.
  - **Cart (needs API, see the table):** when the server sends the previous price for a line, show under the price "Price changed: was ₹249" in `text.secondary`, and a cart-level notice "Prices of 2 items changed since you added them."

#### CA-20 · Low · Checkout bar details
- **Screen / file:** `features/cart/presentation/cart_screen.dart:344-387` (`_CheckoutBar`); the same pattern in `checkout_screen.dart:195-234`.
- **Issue:** the reason checkout is blocked is `bodySmall` (12 sp) in red with no icon. "To pay" keeps the old amount while a change is in flight (the button is correctly disabled, but nothing says the total is updating). At 2.0× text, the button label "Proceed to checkout" wraps to 2–3 lines next to the total.
- **Fix:** blocker text 14 sp / 500 (`customer.font.blockerReason`) with a leading `info` icon (20 dp, `danger.fg`). While `cart.busy`, show "Updating…" (`labelMedium`, `text.secondary`) under the total instead of hiding anything. From 1.5× text, stack the total above a full-width button.

### F. Checkout and payment

#### CA-21 · Medium · Cash on Delivery disappears without a reason
- **Screen / file:** `features/cart/domain/cart.dart:124-129` (`offers()` keeps only methods with `is_available`), `:256-272` (`PaymentOption` already holds `reason` and `message`); `features/checkout/presentation/checkout_screen.dart:152-170`.
- **Issue:** the server sends why COD isn't available (`unavailable_reason`: COD disabled, above the limit, not allowed for this account; plus a display `message`), but the app hides the option, as `03 §2.9` and the schema describe ("show only when true"). Customers who always pay cash look for COD, don't find it, and don't know whether to add less, pay online, or give up. Also, `onlinePaymentUnavailable` (`checkout_screen.dart:65`) says "…or choose Cash on Delivery" even when COD isn't offered.
- **Fix (needs a PM decision, because it changes 03 §2.9):**
  - Show COD as a disabled `RadioListTile` (`enabled: false`) with the icon `payments_outlined`, the title "Cash on delivery" and the reason as the subtitle in `text.secondary` (8.91:1):
    | Reason | Subtitle |
    |---|---|
    | `ABOVE_LIMIT` | "Available on orders up to ₹2,000" (amount from the server; see APIs) |
    | `COD_DISABLED` | "Not available right now" |
    | `NOT_ALLOWED` | Wording for the PM and legal (see Questions); suggestion: "Not available on this account. Pay online to continue." |
    | unknown | the server's `message` |
  - The disabled text must stay readable: don't rely on the 38% disabled colour for the subtitle (2.35:1); set the subtitle style explicitly.
  - Pick the 503 message by `codAvailable`: with COD, keep today's text; without, "Payment service is unavailable right now. Please try again in a few minutes."

#### CA-22 · Medium · Payment failed: no reassurance about money already taken
- **Screen / file:** `features/checkout/presentation/payment_failed_screen.dart:182-199` (the details list), `:243` (Retry button); strings `l10n/app_en.arb:611-629`.
- **Issue:** with UPI, the money often leaves the bank account even though the payment "failed". A customer who sees "The payment for order JQ-1042 wasn't completed" right after a debit SMS fears the money is lost, and calls support or pays twice. The screen doesn't say what happens to such money. The Retry button also doesn't show the amount.
- **Fix:**
  - Add one line under the reason, for online orders: "**If money was taken from your account**, it isn't lost. It goes back to the same account automatically." The time frame comes from Jivo Finance / Razorpay (see Questions); don't add a number until confirmed.
  - Retry label: "Retry payment · ₹1,240" (server `grand_total`).
  - Keep the "Pay by 3:45 pm" hint and the server-checked Retry.

#### CA-23 · Low · Checkout and payment polish
- **Screen / file:** `features/checkout/presentation/checkout_screen.dart:128` (`PopScope(canPop: !checkout.busy)`), `:221-223` (COD button label); `features/checkout/presentation/order_success_screen.dart:84-87`; `features/orders/presentation/pending_payment.dart:94`.
- **Issue and fix:**
  - The COD button says only "Place order". Use "Place order · ₹1,240 (pay on delivery)", so the customer sees the amount before committing, as online does with "Pay ₹1,240".
  - Back is blocked silently while paying. On a blocked Back, show a snackbar "Please wait. We're confirming your payment."
  - The order-placed icon uses an elastic bounce; skip the animation when `MediaQuery.disableAnimationsOf(context)` is true.
  - The pending-payment banner on Home uses the red error container for a state that is not an error. Use `customer.color.status.pendingPayment` (bg #FFF4D6, text #181D17, 15.62:1, icon `hourglass_top` in #8A5300), and add the deadline when the server sends it: "Order JQ-1042 is waiting for payment · Pay by 3:45 pm".

### G. Orders, tracking, cancel and refunds

#### CA-24 · Medium · Order detail: the status row overflows at large text
- **Screen / file:** `features/orders/presentation/order_detail_screen.dart:145-153` (`Row` with `OrderStatusChip`, `Spacer` and the date, none of them flexible).
- **Issue:** the chip's text and the date can't wrap or shrink. For "Packed, rider on the way to store", the row needs about 315 dp at 1.0× (328 dp available on a 360 dp phone) and about 400 dp at 1.3×, so it **overflows from about 1.1×**. Most other statuses overflow at 2.0×. In a release build the date is cut off; in debug the yellow-black stripes appear. Hindi labels will be longer. Estimate from font sizes; a widget test should confirm.
- **Fix:** replace the `Row` with `Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center)`. Let the chip text wrap inside a `ConstrainedBox(maxWidth: availableWidth)`. Add widget tests at 1.3× and 2.0× for the longest label.

#### CA-25 · Medium · Tracking: the delivery OTP is below the map
- **Screen / file:** `features/tracking/presentation/tracking_screen.dart:110-113` (`TrackMap` comes before `DeliveryOtpCard`); `features/tracking/presentation/tracking_map.dart:47` (220 dp map).
- **Issue:** at the door the customer opens tracking to read the OTP. The order is status, ETA, stage card, the 220 dp map, then the OTP. On a 360×640 phone the OTP card starts at about 490 dp at 1.0×, so it is only just visible, and at 1.3× text (or with the offline banner) it is below the fold. (The order detail already shows the OTP near the top; keep that.)
- **Fix:** the order on tracking becomes: status headline → ETA line (CA-26) → **OTP card** (when present) → COD card (when present) → stage card → map → rider card → timeline → "Order details". When the stage is `arriving`, also give the OTP card a 2 dp `brand.primary` border.

#### CA-26 · Medium · Tracking doesn't say when its data is old
- **Screen / file:** `features/tracking/presentation/tracking_providers.dart:91-98` (a failed poll keeps the last data silently); `features/tracking/presentation/delivery_cards.dart:77-81` (rider subtitle "Your delivery partner · 3:45 pm"); `features/tracking/presentation/tracking_screen.dart:140-185` (`EtaCountdown`, "Arriving any moment" once the ETA has passed).
- **Issue:**
  1. When the socket is down and polling fails (weak signal), the rider marker, status and ETA freeze, and nothing tells the customer.
  2. The time after "Your delivery partner" is when the rider's location was last updated, but it reads like an arrival time.
  3. When the rider is late, "Arriving any moment" stays for as long as it takes, which erodes trust.
- **Fix:**
  - A one-line freshness indicator under the ETA (`bodySmall`, with an icon):
    | State | Text | Icon / colour |
    |---|---|---|
    | Socket live (`TrackController.live`) | "Live" | 8 dp dot in `success.fg` plus the word |
    | Polling, last poll OK | "Updated 3:45 pm" | `sync`, `text.secondary` |
    | Last poll failed | "**Can't update right now.** Last update 3:45 pm" | `cloud_off`, on `warning.tint`, text `text.primary` (15.62:1) |
  - Rider subtitle: "Location updated 2 min ago" (relative, from `rider.updatedAt`).
  - Late: 5 minutes after the server ETA (`customer.motion.etaLateAfter`), replace "Arriving any moment" with "**Running a little late.** Your rider is on the way." and show a "Get help" text button (opens a ticket for this order). A new ETA from the socket (`order.eta`) replaces it as today. The app only compares the clock with the server's time; it never estimates a new ETA.

#### CA-27 · Medium · "Item couldn't be supplied" is hidden at the bottom of the order
- **Screen / file:** `features/orders/presentation/order_detail_screen.dart:459-465` (the only sign is "N unavailable" in red under the line, inside the Items section), `:194` (`CodDueCard`); refund model `features/orders/domain/order_history.dart:193-205` (`OrderRefund` drops the `reason` the API sends).
- **Issue:** when the store marks an item unavailable (T8a, `08 §6.3`), the bill, the COD amount and the refunds change, but the top of the order looks the same. The customer must scroll to the items to find out. A COD customer meets the rider expecting to pay ₹1,240 and is asked for ₹990 (the rider side was fixed in RD-03; the customer side wasn't). The API already sends `refunds[].reason = ITEMS_UNAVAILABLE`, but the app model drops it.
- **Fix:**
  - Add `reason` to `OrderRefund` (from `OrderRefundReasonEnum`).
  - A notice card under the status headline whenever any line has `quantity_unavailable > 0`: background `warning.tint`, icon `info` in `warning.fg`, text `text.primary`:
    - Title: "**1 item couldn't be supplied**"
    - Lines: "Jivo Canola Oil 1 L: 1 of 2" (one per line, at most 2, then "and 1 more").
    - Money line, from the server only: online paid → "₹250 is being refunded to your original payment method" (the `ITEMS_UNAVAILABLE` refund's amount and status); COD → "Pay **₹990** to the rider" (`cod_amount_due`).
  - Refund lines get reason-specific copy: "₹250 refunded for items the store couldn't supply."
  - Ask the backend for a push when this happens (after D-19).

#### CA-28 · Low · Cancel sheet details
- **Screen / file:** `features/orders/presentation/cancel_order_sheet.dart:43-62` (`cancelRefundText` derives the refund line in the app from `payment_method`, `payment_status` and `grand_total`, a documented PM default until D-10), `:177-186` (confirm is a filled primary button, "Keep order" a text button); `features/orders/presentation/order_detail_screen.dart:649-675` (`_ContactSupportCard` shows no action without a support phone).
- **Issue:** the refund amount shown before cancelling is chosen by the app (from `grand_total`). If an item was already refunded (CA-27), the app still promises the full total as "full refund". The destructive "Cancel order" looks like the main, safe action. "Contact support for help" can appear with no way to contact anyone.
- **Fix:** when the backend offers a refund preview (see APIs), show that amount instead. Style the confirm as destructive (`FilledButton` with `danger.fg` / `danger.on`, 6.46:1) and make "Keep order" an `OutlinedButton` of the same size above it. Without a support phone, the card's action becomes "Get help" (new ticket for this order).

#### CA-29 · Low · Orders list and timeline details
- **Screen / file:** `features/orders/presentation/order_timeline.dart:42` ("upcoming" icon and connector in `outlineVariant`); `features/orders/presentation/orders_screen.dart:100` (load more only on scroll), `:190` (`imageUrls.take(4)`).
- **Issue and fix:**
  - Upcoming steps are drawn in `outline.decorative` #C2C8BD, **1.62:1**, below the 3:1 needed for a meaningful icon. Use `outline.default` #73796F (4.24:1).
  - If the first page doesn't fill the screen, the scroll-based "load more" never fires. Also trigger it after the first build when `maxScrollExtent == 0 && hasMore`.
  - Order cards show up to 4 thumbnails with no hint of more. Add a "+3" tile (40 dp, `surface.highest`, `labelLarge`).

### H. Help, ratings and account

#### CA-30 · Medium · Support replies don't appear on an open ticket
- **Screen / file:** `features/support/presentation/ticket_screens.dart:434-540` (`TicketDetailScreen`: loads once; only pull-to-refresh reloads), `:507-514` (the thread starts at the top), `:685` (`counterText: ''` hides the 1000-character limit).
- **Issue:** a customer waiting on the ticket screen never sees support's reply unless they pull down. Push is a no-op until D-19, so nothing tells them a reply arrived. In a long thread, the newest message is at the bottom and off screen. (The rider app has the same issue, RA-22.)
- **Fix:** while the thread is open and the ticket isn't `CLOSED`, re-read it every 15 s (`customer.motion.ticketPoll`) and on app resume; stop when the screen closes. Scroll to the newest message on open and after sending. When a new support message arrives while the customer is scrolled up, show a "New reply ↓" pill (48 dp). Show the character counter from 900 characters.

#### CA-31 · Medium · Missing account and compliance items: grievance officer, promotional push consent
- **Screen / file:** `features/support/presentation/help_screen.dart:19-85` (no grievance officer); `features/profile/presentation/account_screens.dart:59-160` (no notification preferences).
- **Issue:**
  1. The Consumer Protection (E-Commerce) Rules 2020 require the grievance officer's name, designation and contact details to be shown to buyers (`09 §4` plans it on the support screen in Phase 7). Nothing shows them.
  2. `03 §2.11` asks for a toggle for promotional push. The API already has it (`PATCH /me/` with `marketing_opt_in`), but the app has no switch, so customers can't withdraw consent in the app (DPDP).
- **Fix:**
  - Help: a section "**Grievance officer**" at the end: name, designation, email (`mailto:`), phone (`tel:`), and the response time, from config or a CMS page (see APIs). Each contact is a 48 dp `ListTile`.
  - Account → a "Notifications" sub-screen (or a row): `SwitchListTile` "Offers and promotions", subtitle "Order updates are always sent.", bound to `marketing_opt_in`, with a progress state and an error snackbar if saving fails (the switch goes back).

#### CA-32 · Low · Delete account: no resend, no warning about open orders
- **Screen / file:** `features/profile/presentation/account_screens.dart:218-352` (`DeleteAccountScreen`; OTP step from `:315`).
- **Issue:** the OTP step has no "Resend OTP" or countdown, so a lost SMS forces the customer to leave and start again. Nothing warns a customer who has an order on the way or a refund in progress.
- **Fix:** reuse the login screen's resend row ("Resend OTP in 25s", then "Resend OTP"). Before sending the OTP, if `activeOrders()` is not empty, show "You have an order in progress. Your account will be deleted after it's delivered." or block it, as the PM decides (see Questions).

#### CA-33 · Low · A malformed amount breaks the whole widget
- **Screen / file:** `shared/formatting/formatters.dart:22-24` (`formatRupees` throws `FormatException`), used in 37 places inside widgets (bill rows, tiles, cart lines, order rows, coupon sheet).
- **Issue:** if the server ever sends an amount the formatter can't read (for example `".50"`, which the schema's pattern allows), the widget that renders it throws, and the customer sees a grey or red box instead of the bill. Checkout already does the safe thing (`formatRupeesOrNull`, and a missing total blocks paying).
- **Fix:** in widgets, use `formatRupeesOrNull(x) ?? '—'` and block the dependent action (as checkout does). Keep the throwing version for tests and data mapping only. No change to the money rule.

#### CA-34 · Low · Screen-reader details
- **Screen / file and fix:**
  - Read-only stars (`features/orders/presentation/order_detail_screen.dart:625`, `features/rating/presentation/rate_order_screen.dart:237-250`) are announced as five disabled buttons. In read-only mode, wrap them in `Semantics(label: 'Rated 4 out of 5', excludeSemantics: true)`, and draw empty stars in `text.secondary`, not the 38% disabled colour (2.35:1).
  - FAQ category titles (`features/support/presentation/help_screen.dart:115`) and the "Legal" title on Account (`account_screens.dart:97-103` and `:117-122`, a `ListTile` with no action) are not marked as headers. Use `Semantics(header: true)` and plain text instead of a `ListTile`.
  - Product tiles (`product_tile.dart:104-131`) split into several screen-reader stops (info, price, ADD), and the "open product" action is on the card behind them. **Needs checking with TalkBack:** if a double-tap on the name doesn't open the product, give the card `Semantics(button: true, label: '<name>, <variant>, <price>', hint: 'Opens product details')` and keep ADD as its own stop.
  - The inbox still counts unread items from the first page (`features/notifications/presentation/inbox_screen.dart:132`, `TODO(api)`), but the API now has `me_notifications_unread_count` (api-requests #45). Bind it so the badge is right.

---

## APIs and data required

| # | Need | For | Owner |
|---|---|---|---|
| 1 | On `PaymentOption`, the COD limit as a field (`cod_max_order_value`, string) when `unavailable_reason = ABOVE_LIMIT`, so the app can fill its own string instead of the English `message` | CA-21 | django-backend-dev (after the PM decision) |
| 2 | On cart lines, the previous selling price when it changed since the line was added (`previous_selling_price`, or a `PRICE_CHANGED` line issue with `details.before`) | CA-19 | django-backend-dev |
| 3 | Grievance officer details (name, designation, email, phone, response time) in `config/app`, or a CMS page slug `grievance` | CA-31 | django-backend-dev, Jivo legal |
| 4 | A refund preview for cancelling (amount, method, expected time), for example `cancel_refund_preview` on the order detail | CA-28 | django-backend-dev (with D-10) |
| 5 | Confirmation of whether an out-of-stock cart line's `line_total` is part of the bill, or should be sent as 0 / omitted | CA-18 | django-backend-dev |
| 6 | A push to the customer when items are marked unavailable (T8a), after D-19 | CA-27 | django-backend-dev |
| 7 | Nothing new for the active order card (CA-10), the freshness line (CA-26), the refund reason (CA-27), `marketing_opt_in` (CA-31) or the unread count (CA-34): the API already sends these; the app must use them | n/a | flutter-customer-dev |

## Implementation tasks

**flutter-customer-dev** (owner of `customer_app/` and `jivo_core`)

| Priority | Task | Findings / tokens |
|---|---|---|
| Before real customers | Address form: map pin first, carry the chosen pin over, prefill from reverse geocoding, select the new address | CA-07 |
| Before real customers | Active order card on Home | CA-10; `customer.color.brand.primaryContainer`, `text.primary` |
| Before real customers | Keep content on a failed refresh; retry on reconnect; banner after 2 network errors | CA-03, CA-02 |
| Before real customers | Stepper / ADD spinner after 300 ms | CA-17; `customer.motion.pendingSpinnerDelay` |
| Current phase | COD shown with its reason (after the PM decision); 503 copy by `codAvailable` | CA-21 |
| Current phase | Out-of-stock tile without opacity; stock pill | CA-11; `customer.color.stock.*` |
| Current phase | Non-veg triangle mark (after regulatory confirms) | CA-12; `customer.color.dietMark.*` |
| Current phase | PDP sticky price + ADD bar; tax line if legal confirms | CA-13; `customer.size.pdpActionBar`, `pdpStepperWidth` |
| Current phase | Large-text layouts: 1-column grid and chip rail ≥ 1.5×; Wrap for the order status row and the address label row; stacked cart line ≥ 1.3×; widget tests at 1.0/1.3/2.0× | CA-14, CA-24, CA-08, CA-18, CA-20; `customer.textScale.*` |
| Current phase | Price-changed notice on checkout (and on cart lines when API #2 lands) | CA-19; `customer.color.warning.tint` |
| Current phase | Payment-failed reassurance line (after Finance confirms the wording) and amount on Retry | CA-22 |
| Current phase | Tracking: OTP above the map; freshness line; late copy | CA-25, CA-26; `customer.color.warning.tint`, `success.fg`, `customer.motion.etaLateAfter` |
| Current phase | Item-unavailable notice; refund `reason` in the model | CA-27 |
| Current phase | Ticket thread polling, scroll to newest, new-reply pill | CA-30; `customer.motion.ticketPoll` |
| Current phase | Grievance officer section (after API #3); promotional push switch | CA-31 |
| Later | Low findings | CA-01, CA-04, CA-05, CA-06, CA-09, CA-15, CA-16, CA-23, CA-28, CA-29, CA-32, CA-33, CA-34 |
| jivo_core | Pin the ColorScheme roles to the values in `design/tokens/customer.tokens.json` (`ColorScheme.fromSeed(...).copyWith(...)`), so contrast no longer depends on the seed algorithm; additive only | tokens |

**django-backend-dev:** API rows 1–6 above.

**catalog-data:** export banners at 1200×600 px with text inside the middle 80%, and product images 1:1 at about 1000×1000 px (CA-15).

## Questions for the PM

1. **COD visibility (CA-21):** may the app show Cash on Delivery greyed out with the reason, instead of hiding it? This changes `03 §2.9` and the schema description. If yes, what wording does Jivo want for `NOT_ALLOWED` (the account lost COD after refused deliveries)? It must not sound like an accusation.
2. **Failed UPI payments (CA-22):** what can the app promise about money that left the customer's account for an unpaid order: the time frame (bank reversal or Razorpay refund) and who to contact? Jivo Finance / Razorpay to confirm.
3. **Tax line (CA-13):** should product detail say "MRP inclusive of all taxes" (Legal Metrology)? Jivo legal to confirm.
4. **Non-veg symbol (CA-12):** confirm with Jivo regulatory that the non-veg mark must be the FSSAI 2020 brown triangle.
5. **Grievance officer (CA-31):** who is the grievance officer, and where should the details live (config or CMS)? Jivo legal.
6. **Login consent (CA-05):** is "By continuing, you agree to…" enough, or does Jivo legal want a checkbox (DPDP)? The rider app has the same question (rider audit, question 1).
7. **Brand copy (CA-04):** may the onboarding claims ("Genuine products, fresh stock, fair prices", "in minutes") stay until Jivo Marketing sends approved copy with the brand kit (H-19, D-06)?
8. **Delete account with an open order (CA-32):** block deletion while an order is in progress or a refund is pending, or allow it with a warning?
9. **Offline cache (CA-03):** `03 §2.1` says the cached home and catalog are shown read-only offline. Is a disk cache in scope before launch, or is "keep what's on screen" enough for v1?
10. **Out-of-stock lines (CA-18):** is an out-of-stock line's total included in "To pay" while it is flagged? (Checkout is blocked anyway, but the customer reads the bill.)
