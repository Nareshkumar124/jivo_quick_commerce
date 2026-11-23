import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/app/theme.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/home/presentation/home_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import '../catalog/catalog_fixtures.dart';

/// The fake server, recording every `(variant, quantity)` sent.
class _RecordingCart extends FakeCommerceBackend {
  _RecordingCart() : super(latency: Duration.zero);

  final sent = <(int, int)>[];

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) {
    sent.add((variantId, quantity));
    return super.setQuantity(variantId, quantity, preview: preview);
  }
}

/// Water sold by the box: at least 5 per order, with wholesale prices.
CatalogProduct _water({int orderable = 200, int? unitsLeft}) => CatalogProduct(
  id: 15,
  slug: 'jivo-water',
  name: 'Jivo Packaged Drinking Water 1 L',
  defaultVariantId: 1501,
  variants: [
    CatalogVariant(
      id: 1501,
      name: '1 L x 12',
      sellingPrice: '90.00',
      mrp: '100.00',
      discountAmount: '10.00',
      discountPercent: 10,
      stockStatus: unitsLeft == null
          ? StockStatus.inStock
          : StockStatus.lowStock,
      unitsLeft: unitsLeft,
      orderableQuantity: orderable,
      maxQtyPerOrder: 1000,
      minQtyPerOrder: 5,
      priceTiers: const [
        PriceTier(minOrderUnits: 5, price: '90.00'),
        PriceTier(minOrderUnits: 50, price: '85.00'),
        PriceTier(minOrderUnits: 250, price: '80.00'),
      ],
    ),
  ],
);

Future<_RecordingCart> _pumpCard(
  WidgetTester tester,
  CatalogProduct product, {
  bool cartAvailable = true,
}) async {
  final cart = _RecordingCart();
  await tester.pumpWidget(
    harness(
      Theme(
        data: buildCustomerTheme(),
        child: Builder(
          builder: (context) => Center(
            child: SizedBox(
              width: 152,
              height: homeCardExtent(context, [product]),
              child: HomeProductCard(product: product),
            ),
          ),
        ),
      ),
      cartAvailable: cartAvailable,
      overrides: [cartRepositoryProvider.overrideWithValue(cart)],
    ),
  );
  await tester.pumpAndSettle();
  return cart;
}

