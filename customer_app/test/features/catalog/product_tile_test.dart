import 'dart:async';

import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/catalog/presentation/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/widget_harness.dart';
import 'catalog_fixtures.dart';

Future<InMemoryCartRepository> pumpTile(
  WidgetTester tester,
  CatalogProduct tile, {
  CartRepository? repository,
}) async {
  final cart = InMemoryCartRepository();
  await tester.pumpWidget(
    harness(
      Center(
        child: SizedBox(
          width: 160,
          height: 320,
          child: ProductTile(product: tile),
        ),
      ),
      overrides: [cartRepositoryProvider.overrideWithValue(repository ?? cart)],
    ),
  );
  await tester.pumpAndSettle();
  return cart;
}

String qty(WidgetTester tester, Object id) =>
    tester.widget<Text>(find.byKey(ValueKey('qty-$id'))).data!;

/// Holds every change until [release] (an in-flight request).
class SlowCartRepository implements CartRepository {
  final calls = <(int, int)>[];
  Completer<void> _gate = Completer<void>();

  void release() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<CartSnapshot> load() async => CartSnapshot.empty;

  @override
  Future<CartSnapshot> setQuantity(int variantId, int quantity) async {
    calls.add((variantId, quantity));
    await _gate.future;
    return CartSnapshot(quantities: {variantId: quantity}, itemCount: quantity);
  }

  @override
  Future<CartSnapshot> clear() async => CartSnapshot.empty;
}

