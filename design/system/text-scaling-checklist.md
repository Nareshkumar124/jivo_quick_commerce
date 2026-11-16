# Text-scaling checklist (customer app and rider app)

- **Status:** ready to use. Version 1, 2026-11-10.
- **Owner:** ui-designer. **Used by:** flutter-customer-dev (`customer_app/`) and flutter-rider-dev (`rider_app/`), who turn each row of §4 into widget tests; QA uses §5 for the manual pass on the phone.
- **Sources:** the design rule "text scaling to 200% without breaking layouts" (`docs/09-nfr-security-compliance.md` §6, `docs/03-customer-app.md` §4); the audits `design/audits/2026-11-10-customer-app.md` (CA-xx), `design/audits/2026-11-10-rider-account.md` (RA-xx) and `design/audits/2026-11-04-rider-delivery.md` (RD-12); the screen specs in `design/screens/customer/` and `design/screens/rider/`.
- **Why it matters:** many customers and riders on budget Android phones use large system text. A layout that overflows is clipped in release builds, so a price, a status or a button can silently disappear.

## 1. The three test sizes

Every screen in §4 is tested at three text scales on a **360×640 dp** surface (the smallest common Android phone):

| Scale | Stands for |
|---|---|
| **1.0×** | default text |
| **1.3×** | Android "Large" font, and roughly the extra length of Hindi strings until real Hindi exists (D-24) |
| **2.0×** | the largest font setting (the design rule's 200%) |

Add **1.5×** for any screen whose layout switches at 1.5× (`customer.textScale.singleColumnFrom` in `design/tokens/customer.tokens.json`, and the rider screens that stack above 1.5×), so both sides of the switch are covered.

## 2. How to set the test up

**Surface.** Use 640 dp height, not a tall one. Several existing tests use 800 dp wide or 360×1600 dp surfaces; those catch row overflows but hide "the button was pushed off the screen" and "the bottom bar takes over the screen".

- **Customer app** (the existing `harness()` in `customer_app/test/helpers/widget_harness.dart` already takes `textScaler`):

  ```dart
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('order detail fits at $scale×', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920); // 360×640 dp
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(const OrderDetailScreen(orderId: 1),
            textScaler: TextScaler.linear(scale), overrides: [/* fakes */]),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull); // no RenderFlex overflow
    });
  }
  ```

- **Rider app:** follow `rider_app/test/features/shift/presentation/home_screen_test.dart` (the "200 % text on 360×640" test): `h.surface = const Size(945, 1680)` (360×640 dp at 2.625) and `tester.platformDispatcher.textScaleFactorTestValue = scale`, with `addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue)`.

## 3. What every test checks

| # | Check | How |
|---|---|---|
| 1 | No overflow | `expect(tester.takeException(), isNull)` after `pumpAndSettle()` |
| 2 | The main action is on the screen and big enough | `tester.getRect(find.byKey(primaryKey))` lies inside the 640 dp view (or becomes visible after `scrollUntilVisible` when the action is inside a scrolling body, as the spec says); height ≥ 48 dp (customer) or ≥ 56 dp (rider primary actions) |
| 3 | Bottom areas don't take over | the combined height of bars pinned at the bottom (cart bar, checkout bar, `PrimaryActionBar`, the PDP bar) is ≤ 50% of the view height |
| 4 | Information that must not be cut is complete | `find.text(fullString)` for statuses, amounts, OTP digits and error messages; only lines the spec allows to ellipsize may end in "…" |
| 5 | Minimum font size (rider task, cash, earnings and home screens) | every `Text` style ≥ 14 sp, as the existing rider home test does |
| 6 | Accessibility guidelines (at 1.0× only) | `await expectLater(tester, meetsGuideline(androidTapTargetGuideline));` and `labeledTapTargetGuideline`; `textContrastGuideline` where backgrounds are plain colours |

A screen **passes** when all its states in §4 pass checks 1–4 at every scale (and 5–6 where listed).

## 4. Screens to cover

Tick a box when the widget test exists and passes. "State" says what to pump; "Watch for" is the risk the audit found.

### 4.1 Customer app

| Screen (file) | State to pump | Watch for | Finding / spec | 1.0× | 1.3× | 2.0× |
|---|---|---|---|---|---|---|
| Order detail (`features/orders/presentation/order_detail_screen.dart:145-153`) | `PACKED` (longest label "Packed, rider on the way to store") and `OUT_FOR_DELIVERY` with OTP and COD | status chip + date row overflow from about 1.1× | CA-24 | [ ] | [ ] | [ ] |
| Address list (`features/addresses/presentation/address_screens.dart:103-121`) | an address that is both "Not serviceable" and "Default" | label row with two chips overflows at 1.3× | CA-08 | [ ] | [ ] | [ ] |
| Address form (`address_screens.dart`, spec `design/screens/customer/address-form-with-map-pin.md`) | "No pin", "Permission blocked", "Pin set on the map" | pin card buttons, label chips | CA-07 | [ ] | [ ] | [ ] |
| Product list (`features/catalog/presentation/product_list_screen.dart`) | category with sub-categories, long product names | 2-column grid and 76 dp rail; one column and chip rail from 1.5× (add a 1.5× case) | CA-14 | [ ] | [ ] | [ ] |
| Product tile and rails (`features/catalog/presentation/widgets/product_tile.dart:20-27`) | in stock, low stock, out of stock, several variants | tile height formula; the out-of-stock pill | CA-11, CA-14 (extend `product_tile_test.dart` to 360 dp wide) | [ ] | [ ] | [ ] |
| Product detail + sticky bar (spec `design/screens/customer/pdp-sticky-action-bar.md`) | in cart with the price-updated notice; cart bar showing | stacked bar from 1.5×; bottom area ≤ 50% | CA-13 | [ ] | [ ] | [ ] |
| Home (`features/home/presentation/home_screen.dart`, spec `home-active-order-card.md`) | active order `OUT_FOR_DELIVERY` + pending-payment banner + store closed | header, active order card, banners stacking | CA-10 | [ ] | [ ] | [ ] |
| Cart (`features/cart/presentation/cart_screen.dart`, `widgets/cart_line_tile.dart`) | a line with an issue and total "₹1,24,999"; checkout blocked | line stacks from 1.3×; checkout bar stacks from 1.5× (extend `cart_screen_test.dart` from 360×1600 to 360×640 and add 1.3×) | CA-18, CA-20 | [ ] | [ ] | [ ] |
| Coupon sheet (`features/cart/presentation/widgets/coupon_sheet.dart`) | code field with an error + list of 3 coupons | the field + Apply row | general | [ ] | [ ] | [ ] |
| Checkout (`features/checkout/presentation/checkout_screen.dart:184-238`) | online selected, "Confirming your payment…", a blocker | bottom bar height | CA-20 | [ ] | [ ] | [ ] |
| Payment failed (`features/checkout/presentation/payment_failed_screen.dart`) | `PAYMENT_PENDING` with Retry, Change method, Cancel | all three actions reachable | general | [ ] | [ ] | [ ] |
| Cancel order sheet (`features/orders/presentation/cancel_order_sheet.dart`) | reason chosen, error shown | confirm and "Keep order" reachable | general | [ ] | [ ] | [ ] |
| Tracking (spec `design/screens/customer/tracking-layout.md`) | `OUT_FOR_DELIVERY` with OTP and COD; late; stale | OTP on the first screen; digits on one line | CA-25, CA-26 | [ ] | [ ] | [ ] |
| Force update and maintenance (`features/launch/presentation/app_control_screens.dart`) | 426 with store link; maintenance with a long message | the only button reachable (scrolls today; keep it so) | RA-01 note | [ ] | [ ] | [ ] |
| App shell (`app/app_shell.dart`) | cart not empty on Home | cart bar + navigation bar height | general | [ ] | [ ] | [ ] |

### 4.2 Rider app

| Screen (file) | State to pump | Watch for | Finding / spec | 1.0× | 1.3× | 2.0× |
|---|---|---|---|---|---|---|
| Blocking screens: force update, maintenance, splash error, status (`features/launch/presentation/blocking_message.dart:25-49`) | longest body text | fixed `Column` with two `Spacer`s; the button pushed off screen | RA-01 | [ ] | [ ] | [ ] |
| Documents (`features/onboarding/presentation/documents_screen.dart:158` `_DocumentTile`) | one tile per state: needed, in review, approved, rejected with a note | name squeezed by the action word | RA-05 | [ ] | [ ] | [ ] |
| Home status card and deposit banner (`features/shift/presentation/online_toggle.dart`) | online with a long store name; prepaid only with the banner | 2-line cap on the status body; banner title row | RA-13, home spec | [ ] | [ ] | [ ] |
| Home online control (existing test `home_screen_test.dart:262`) | offline, online, task active | keep as the model test | home spec §10 | [ ] | [ ] | [x] |
| Permissions gate (`features/permissions/presentation/permissions_gate_screen.dart:209` `_GateRow`) | one row blocked, one done | trailing status squeezes the title | RA-15 | [ ] | [ ] | [ ] |
| Label/value rows: history detail, earnings, cash, payouts (`history_detail_screen.dart:107-117`, `earnings_screen.dart:274-287`, `cash_screen.dart:172-201`, `payouts_screen.dart:60-91`) | long dates and amounts | value text that doesn't shrink; stack above 1.5× (add a 1.5× case) | RA-16 | [ ] | [ ] | [ ] |
| Task steps (`shared/widgets/primary_action_bar.dart`, spec `design/screens/rider/task-step-shell.md`) | each step with an error line and secondaries | bar ≤ 50% (now capped at `:111`); keep as a regression test | RD-12 | [ ] | [ ] | [ ] |
| Offer (`features/offers/presentation/offer_screen.dart:332-341`, spec `offer.md`) | countdown at 8 s with COD | ring grows with the text | RD-12 | [ ] | [ ] | [ ] |
| COD confirm dialog (spec `design/screens/rider/cod.md`) | the "Collected ₹1,240?" dialog | buttons stack at large text, "Yes" at the bottom | cod spec | [ ] | [ ] | [ ] |

"[x]" marks a case an existing test already covers at 360×640 (the rider home control at 2.0×). Other existing scale tests (`customer_app/test/features/cart/cart_screen_test.dart:387`, `customer_app/test/features/catalog/product_tile_test.dart:296`) use other surface sizes, so they are not ticked.

## 5. Manual pass on the phone (QA)

Once per release candidate, on the test phone (Realme, about 360 dp wide):
1. Settings → Display → Font size: largest. Display size: default.
2. Customer app: Home → a product → ADD → Cart → Checkout → an order's detail → Tracking. Rider app: Home → Documents → Earnings → Cash → History detail.
3. On every screen: nothing cut off, every button reachable, amounts and statuses complete.
4. Repeat with Display size: largest (this shrinks the dp width further).
5. Note failures with a screenshot in a QA bug, naming the row of §4.

## 6. Rules the tests protect (from the specs)

- Rows that hold two variable texts (status + date, label + value, name + stepper) **wrap or stack** from 1.3× (`customer.textScale.stackRowsFrom`).
- Grids become one column and side rails become chip rows from 1.5×.
- Bottom-pinned areas are capped at 50% of the height and scroll inside, with the main action always visible.
- OTP digits and amounts never break across lines; they scale down to fit (`FittedBox`) instead.
- No fixed heights around text. Heights that must grow use `minimumSize` / `minHeight`, never `height`.