String _qty(WidgetTester tester, int id) =>
    tester.widget<Text>(find.byKey(ValueKey('qty-$id'))).data!;

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initializeFormatting);

  group('ADD and the stepper (cart controller)', () {
    testWidgets('ADD adds the minimum in one tap; − and + step; − below the '
        'minimum removes the line', (tester) async {
      final cart = await _pumpCard(tester, _water());
      expect(find.text('Min 5'), findsOneWidget);
      expect(find.text('₹80 at 250+ cartons'), findsOneWidget);

      await _tap(tester, 'add-1501');
      expect(find.byKey(const Key('qty-dialog')), findsNothing);
      expect(_qty(tester, 1501), '5');

      await _tap(tester, 'step-plus-1501');
      expect(_qty(tester, 1501), '6');
      await _tap(tester, 'step-minus-1501');
      expect(_qty(tester, 1501), '5');
      // 4 is below the minimum: the controller removes the line instead.
      await _tap(tester, 'step-minus-1501');
      expect(find.byKey(const ValueKey('add-1501')), findsOneWidget);
      expect((await cart.load()).isEmpty, isTrue);
      // ADD asks for 1; the controller raises it to the minimum.
      expect(cart.sent, [(1501, 5), (1501, 6), (1501, 5), (1501, 0)]);
    });

    testWidgets('− at the minimum says "Removed" (also to screen readers); '
        'Undo restores the previous quantity', (tester) async {
      final cart = await _pumpCard(tester, _water());
      await _tap(tester, 'add-1501');
      await _tap(tester, 'step-plus-1501');
      await _tap(tester, 'step-minus-1501');
      expect(find.textContaining('Removed'), findsNothing);
      tester.takeAnnouncements();

      await _tap(tester, 'step-minus-1501');
      expect((await cart.load()).isEmpty, isTrue);
      const removed = 'Removed Jivo Packaged Drinking Water 1 L 1 L x 12';
      expect(find.text(removed), findsOneWidget);
      expect(tester.takeAnnouncements().map((a) => a.message), [removed]);

      await _tap(tester, 'home-undo-1501');
      expect(_qty(tester, 1501), '5');
      expect(cart.sent.last, (1501, 5));
    });

    testWidgets('tapping the number types a bulk quantity', (tester) async {
      final cart = await _pumpCard(tester, _water());
      await _tap(tester, 'add-1501');
      await _tap(tester, 'qty-edit-1501');
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('qty-field')), '120');
      await _tap(tester, 'qty-update');
      expect(_qty(tester, 1501), '120');
      expect((await cart.load()).quantityOf(1501), 120);
    });

    testWidgets('+ stops at the orderable quantity with the usual message', (
      tester,
    ) async {
      final cart = await _pumpCard(tester, _water(orderable: 6, unitsLeft: 6));
      await _tap(tester, 'add-1501');
      await _tap(tester, 'step-plus-1501');
      expect(_qty(tester, 1501), '6');
      await _tap(tester, 'step-plus-1501');
      expect(_qty(tester, 1501), '6');
      expect(find.text('You can add up to 6 of this item'), findsOneWidget);
      expect(cart.sent, [(1501, 5), (1501, 6)]);
    });

    testWidgets('several pack sizes: ADD opens the variant picker', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        product(
          variants: [
            variant(id: 101, name: '1 L'),
            variant(id: 102, name: '5 L'),
          ],
        ),
      );
      await _tap(tester, 'add-product-1');
      expect(find.byKey(const Key('variant-picker')), findsOneWidget);
    });

    testWidgets('without the cart (staging/prod): "Cart coming soon"', (
      tester,
    ) async {
      await _pumpCard(tester, _water(), cartAvailable: false);
      expect(find.byKey(const Key('cart-coming-soon')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-1501')), findsNothing);
    });

    testWidgets('ADD and the stepper buttons are 48 dp tall', (tester) async {
      await _pumpCard(tester, _water());
      expect(tester.getSize(find.byKey(const ValueKey('add-1501'))).height, 48);
      await _tap(tester, 'add-1501');
      for (final key in [
        'step-minus-1501',
        'step-plus-1501',
        'qty-edit-1501',
      ]) {
        expect(tester.getSize(find.byKey(ValueKey(key))).height, 48);
      }
    });
  });

  group('small screens and large text', () {
    // Every optional line on: MRP, "Min 5", bulk price, "Only N left".
    final rich = [
      _water(unitsLeft: 3, orderable: 3 + 5),
      product(),
      product(
        id: 2,
        name: 'Jivo Extra Light Olive Oil With A Very Long Product Name',
        variants: [
          variant(id: 201),
          variant(id: 202, name: '5 L'),
        ],
      ),
    ];

    for (final width in [320.0, 360.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        testWidgets('a rail of rich cards fits at ${width.toInt()} dp, '
            '${scale}x text, in and out of the cart', (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            harness(
              Theme(
                data: buildCustomerTheme(),
                child: HomeProductRail(items: rich),
              ),
              textScaler: TextScaler.linear(scale),
              overrides: [
                cartRepositoryProvider.overrideWithValue(_RecordingCart()),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await _tap(tester, 'add-1501');
          expect(tester.takeException(), isNull);
          expect(find.byKey(const ValueKey('step-plus-1501')), findsOneWidget);
        });

        testWidgets('the whole home fits at ${width.toInt()} dp, ${scale}x '
            'text', (tester) async {
          tester.view.physicalSize = Size(width, 640);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearAllTestValues);
          final app = TestApp(tokens: signedInTokens);
          await app.pump(tester);
          expect(find.byKey(const Key('home-header')), findsOneWidget);
          expect(find.byKey(const Key('home-search')), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (var i = 0; i < 14; i++) {
            await tester.drag(
              find.byType(CustomScrollView).first,
              const Offset(0, -500),
            );
            await tester.pump();
          }
          expect(tester.takeException(), isNull);
          expect(find.byType(HomeProductCard), findsWidgets);
        });
      }
    }

    testWidgets('the header is compact: ETA badge, address, above the fold', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);
      expect(find.byKey(const Key('home-eta-badge')), findsOneWidget);
      expect(find.text('Delivery in 14 mins'), findsOneWidget);
      // Header and search together stay under a fifth of a 640 dp screen
      // (plus the status bar inset, 0 in tests).
      final searchBottom = tester
          .getBottomLeft(find.byKey(const Key('home-search')))
          .dy;
      expect(searchBottom, lessThan(140));
      // A product card starts above the fold.
      expect(
        tester.getTopLeft(find.byType(HomeProductCard).first).dy,
        lessThan(640),
      );
    });
  });
}