void main() {
  testWidgets('shows name, variant, server price, struck MRP and discount', (
    tester,
  ) async {
    await pumpTile(tester, product());
    expect(find.text('Jivo Canola Oil'), findsOneWidget);
    expect(find.text('1 L'), findsOneWidget);
    expect(find.text('₹249'), findsOneWidget);
    final mrp = tester.widget<Text>(find.text('₹299'));
    expect(mrp.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('16% OFF'), findsOneWidget);
    expect(find.text('ADD'), findsOneWidget);
  });

  testWidgets('no badge or MRP when the server sends no discount', (
    tester,
  ) async {
    await pumpTile(
      tester,
      product(
        only: variant(
          price: '169.00',
          mrp: '169.00',
          discountAmount: '0.00',
          discountPercent: 0,
        ),
      ),
    );
    expect(find.text('₹169'), findsOneWidget);
    expect(find.textContaining('OFF'), findsNothing);
    expect(find.textContaining('₹'), findsOneWidget);
  });

  testWidgets('paise are shown only when non-zero', (tester) async {
    await pumpTile(
      tester,
      product(
        only: variant(price: '699.50', mrp: '799.00'),
      ),
    );
    expect(find.text('₹699.50'), findsOneWidget);
    expect(find.text('₹799'), findsOneWidget);
  });

  testWidgets('ADD becomes a stepper; plus and minus change the quantity', (
    tester,
  ) async {
    final cart = await pumpTile(tester, product());

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('ADD'), findsNothing);
    expect(qty(tester, 101), '1');

    await tester.tap(find.byKey(const ValueKey('inc-101')));
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '2');
    expect((await cart.load()).quantityOf(101), 2);

    await tester.tap(find.byKey(const ValueKey('dec-101')));
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '1');

    await tester.tap(find.byKey(const ValueKey('dec-101')));
    await tester.pumpAndSettle();
    expect(find.text('ADD'), findsOneWidget);
    expect((await cart.load()).isEmpty, isTrue);
  });

  testWidgets('plus stops at the orderable_quantity with a message', (
    tester,
  ) async {
    // max_qty_per_order 2: the server sends orderable_quantity 2.
    final cart = await pumpTile(
      tester,
      product(only: variant(orderable: 2, maxQty: 2)),
    );

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inc-101')));
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '2');

    await tester.tap(find.byKey(const ValueKey('inc-101')));
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '2');
    expect(find.text('You can add up to 2 of this item'), findsOneWidget);
    expect((await cart.load()).quantityOf(101), 2);
  });

  testWidgets('LOW_STOCK shows "Only N left" and caps at what is orderable', (
    tester,
  ) async {
    await pumpTile(
      tester,
      product(
        only: variant(status: StockStatus.lowStock, unitsLeft: 3, orderable: 3),
      ),
    );
    expect(find.text('Only 3 left'), findsOneWidget);

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('inc-101')));
      await tester.pumpAndSettle();
    }
    expect(qty(tester, 101), '3');
    expect(find.text('You can add up to 3 of this item'), findsOneWidget);
  });

  testWidgets('out of stock: greyed out, no ADD', (tester) async {
    await pumpTile(
      tester,
      product(only: variant(status: StockStatus.outOfStock, orderable: 0)),
    );
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('ADD'), findsNothing);
    expect(find.textContaining('left'), findsNothing);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.byType(Card), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('buttons are disabled while a change is in flight', (
    tester,
  ) async {
    final slow = SlowCartRepository();
    await pumpTile(tester, product(), repository: slow);

    await tester.tap(find.text('ADD'));
    await tester.pump();
    final add = tester.widget<OutlinedButton>(
      find.descendant(
        of: find.byKey(const ValueKey('add-101')),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(add.onPressed, isNull);
    expect(slow.calls, [(101, 1)]);

    slow.release();
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '1');
  });

  testWidgets('a server error is shown as a friendly message', (tester) async {
    final cart = InMemoryCartRepository()
      ..failNext = const ApiError(code: ApiErrorCode.stockUnavailable);
    await pumpTile(tester, product(), repository: cart);

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.text('ADD'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('with several variants, ADD opens the variant picker', (
    tester,
  ) async {
    final cart = await pumpTile(
      tester,
      product(
        variants: [
          variant(),
          variant(
            id: 102,
            name: '2 L',
            price: '479.00',
            mrp: '580.00',
            discountPercent: 17,
          ),
        ],
      ),
    );
    expect(find.text('1 L · 2 options'), findsOneWidget);

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('variant-picker')), findsOneWidget);
    expect(find.text('₹479'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-102')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('inc-102')));
    await tester.pumpAndSettle();
    expect((await cart.load()).quantityOf(102), 2);

    // Back on the tile: the total over all variants.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('variant-picker')), findsNothing);
    expect(qty(tester, 'product-1'), '2');
  });

  testWidgets('without a cart (staging/prod before P3): "Cart coming soon"', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        Center(
          child: SizedBox(
            width: 160,
            height: 320,
            child: ProductTile(product: product()),
          ),
        ),
        cartAvailable: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-coming-soon')), findsOneWidget);
    expect(find.text('ADD'), findsNothing);
    expect(find.text('₹249'), findsOneWidget);
  });

  testWidgets('touch targets are at least 48 dp', (tester) async {
    await pumpTile(tester, product());
    expect(tester.getSize(find.byKey(const ValueKey('add-101'))).height, 48);
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    for (final key in ['inc-101', 'dec-101']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('a phone-width grid does not overflow at ${scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [
              SliverProductGrid(
                items: [
                  product(
                    name: 'Jivo Extra Light Olive Oil with a long name',
                    only: variant(
                      status: StockStatus.lowStock,
                      unitsLeft: 2,
                      orderable: 2,
                    ),
                  ),
                  product(
                    id: 2,
                    variants: [
                      variant(id: 2),
                      variant(id: 3, name: '5 L'),
                    ],
                  ),
                  product(
                    id: 3,
                    only: variant(
                      id: 4,
                      status: StockStatus.outOfStock,
                      orderable: 0,
                    ),
                  ),
                  product(
                    id: 4,
                    only: variant(id: 5, discountPercent: 0, mrp: '249.00'),
                  ),
                ],
              ),
            ],
          ),
          overrides: [
            cartRepositoryProvider.overrideWithValue(InMemoryCartRepository()),
          ],
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
