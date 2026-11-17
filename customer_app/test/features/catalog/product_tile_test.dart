import 'dart:async';

import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/cart_repository.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/catalog/presentation/widgets/price_tags.dart';
import 'package:customer_app/features/catalog/presentation/widgets/product_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/widget_harness.dart';
import 'catalog_fixtures.dart';

Future<FakeCommerceBackend> pumpTile(
  WidgetTester tester,
  CatalogProduct tile, {
  CartRepository? repository,
}) async {
  final cart = FakeCommerceBackend(latency: Duration.zero);
  await tester.pumpWidget(
    harness(
      Center(
        child: SizedBox(
          width: 160,
          height: 380,
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

/// The quantity box (there is no - or +).
Finder box(Object id) => find.byKey(ValueKey('qty-edit-$id'));

/// What the "Enter quantity" field holds.
String fieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(const Key('qty-field')))
    .controller!
    .text;

/// Opens the "Enter quantity" dialog with [open] (ADD or the quantity box),
/// types [text] (or keeps what is prefilled) and taps Update. With
/// [settle] false, only one frame is drawn after the tap.
Future<void> setQty(
  WidgetTester tester,
  Finder open, {
  String? text,
  bool settle = true,
}) async {
  await tester.tap(open);
  await tester.pumpAndSettle();
  if (text != null) {
    await tester.enterText(find.byKey(const Key('qty-field')), text);
  }
  await tester.tap(find.byKey(const Key('qty-update')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Holds every change until [release] (an in-flight request).
class SlowCartRepository extends FakeCommerceBackend {
  SlowCartRepository() : super(latency: Duration.zero);

  final calls = <(int, int)>[];
  Completer<void> _gate = Completer<void>();

  void release() {
    _gate.complete();
    _gate = Completer<void>();
  }

  @override
  Future<CartSnapshot> setQuantity(
    int variantId,
    int quantity, {
    CartLinePreview? preview,
  }) async {
    calls.add((variantId, quantity));
    await _gate.future;
    return super.setQuantity(variantId, quantity, preview: preview);
  }
}

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

  testWidgets('ADD opens the dialog; the quantity box changes and removes', (
    tester,
  ) async {
    final cart = await pumpTile(tester, product());

    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
    expect(fieldText(tester), '1', reason: 'prefilled with the minimum');
    await tester.tap(find.byKey(const Key('qty-update')));
    await tester.pumpAndSettle();
    expect(find.text('ADD'), findsNothing);
    expect(qty(tester, 101), '1');
    // One quantity box: no - or +.
    expect(find.byIcon(Icons.remove), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Quantity 1, tap to change'), findsOneWidget);

    await setQty(tester, box(101), text: '3');
    expect(qty(tester, 101), '3');
    expect((await cart.load()).quantityOf(101), 3);

    await setQty(tester, box(101), text: '0');
    expect(find.text('ADD'), findsOneWidget);
    expect((await cart.load()).isEmpty, isTrue);
  });

  testWidgets('above the orderable_quantity is refused in the dialog', (
    tester,
  ) async {
    // max_qty_per_order 2: the server sends orderable_quantity 2.
    final cart = await pumpTile(
      tester,
      product(only: variant(orderable: 2, maxQty: 2)),
    );

    await setQty(tester, find.text('ADD'), text: '3');
    expect(find.text('You can add up to 2 of this item'), findsOneWidget);
    expect((await cart.load()).isEmpty, isTrue);

    await tester.enterText(find.byKey(const Key('qty-field')), '2');
    await tester.tap(find.byKey(const Key('qty-update')));
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '2');
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
    await setQty(tester, find.text('ADD'), text: '4');
    expect(find.text('You can add up to 3 of this item'), findsOneWidget);
  });

  testWidgets('out of stock: only the image is greyed, pill, no ADD (CA-11)', (
    tester,
  ) async {
    await pumpTile(
      tester,
      product(only: variant(status: StockStatus.outOfStock, orderable: 0)),
    );
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.byKey(const Key('out-of-stock-pill')), findsOneWidget);
    expect(find.text('ADD'), findsNothing);
    expect(find.textContaining('left'), findsNothing);
    expect(
      find.ancestor(of: find.byType(Card), matching: find.byType(Opacity)),
      findsNothing,
      reason: 'the card is not dimmed, so its text keeps full contrast',
    );
    final image = tester.widget<OutOfStockImage>(find.byType(OutOfStockImage));
    expect(image.outOfStock, isTrue);
    expect(
      find.descendant(
        of: find.byType(OutOfStockImage),
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
    final name = tester.widget<Text>(find.text(product().name));
    expect(
      find.ancestor(of: find.byWidget(name), matching: find.byType(Opacity)),
      findsNothing,
    );
  });

  testWidgets('veg is a dot, non-veg a triangle (CA-12)', (tester) async {
    await tester.pumpWidget(
      harness(
        const Row(children: [VegMark(isVeg: true), VegMark(isVeg: false)]),
      ),
    );
    expect(find.byKey(const Key('veg-dot')), findsOneWidget);
    expect(find.byKey(const Key('non-veg-triangle')), findsOneWidget);
    expect(find.bySemanticsLabel('Vegetarian'), findsOneWidget);
    expect(find.bySemanticsLabel('Non-vegetarian'), findsOneWidget);
  });

  testWidgets('ADD ignores taps while a change is in flight', (tester) async {
    final slow = SlowCartRepository();
    await pumpTile(tester, product(), repository: slow);

    await setQty(tester, find.text('ADD'), settle: false);
    final add = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const ValueKey('add-101')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(add.onPressed, isNull);
    expect(slow.calls, [(101, 1)]);

    slow.release();
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '1');
  });

  testWidgets('CA-17: a slow change shows a spinner after 300 ms, never '
      'before, and the number only from the server', (tester) async {
    final slow = SlowCartRepository();
    await pumpTile(tester, product(), repository: slow);
    final add = find.byKey(const ValueKey('add-101'));
    Finder spinnerIn(Finder of) => find.descendant(
      of: of,
      matching: find.byType(CircularProgressIndicator),
    );

    await setQty(tester, find.text('ADD'), settle: false);
    await tester.pump(const Duration(milliseconds: 200));
    expect(spinnerIn(add), findsNothing, reason: 'no flash on a fast answer');
    expect(find.text('ADD'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(spinnerIn(add), findsOneWidget);
    expect(find.text('ADD'), findsNothing);

    slow.release();
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '1');
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await setQty(tester, box(101), text: '2', settle: false);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('qty-busy-101')), findsOneWidget);
    expect(find.byKey(const ValueKey('qty-101')), findsNothing);
    slow.release();
    await tester.pumpAndSettle();
    expect(qty(tester, 101), '2');
  });

  testWidgets('a server error is shown as a friendly message', (tester) async {
    final cart = FakeCommerceBackend(latency: Duration.zero);
    await pumpTile(tester, product(), repository: cart);
    cart.failNext = const ApiError(code: ApiErrorCode.stockUnavailable);

    await setQty(tester, find.text('ADD'));
    expect(find.text('ADD'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  group('minimum per order', () {
    CatalogProduct water({int orderable = 20}) => product(
      name: 'Jivo Water 1 L x 12',
      only: variant(
        id: 1501,
        name: '1 L x 12',
        orderable: orderable,
        maxQty: 1000,
        minQty: 5,
      ),
    );

    testWidgets('"Min 5" shows near ADD; ADD is prefilled with 5; 4 is '
        'refused; 0 removes', (tester) async {
      final cart = await pumpTile(tester, water());
      expect(find.text('Min 5'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Minimum 5 per order'),
        findsOneWidget,
        reason: 'screen readers hear the full hint',
      );

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();
      expect(fieldText(tester), '5');
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
      expect(qty(tester, 1501), '5');
      expect((await cart.load()).quantityOf(1501), 5);

      await setQty(tester, box(1501), text: '6');
      expect(qty(tester, 1501), '6');

      await setQty(tester, box(1501), text: '4');
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      expect(find.text('Minimum 5 per order'), findsWidgets);
      await tester.tap(find.byKey(const Key('qty-cancel')));
      await tester.pumpAndSettle();
      expect(qty(tester, 1501), '6');

      await setQty(tester, box(1501), text: '0');
      expect(find.text('ADD'), findsOneWidget);
      expect((await cart.load()).isEmpty, isTrue);
      expect(find.text('Min 5'), findsOneWidget, reason: 'hint stays');
    });

    testWidgets('min 1: no hint, ADD adds one', (tester) async {
      final slow = SlowCartRepository();
      await pumpTile(tester, product(), repository: slow);
      expect(find.textContaining('Min'), findsNothing);
      expect(find.textContaining('Minimum'), findsNothing);
      await setQty(tester, find.text('ADD'), settle: false);
      expect(slow.calls, [(101, 1)]);
      slow.release();
      await tester.pumpAndSettle();
    });

    testWidgets('fewer orderable than the minimum: out of stock', (
      tester,
    ) async {
      await pumpTile(tester, water(orderable: 4));
      expect(find.text('Out of stock'), findsOneWidget);
      expect(find.text('ADD'), findsNothing);
    });

    testWidgets('MIN_QTY_REQUIRED shows the minimum with the item name', (
      tester,
    ) async {
      // The tile predates a raised minimum: it still says min 1.
      final cart = FakeCommerceBackend(latency: Duration.zero)
        ..minimums[101] = 5;
      await pumpTile(tester, product(), repository: cart);

      await setQty(tester, find.text('ADD'));
      expect(
        find.text('You need to order at least 5 of Jivo Canola Oil 1 L.'),
        findsOneWidget,
      );
      expect(find.text('ADD'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // The next change uses the server's minimum.
      await setQty(tester, find.text('ADD'));
      expect(qty(tester, 101), '5');
    });

    testWidgets('the variant picker shows each variant\'s minimum', (
      tester,
    ) async {
      await pumpTile(
        tester,
        product(
          variants: [
            variant(),
            variant(id: 102, name: '1 L x 12', maxQty: 1000, minQty: 5),
          ],
        ),
      );
      expect(find.text('Min 5'), findsNothing, reason: 'default is min 1');
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();
      expect(find.text('Minimum 5 per order'), findsOneWidget);
      await setQty(tester, find.byKey(const ValueKey('add-102')));
      expect(qty(tester, 102), '5');
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets('a grid with a "Min 5" tile does not overflow at ${scale}x', (
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
                      name: 'Jivo Packaged Drinking Water with a long name',
                      only: variant(
                        status: StockStatus.lowStock,
                        unitsLeft: 8,
                        orderable: 8,
                        maxQty: 1000,
                        minQty: 5,
                      ),
                    ),
                    product(id: 2, only: variant(id: 2)),
                  ],
                ),
              ],
            ),
            overrides: [
              cartRepositoryProvider.overrideWithValue(
                FakeCommerceBackend(latency: Duration.zero),
              ),
            ],
            textScaler: TextScaler.linear(scale),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Min 5'), findsOneWidget);
      });
    }
  });

  group('type a quantity (bulk orders)', () {
    CatalogProduct bulk({int orderable = 1000, int minQty = 1}) => product(
      name: 'Jivo Water 1 L x 12',
      only: variant(
        id: 1501,
        name: '1 L x 12',
        orderable: orderable,
        maxQty: 1000,
        minQty: minQty,
      ),
    );

    Future<_RecordingCart> addOne(
      WidgetTester tester,
      CatalogProduct tile,
    ) async {
      final cart = _RecordingCart();
      await pumpTile(tester, tile, repository: cart);
      await setQty(tester, find.text('ADD'));
      return cart;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.tap(find.byKey(const ValueKey('qty-1501')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('qty-field')), text);
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping the number opens the dialog, prefilled', (
      tester,
    ) async {
      await addOne(tester, bulk());
      expect(
        find.bySemanticsLabel('Quantity 1, tap to change'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('qty-1501')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      expect(find.text('Enter quantity'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('qty-field')),
      );
      expect(field.controller!.text, '1');
      expect(field.keyboardType, TextInputType.number);

      await tester.tap(find.byKey(const Key('qty-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('qty-dialog')), findsNothing);
    });

    testWidgets('typed 100 is one request for 100', (tester) async {
      final cart = await addOne(tester, bulk());
      await type(tester, '100');
      expect(find.byKey(const Key('qty-dialog')), findsNothing);
      expect(cart.sent, [(1501, 1), (1501, 100)]);
      expect(qty(tester, 1501), '100');
    });

    testWidgets('above the cap: refused inline, nothing sent', (tester) async {
      final cart = await addOne(tester, bulk(orderable: 5));
      await type(tester, '9');
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      expect(find.text('You can add up to 5 of this item'), findsOneWidget);
      expect(cart.sent, [(1501, 1)]);
    });

    testWidgets('0 removes the line', (tester) async {
      final cart = await addOne(tester, bulk());
      await type(tester, '0');
      expect(cart.sent.last, (1501, 0));
      expect(find.text('ADD'), findsOneWidget);
    });

    testWidgets('only digits can be typed', (tester) async {
      await addOne(tester, bulk());
      await tester.tap(find.byKey(const ValueKey('qty-1501')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('qty-field')), '1a2-.3 ');
      final field = tester.widget<TextField>(
        find.byKey(const Key('qty-field')),
      );
      expect(field.controller!.text, '123');
    });

    testWidgets('below the per-variant minimum: refused with the minimum', (
      tester,
    ) async {
      final cart = await addOne(tester, bulk(minQty: 5));
      expect(cart.sent, [(1501, 5)], reason: 'ADD still adds the minimum');
      await type(tester, '3');
      expect(find.text('Minimum 5 per order'), findsWidgets);
      expect(find.byKey(const Key('qty-dialog')), findsOneWidget);
      expect(cart.sent, [(1501, 5)]);

      await tester.enterText(find.byKey(const Key('qty-field')), '7');
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
      expect(cart.sent, [(1501, 5), (1501, 7)]);
    });
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

    await setQty(tester, find.byKey(const ValueKey('add-102')));
    await setQty(tester, box(102), text: '2');
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
            height: 380,
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
    await setQty(tester, find.text('ADD'));
    final size = tester.getSize(box(101));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
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
            cartRepositoryProvider.overrideWithValue(
              FakeCommerceBackend(latency: Duration.zero),
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
