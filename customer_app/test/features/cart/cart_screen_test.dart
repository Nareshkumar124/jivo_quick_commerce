import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/widgets/bill_details.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:customer_app/features/cart/presentation/widgets/price_tier_nudge_card.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import 'cart_fixtures.dart';

/// Tall enough to build the whole cart without scrolling.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Starts the app on Home and opens the cart.
Future<TestApp> openCart(WidgetTester tester, [TestApp? app]) async {
  tallView(tester);
  final started = app ?? TestApp(tokens: signedInTokens);
  await started.pump(tester);
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.cart);
  await tester.pumpAndSettle();
  return started;
}

/// Puts [quantity] × Jivo Canola Oil (₹249) in the fake server cart.
Future<TestApp> appWithOil({int quantity = 2, int orderable = 5}) async {
  final app = TestApp(tokens: signedInTokens);
  await app.cart.setQuantity(
    101,
    quantity,
    preview: CartLinePreview.of(oil(orderable: orderable), 'Jivo Canola Oil'),
  );
  return app;
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

/// Taps a cart line's quantity box, types [text] and taps Update (there is
/// no - or +).
Future<void> typeLineQty(
  WidgetTester tester,
  int variantId,
  String text,
) async {
  await tester.tap(find.byKey(ValueKey('qty-edit-line-$variantId')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('qty-field')), text);
  await tester.tap(find.byKey(const Key('qty-update')));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeFormatting);

  testWidgets('the bill is rendered exactly as the server sent it', (
    tester,
  ) async {
    // The fixture's numbers don't add up (₹999 to pay): a screen that sums
    // or derives money fails here.
    final stub = StubCartRepository(cartSnapshot());
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );

    expect(find.byType(BillDetails), findsOneWidget);
    expect(textOf(tester, 'bill-mrp-total'), '₹598');
    expect(textOf(tester, 'bill-product-discount'), '−₹100');
    expect(textOf(tester, 'bill-delivery-fee'), 'FREE');
    expect(textOf(tester, 'bill-handling-fee'), '₹5');
    expect(textOf(tester, 'bill-to-pay'), '₹999');
    expect(textOf(tester, 'checkout-bar-total'), '₹999');
    expect(textOf(tester, 'cart-line-total-101'), '₹498');
    // Zero rows are hidden; nothing the server didn't send is derived.
    for (final key in ['coupon-discount', 'small-cart-fee', 'tip']) {
      expect(find.byKey(ValueKey('bill-$key')), findsNothing, reason: key);
    }
    expect(find.byKey(const Key('bill-savings')), findsNothing);
    expect(find.byKey(const Key('free-delivery-nudge')), findsNothing);
    expect(stub.calls, contains('load:1')); // priced for the saved address
  });

  testWidgets('savings and the free-delivery nudge come from the server', (
    tester,
  ) async {
    final stub = StubCartRepository(
      cartSnapshot(
        bill: const CartBill(
          mrpTotal: '160.00',
          itemTotal: '148.00',
          productDiscount: '12.00',
          couponDiscount: '10.00',
          deliveryFee: '25.00',
          smallCartFee: '15.00',
          handlingFee: '5.00',
          tip: '20.00',
          grandTotal: '203.00',
          totalSavings: '77.00',
        ),
        thresholds: const CartThresholds(
          minOrderValue: '49.00',
          freeDeliveryThreshold: '199.00',
          amountToFreeDelivery: '51.00',
        ),
        coupon: const AppliedCoupon(
          code: 'WELCOME10',
          title: '10% off',
          discount: '10.00',
        ),
      ),
    );
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );

    expect(textOf(tester, 'bill-coupon-discount'), '−₹10');
    expect(find.text('Coupon (WELCOME10)'), findsOneWidget);
    expect(textOf(tester, 'bill-delivery-fee'), '₹25');
    expect(textOf(tester, 'bill-small-cart-fee'), '₹15');
    expect(textOf(tester, 'bill-tip'), '₹20');
    expect(find.text('You save ₹77 on this order'), findsOneWidget);
    expect(find.text('Add ₹51 more for FREE delivery'), findsOneWidget);
    expect(find.text('WELCOME10 applied'), findsOneWidget);
  });

  testWidgets('an empty cart shows the empty state', (tester) async {
    await openCart(tester);
    expect(find.byKey(const Key('cart-empty')), findsOneWidget);
    expect(find.byKey(const Key('proceed-to-checkout')), findsNothing);

    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a failed load shows retry, and retry loads the cart', (
    tester,
  ) async {
    final stub = StubCartRepository(cartSnapshot())
      ..loadError = const ApiError(code: ApiErrorCode.network);
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(find.text('Retry'), findsOneWidget);

    stub.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-content')), findsOneWidget);
  });

  testWidgets('a line with less stock is flagged, fixed, and blocks checkout', (
    tester,
  ) async {
    final app = await appWithOil(quantity: 4);
    app.cart.stock[101] = 2;
    await openCart(tester, app);

    expect(find.byKey(const Key('cart-problems')), findsOneWidget);
    expect(find.text('Only 2 available'), findsOneWidget);
    final proceed = find.byKey(const Key('proceed-to-checkout'));
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(of: proceed, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Update to 2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-problems')), findsNothing);
    expect(find.text('2', skipOffstage: false), findsWidgets);
    expect((await app.cart.load()).lines.single.quantity, 2);
  });

  testWidgets("a server blocker disables checkout and says why", (
    tester,
  ) async {
    // The server's blocker decides; the text is the app's, filled with the
    // server's amounts (`thresholds`).
    final stub = StubCartRepository(
      cartSnapshot(
        thresholds: const CartThresholds(
          minOrderValue: '99.00',
          amountToMinOrder: '20.00',
        ),
        checkout: const CheckoutStatus(
          canPlaceOrder: false,
          blockers: [
            CheckoutBlocker(
              code: CheckoutBlockerCode.minOrderNotMet,
              message: 'server text',
            ),
          ],
        ),
      ),
    );
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(
      find.text('Minimum order is ₹99. Add ₹20 more to check out.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('proceed-to-checkout')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  group('minimum units per order (any mix of products)', () {
    Future<TestApp> waterApp(Map<int, int> lines) async {
      final app = TestApp(
        tokens: signedInTokens,
        commerce: FakeCommerceBackend(
          latency: Duration.zero,
          rules: const FakeBillRules(
            minimumUnits: 5,
            orderUnitLabel: 'cartons',
          ),
        ),
      );
      for (final MapEntry(key: id, value: quantity) in lines.entries) {
        await app.cart.setQuantity(
          id,
          quantity,
          preview: CartLinePreview.of(oil(id: id), 'Jivo Water $id'),
        );
      }
      // A saved address, so the units rule is the only blocker.
      await app.cart.update(const CartUpdate(addressId: 1));
      return app;
    }

    Finder notice(String text) => find.descendant(
      of: find.byKey(const Key('min-units-warning')),
      matching: find.text(text),
    );

    FilledButton proceed(WidgetTester tester) => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('proceed-to-checkout')),
        matching: find.byType(FilledButton),
      ),
    );

    testWidgets('short of the minimum: a clear warning, checkout blocked; '
        'adding more clears it', (tester) async {
      final app = await waterApp({1501: 2, 1502: 1});
      await openCart(tester, app);

      const warning =
          'Add 2 more cartons to place your order (minimum 5 cartons)';
      expect(notice(warning), findsOneWidget, reason: 'the cart notice');
      expect(textOf(tester, 'checkout-blocked'), warning, reason: 'blocker');
      expect(proceed(tester).onPressed, isNull);

      await typeLineQty(tester, 1502, '2');
      expect(
        notice('Add 1 more to place your order (minimum 5 cartons)'),
        findsOneWidget,
      );

      await typeLineQty(tester, 1501, '3');
      expect(find.byKey(const Key('min-units-warning')), findsNothing);
      expect(find.byKey(const Key('checkout-blocked')), findsNothing);
      expect(proceed(tester).onPressed, isNotNull);
    });

    testWidgets('rule off: no warning', (tester) async {
      await openCart(tester, await appWithOil(quantity: 1));
      expect(find.byKey(const Key('min-units-warning')), findsNothing);
    });
  });

  group('wholesale (volume) prices', () {
    const tiers = [
      PriceTier(minOrderUnits: 5, price: '90.00'),
      PriceTier(minOrderUnits: 25, price: '87.00'),
      PriceTier(minOrderUnits: 50, price: '85.00'),
    ];

    /// A water line as the server sends it. Its total deliberately does
    /// not equal rate × quantity: the screen must show the server's.
    CartLine water({
      int id = 1,
      int variantId = 1501,
      String variantName = '1 L',
      int quantity = 30,
      String rate = '87.00',
      PriceTier? tier = const PriceTier(minOrderUnits: 25, price: '87.00'),
      String? next,
    }) => cartLine(
      id: id,
      variantId: variantId,
      name: 'Jivo Water',
      variantName: variantName,
      price: '90.00',
      mrp: '90.00',
      quantity: quantity,
      lineTotal: '2611.00',
      lineMrpTotal: '2700.00',
      orderable: 300,
      priceTiers: tiers,
      pricePerUnit: rate,
      priceTier: tier,
      nextTierPrice: next,
    );

    Future<void> openWith(
      WidgetTester tester,
      List<CartLine> lines, {
      NextPriceTier? next,
      int? unitsToMinOrder,
    }) => openCart(
      tester,
      TestApp(
        tokens: signedInTokens,
        cartRepository: StubCartRepository(
          cartSnapshot(
            lines: lines,
            thresholds: CartThresholds(
              minOrderValue: '0.00',
              minOrderUnits: 5,
              unitsToMinOrder: unitsToMinOrder,
              orderUnitLabel: 'boxes',
              tierUnits: 22,
              nextPriceTier: next,
            ),
          ),
        ),
      ),
    );

    String? nudge(WidgetTester tester) {
      final finder = find.descendant(
        of: find.byKey(const Key('price-tier-nudge')),
        matching: find.byType(Text),
      );
      if (finder.evaluate().isEmpty) return null;
      final texts = [
        for (final e in finder.evaluate()) (e.widget as Text).data,
      ];
      return texts.where((t) => t != 'Add more').join(' ');
    }

    testWidgets('a line shows the billed rate per box and the server total', (
      tester,
    ) async {
      await openWith(tester, [water()]);

      expect(textOf(tester, 'cart-line-rate-1501'), '₹87/box');
      expect(find.byKey(const ValueKey('cart-line-tier-1501')), findsOneWidget);
      expect(find.text('Wholesale rate'), findsOneWidget);
      expect(textOf(tester, 'cart-line-total-1501'), '₹2,611');
      // The struck MRP (₹90) is the server's, not derived.
      expect(find.text('₹90'), findsOneWidget);
    });

    testWidgets('below the first slab: the normal rate, no tag', (
      tester,
    ) async {
      await openWith(tester, [water(quantity: 3, rate: '90.00', tier: null)]);
      expect(textOf(tester, 'cart-line-rate-1501'), '₹90/box');
      expect(find.byKey(const ValueKey('cart-line-tier-1501')), findsNothing);
    });

    testWidgets('items without tiers keep the plain price', (tester) async {
      await openWith(tester, [cartLine()]);
      expect(find.byKey(const ValueKey('cart-line-rate-101')), findsNothing);
      expect(find.text('₹249'), findsOneWidget);
    });

    testWidgets('the nudge names the size and its next price', (tester) async {
      await openWith(tester, [
        water(quantity: 22, rate: '90.00', next: '87.00'),
      ], next: const NextPriceTier(minOrderUnits: 25, unitsToNextTier: 3));
      expect(nudge(tester), 'Add 3 more boxes and pay ₹87/box on 1 L');
      expect(find.byKey(const Key('min-units-warning')), findsNothing);
    });

    testWidgets('one box away: "Add 1 more"', (tester) async {
      await openWith(tester, [
        water(quantity: 24, rate: '90.00', next: '87.00'),
      ], next: const NextPriceTier(minOrderUnits: 25, unitsToNextTier: 1));
      expect(nudge(tester), 'Add 1 more and pay ₹87/box on 1 L');
    });

    testWidgets('several sizes get cheaper: one generic line', (tester) async {
      await openWith(tester, [
        water(quantity: 20, rate: '90.00', next: '87.00'),
        water(
          id: 2,
          variantId: 1502,
          variantName: '500 ml',
          quantity: 2,
          rate: '125.00',
          next: '122.00',
        ),
      ], next: const NextPriceTier(minOrderUnits: 25, unitsToNextTier: 3));
      expect(nudge(tester), 'Add 3 more boxes and pay less per box');
    });

    testWidgets('the piggy card is first, above the items, with Add more', (
      tester,
    ) async {
      await openWith(tester, [
        water(quantity: 22, rate: '90.00', next: '87.00'),
      ], next: const NextPriceTier(minOrderUnits: 25, unitsToNextTier: 3));
      final card = tester.getTopLeft(find.byKey(const Key('price-tier-nudge')));
      final line = tester.getTopLeft(
        find.byKey(const ValueKey('cart-line-rate-1501')),
      );
      expect(card.dy, lessThan(line.dy));
      expect(find.byKey(const Key('price-tier-add-more')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('price-tier-nudge'))),
        matchesSemantics(
          label: 'Add 3 more boxes to get ₹87/box on 1 L',
          isLiveRegion: true,
        ),
      );
    });

    testWidgets('the piggy card fits 360 dp at 2x text', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PriceTierNudgeCard(
                key: const Key('price-tier-nudge'),
                headline: 'Add 300 more cartons',
                detail: 'and pay ₹87/box on 1 L',
                semanticsLabel: 'x',
                onAddMore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('price-tier-nudge')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Add more stays reachable for TalkBack', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PriceTierNudgeCard(
              headline: 'Add 3 more boxes',
              detail: 'and pay less per box',
              semanticsLabel: 'Add 3 more boxes and pay less per box',
              onAddMore: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Add more'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no next slab (top tier or no tiers): no nudge', (
      tester,
    ) async {
      await openWith(tester, [water(quantity: 260, rate: '80.00')]);
      expect(find.byKey(const Key('price-tier-nudge')), findsNothing);
    });

    testWidgets('below the minimum: only the minimum warning', (tester) async {
      await openWith(
        tester,
        [water(quantity: 4, rate: '90.00', tier: null, next: '87.00')],
        next: const NextPriceTier(minOrderUnits: 25, unitsToNextTier: 21),
        unitsToMinOrder: 1,
      );
      expect(find.byKey(const Key('price-tier-nudge')), findsNothing);
      expect(find.byKey(const Key('min-units-warning')), findsOneWidget);
    });

    testWidgets('on the fake server: rates and nudge follow the box total', (
      tester,
    ) async {
      final app = TestApp(
        tokens: signedInTokens,
        commerce: FakeCommerceBackend(
          latency: Duration.zero,
          rules: const FakeBillRules(minimumUnits: 5, orderUnitLabel: 'boxes'),
        ),
      );
      CatalogVariant size(int id, String name, String price) => CatalogVariant(
        id: id,
        name: name,
        sellingPrice: price,
        mrp: price,
        stockStatus: StockStatus.inStock,
        orderableQuantity: 300,
        maxQtyPerOrder: 300,
        priceTiers: id == 1502
            ? const [
                PriceTier(minOrderUnits: 5, price: '125.00'),
                PriceTier(minOrderUnits: 25, price: '122.00'),
              ]
            : tiers,
      );
      await app.cart.setQuantity(
        1501,
        20,
        preview: CartLinePreview.of(size(1501, '1 L', '90.00'), 'Jivo Water'),
      );
      await app.cart.update(const CartUpdate(addressId: 1));
      await openCart(tester, app);

      expect(textOf(tester, 'cart-line-rate-1501'), '₹90/box');
      expect(nudge(tester), 'Add 5 more boxes and pay ₹87/box on 1 L');

      // Any size counts towards the total: 21 + 5 = 26 boxes.
      await app.cart.setQuantity(
        1502,
        5,
        preview: CartLinePreview.of(
          size(1502, '500 ml', '125.00'),
          'Jivo Water',
        ),
      );
      await typeLineQty(tester, 1501, '21');
      expect(textOf(tester, 'cart-line-rate-1501'), '₹87/box');
      expect(textOf(tester, 'cart-line-rate-1502'), '₹122/box');
      expect(textOf(tester, 'cart-line-total-1501'), '₹1,827');
      expect(find.byKey(const ValueKey('cart-line-tier-1502')), findsOneWidget);
      // 50 is the next slab, and only the 1 L gets cheaper there.
      expect(nudge(tester), 'Add 24 more boxes and pay ₹85/box on 1 L');
    });
  });

  group('minimum per order', () {
    testWidgets('the line shows its minimum; below it is refused; 0 removes', (
      tester,
    ) async {
      final app = TestApp(tokens: signedInTokens);
      await app.cart.setQuantity(
        1501,
        5,
        preview: CartLinePreview.of(
          oil(id: 1501, minQty: 5),
          'Jivo Water 1 L x 12',
        ),
      );
      await openCart(tester, app);
      expect(find.text('Minimum 5 per order'), findsOneWidget);

      await typeLineQty(tester, 1501, '4');
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('qty-field')), '0');
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
      expect((await app.cart.load()).isEmpty, isTrue);
      expect(find.byKey(const Key('cart-empty')), findsOneWidget);
    });

    testWidgets('min 1 lines show no hint', (tester) async {
      await openCart(tester, await appWithOil());
      expect(find.textContaining('per order'), findsNothing);
    });

    testWidgets('a line below a raised minimum is flagged, fixed to the '
        'minimum, and blocks checkout', (tester) async {
      final app = await appWithOil();
      app.cart.minimums[101] = 5;
      await openCart(tester, app);

      expect(find.text('Order at least 5'), findsOneWidget);
      expect(
        find.text(
          'Some items are below their minimum quantity. Fix them to continue.',
        ),
        findsOneWidget,
      );
      expect(find.text('Minimum 5 per order'), findsNothing, reason: 'flag');
      final proceed = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('proceed-to-checkout')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(proceed.onPressed, isNull);

      await tester.tap(find.text('Update to 5'));
      await tester.pumpAndSettle();
      expect((await app.cart.load()).quantityOf(101), 5);
      expect(find.text('Order at least 5'), findsNothing);
      expect(find.text('Minimum 5 per order'), findsOneWidget);
    });
  });

  testWidgets('with a saved address, a quantity change never asks to save '
      'the location (staging bug)', (tester) async {
    // The test location is saved address 1; the cart loads ?address_id=1.
    await openCart(tester, await appWithOil());
    FilledButton proceed() => tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('proceed-to-checkout')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(find.byKey(const Key('checkout-blocked')), findsNothing);
    expect(proceed().onPressed, isNotNull);

    for (final key in ['3', '2']) {
      await typeLineQty(tester, 101, key);
      expect(
        find.byKey(const Key('checkout-blocked')),
        findsNothing,
        reason: key,
      );
      expect(proceed().onPressed, isNotNull, reason: key);
    }
  });

  testWidgets('a cart line quantity can be typed; above the cap is refused', (
    tester,
  ) async {
    final app = await appWithOil(); // 2 in the cart, orderable 5
    await openCart(tester, app);
    Future<void> type(String text) async {
      await tester.tap(find.byKey(const ValueKey('qty-line-101')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('qty-field')), text);
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
    }

    await type('6');
    expect(find.text('You can add up to 5 of this item'), findsOneWidget);
    await tester.tap(find.byKey(const Key('qty-cancel')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(101), 2);

    await type('4');
    expect((await app.cart.load()).quantityOf(101), 4);
    expect(textOf(tester, 'qty-line-101'), '4');
    expect(find.byKey(const Key('checkout-blocked')), findsNothing);

    await type('0');
    expect(find.byKey(const Key('cart-empty')), findsOneWidget);
  });

  testWidgets('the quantity box and remove change the server cart', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);
    expect(find.byIcon(Icons.add), findsNothing, reason: 'no - or +');

    await typeLineQty(tester, 101, '3');
    expect((await app.cart.load()).quantityOf(101), 3);
    expect(textOf(tester, 'cart-line-total-101'), '₹747');

    await tester.tap(find.byKey(const ValueKey('cart-line-remove-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).isEmpty, isTrue);
    expect(find.byKey(const Key('cart-empty')), findsOneWidget);
  });

  testWidgets('coupons: reasons, apply and remove', (tester) async {
    final app = await appWithOil(); // ₹498 of items
    await openCart(tester, app);

    await tester.tap(find.byKey(const Key('apply-coupon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coupon-sheet')), findsOneWidget);
    expect(find.text('Save ₹50 on this order'), findsOneWidget);
    // The server lists no expired or used-up coupons.
    expect(find.byKey(const ValueKey('coupon-OILFEST')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('coupon-apply-JIVO50')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coupon-sheet')), findsNothing);
    expect(find.text('JIVO50 applied. You save ₹50.'), findsOneWidget);
    expect(find.text('JIVO50 applied'), findsOneWidget);
    expect(textOf(tester, 'bill-coupon-discount'), '−₹50');

    // The sheet marks the coupon on the cart as applied.
    await tester.tap(find.byKey(const Key('applied-coupon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coupon-applied-JIVO50')), findsOneWidget);
    expect(find.byKey(const ValueKey('coupon-apply-JIVO50')), findsNothing);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('remove-coupon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('apply-coupon')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-coupon-discount')), findsNothing);
  });

  testWidgets("a typed code shows the server's reason under the field", (
    tester,
  ) async {
    final app = await appWithOil(quantity: 1); // ₹249, below JIVO50's ₹299
    await openCart(tester, app);
    await tester.tap(find.byKey(const Key('apply-coupon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a coupon code'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coupon-code')), 'nope');
    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text("This coupon code isn't valid."), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coupon-code')), 'oilfest');
    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('This coupon has expired.'), findsOneWidget);

    // COUPON_NOT_ELIGIBLE with details.amount_to_unlock.
    await tester.enterText(find.byKey(const Key('coupon-code')), 'jivo50');
    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('coupon-code')),
        matching: find.text('Add ₹50 more to use this coupon'),
      ),
      findsOneWidget,
    );
    // The listed coupon says the same, from its amount_to_unlock.
    expect(find.byKey(const ValueKey('coupon-problem-JIVO50')), findsOneWidget);
    expect(find.byKey(const Key('coupon-sheet')), findsOneWidget);
  });

  testWidgets('tip chips set and clear the tip; custom asks for an amount', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const ValueKey('tip-20')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'bill-tip'), '₹20');
    expect((await app.cart.load()).bill!.tip, '20.00');

    await tester.tap(find.byKey(const ValueKey('tip-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bill-tip')), findsNothing);

    await tester.tap(find.byKey(const Key('tip-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tip-custom-field')), '0');
    await tester.tap(find.byKey(const Key('tip-custom-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole amount from ₹1 to ₹500'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tip-custom-field')), '45');
    await tester.tap(find.byKey(const Key('tip-custom-save')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'bill-tip'), '₹45');
    expect(
      find.descendant(
        of: find.byKey(const Key('tip-custom')),
        matching: find.text('₹45'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('instruction chips and the note go to the server', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const ValueKey('instruction-LEAVE_AT_DOOR')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).instructions.tags, {
      InstructionTag.leaveAtDoor,
    });

    await tester.enterText(
      find.byKey(const Key('instructions-note')),
      'Gate code 1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('instructions-save')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).instructions.note, 'Gate code 1234');
    expect(find.text('Instructions saved'), findsOneWidget);
    expect(find.byKey(const Key('instructions-save')), findsNothing);
  });

  testWidgets('proceed re-validates the cart, then opens checkout', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const Key('proceed-to-checkout')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('proceed stops when re-validation finds a stock change', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    app.cart.stock[101] = 0; // sold out since the cart was opened
    await tester.tap(find.byKey(const Key('proceed-to-checkout')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(
      find.text('Some items in your cart changed. Please review them.'),
      findsOneWidget,
    );
    expect(find.text('Out of stock'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('line and bill fit at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CartLineTile(
                line: cartLine(
                  name: 'Jivo Cold Pressed Canola Oil Pouch',
                  orderable: 1,
                  issue: CartIssueCode.quantityUnavailable,
                ),
              ),
              const BillDetails(bill: inconsistentBill),
            ],
          ),
          overrides: [
            cartRepositoryProvider.overrideWithValue(
              StubCartRepository(cartSnapshot()),
            ),
          ],
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
