import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:customer_app/features/catalog/presentation/widgets/product_tile.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import '../cart/cart_fixtures.dart';
import 'catalog_fixtures.dart';
import 'real_catalog_fixtures.dart';

/// A 360 dp phone at [scale] text size.
void phone(WidgetTester tester, double scale) {
  tester.view.physicalSize = const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// The app on the API catalog repository over [realCatalogServer].
Future<TestApp> startReal(WidgetTester tester) async {
  final app = TestApp(
    tokens: signedInTokens,
    catalogRepository: realCatalogRepository(),
  );
  await app.pump(tester);
  return app;
}

GoRouter router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).last));

Future<void> open(WidgetTester tester, String location) async {
  router(tester).push(location);
  await tester.pumpAndSettle();
}

/// Fails with the full report (which widget overflowed) on a layout error.
void expectNoLayoutError(WidgetTester tester) {
  final error = tester.takeException();
  if (error is FlutterError) fail(error.toStringDeep());
  expect(error, isNull);
}

/// The first (outer, vertical) scrollable of the screen.
Finder get outerScrollable => find.byType(Scrollable).first;

/// Every visible struck-through text (an MRP).
Iterable<String> struck(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .where((t) => t.style?.decoration == TextDecoration.lineThrough)
    .map((t) => t.data ?? '');

void main() {
  setUpAll(initializeFormatting);

  group('server payloads map without loss or crash', () {
    test('categories: two levels, no image, no sub-categories', () async {
      final tree = await realCatalogRepository().categories();
      expect(tree, hasLength(8));
      expect(tree.first.imageUrl, isNotNull);
      expect(tree.first.children, hasLength(4));
      final seeds = tree.firstWhere((c) => c.slug == 'seeds');
      expect(seeds.imageUrl, isNull);
      expect(seeds.children, isEmpty);
      final drinks = tree.firstWhere((c) => c.slug == 'beverages');
      expect(drinks.children.map((c) => c.name), ['Water', 'Juices']);
      expect(drinks.children.every((c) => c.imageUrl == null), isTrue);
    });

    test('six sizes keep their order; no discount is 0 and "0.00"; no '
        'image is null', () async {
      final page = await realCatalogRepository().products(
        category: 'edible-oils',
      );
      final mustard = page.items.first;
      expect(mustard.name, mustardName);
      expect(mustard.imageUrl, isNull);
      expect(mustard.defaultVariant.name, '1 L Pouch');
      expect(mustard.variants.map((v) => v.name), [
        '200 ml',
        '500 ml',
        '1 L Pouch',
        '1 L Bottle',
        '2 L',
        '5 L Jar',
      ]);
      final flat = mustard.variants.first;
      expect(flat.sellingPrice, flat.mrp);
      expect(flat.discountPercent, 0);
      expect(flat.discountAmount, '0.00');
      expect(flat.imageUrl, isNull);
      expect(mustard.variants[4].inStock, isFalse);
      expect(mustard.variants[5].lowStockUnits, 2);
    });

    test(
      'an empty category is an empty page; an unknown one NOT_FOUND',
      () async {
        final repository = realCatalogRepository();
        expect((await repository.products(category: 'honey')).items, isEmpty);
        await expectLater(
          repository.products(category: 'gone'),
          throwsA(
            isA<ApiError>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.notFound,
            ),
          ),
        );
      },
    );
  });

  testWidgets('selling == MRP: one price, no strike-through, no "0% OFF", a '
      'placeholder image', (tester) async {
    phone(tester, 1);
    await startReal(tester);
    await open(tester, Routes.category('seeds'));

    final tile = find.byKey(const ValueKey('tile-50'));
    expect(tile, findsOneWidget);
    expect(
      find.descendant(of: tile, matching: find.text('₹249')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.textContaining('OFF')),
      findsNothing,
    );
    expect(struck(tester), isEmpty);
    expect(
      find.descendant(
        of: tile,
        matching: find.byIcon(Icons.shopping_basket_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('66% off: the badge and the struck MRP from the server', (
    tester,
  ) async {
    phone(tester, 1);
    await startReal(tester);
    await open(tester, Routes.category('edible-oils'));

    final tile = find.byKey(const ValueKey('tile-4'));
    expect(
      find.descendant(of: tile, matching: find.text('66% OFF')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tile, matching: find.text('₹500')),
      findsOneWidget,
    );
    expect(struck(tester), contains('₹1,499'));
  });

  testWidgets('an empty category shows its empty state', (tester) async {
    phone(tester, 1);
    await startReal(tester);
    await open(tester, Routes.category('honey'));
    expect(find.text('No products here yet.'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    group('360 dp at ${scale}x text', () {
      testWidgets('home: category grid without images and a rail of long '
          'names fit', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        expect(find.byType(HomeScreen), findsOneWidget);
        expect(find.text('All products'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Bestsellers'),
          200,
          scrollable: outerScrollable,
        );
        await tester.pumpAndSettle();
        expectNoLayoutError(tester);
      });

      testWidgets('categories tab: 15 categories, placeholders where there '
          'is no image', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        router(tester).go(Routes.categories);
        await tester.pumpAndSettle();
        expect(find.text('Edible Oils'), findsOneWidget);
        expect(find.text('Groundnut, Sunflower & More'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Juices'),
          300,
          scrollable: outerScrollable,
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.category_outlined), findsWidgets);
        expectNoLayoutError(tester);
      });

      testWidgets('product list with the sub-category rail: long names and '
          'six-size tiles fit', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        await open(tester, Routes.category('edible-oils'));
        expect(find.text('1 L Pouch · 6 options'), findsOneWidget);
        // CA-14: from 1.5x the side rail becomes a row of chips and the
        // grid takes the full width.
        expect(
          find.byKey(const Key('sub-category-chips')),
          scale >= 1.5 ? findsOneWidget : findsNothing,
        );
        expect(find.byKey(const ValueKey('rail-all')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('tile-52')),
          300,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('product-grid')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final name = tester.widget<Text>(find.text(longName));
        expect(name.maxLines, 2);
        expect(name.overflow, TextOverflow.ellipsis);
        expectNoLayoutError(tester);
      });

      testWidgets('product detail: six sizes wrap; a no-discount size shows '
          'no badge, strike-through or saving', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        await open(tester, Routes.product(mustardSlug));

        for (final id in [401, 402, 403, 404, 405, 406]) {
          expect(find.byKey(ValueKey('variant-$id')), findsOneWidget);
        }
        // The default, 1 L Pouch: 29% off.
        expect(find.text('29% OFF'), findsOneWidget);
        expect(find.text('You save ₹75'), findsOneWidget);
        expect(struck(tester), contains('₹255'));

        final bottle = find.byKey(const ValueKey('variant-404'));
        await tester.ensureVisible(bottle);
        await tester.pumpAndSettle();
        await tester.tap(bottle);
        await tester.pumpAndSettle();
        expect(find.text('₹199'), findsWidgets);
        expect(find.textContaining('% OFF'), findsNothing);
        expect(find.textContaining('You save'), findsNothing);
        expect(struck(tester), isEmpty);
        expectNoLayoutError(tester);
      });

      testWidgets('variant picker: six sizes scroll; the last ADD is '
          'reachable', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        await open(tester, Routes.category('mustard-oil'));
        await tester.tap(find.byKey(const ValueKey('add-product-40')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('variant-picker')), findsOneWidget);

        final last = find.byKey(const ValueKey('add-406'));
        await tester.scrollUntilVisible(
          last,
          200,
          scrollable: find.descendant(
            of: find.byKey(const Key('variant-picker')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Only 2 left'), findsWidgets);
        // Tapping it is covered by product_tile_test (the cart bar that
        // follows only overflows with the test font's square glyphs).
        expect(last.hitTestable(), findsOneWidget);
        expectNoLayoutError(tester);
      });

      testWidgets('search results fit', (tester) async {
        phone(tester, scale);
        await startReal(tester);
        await open(tester, Routes.search);
        await tester.enterText(
          find.byKey(const Key('search-field')),
          'mustard',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('tile-40')), findsOneWidget);
        expectNoLayoutError(tester);
      });
    });
  }

  testWidgets('a long price in a narrow tile at 2.0x stays on one line and '
      'the tile does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 117.5 dp: one column of the list with the sub-category rail at 360 dp.
    final tile = product(
      id: 9,
      name: 'Jivo Extra Virgin Olive Oil',
      only: variant(
        id: 901,
        name: '2 L',
        price: '1250.50',
        mrp: '2700.00',
        discountAmount: '1449.50',
        discountPercent: 53,
      ),
    );
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 117.5,
              height: productTileExtent(context),
              child: ProductTile(product: tile),
            ),
          ),
        ),
        overrides: [
          cartRepositoryProvider.overrideWithValue(
            FakeCommerceBackend(latency: Duration.zero),
          ),
        ],
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();
    expectNoLayoutError(tester);
    final price = find.text('₹1,250.50');
    expect(price, findsOneWidget);
    // One line: the amount's height is a single line of its style.
    final style = tester.widget<Text>(price).style!;
    final oneLine = style.fontSize! * style.height! * 2;
    expect(tester.getSize(price).height, lessThanOrEqualTo(oneLine + 0.5));
    expect(struck(tester), ['₹2,700']);
  });

  testWidgets('a cart line without a discount or image fits at 1.3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      harness(
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CartLineTile(
              line: cartLine(
                name: longName,
                variantName: '1 L Pouch',
                price: '310.00',
                mrp: '310.00',
                quantity: 5,
                lineTotal: '1550.00',
                lineMrpTotal: '1550.00',
              ),
            ),
          ],
        ),
        overrides: [
          cartRepositoryProvider.overrideWithValue(
            FakeCommerceBackend(latency: Duration.zero),
          ),
        ],
        textScaler: const TextScaler.linear(1.3),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('₹310'), findsOneWidget);
    expect(find.text('₹1,550'), findsOneWidget);
    expect(struck(tester), isEmpty);
    expectNoLayoutError(tester);
  });
}
