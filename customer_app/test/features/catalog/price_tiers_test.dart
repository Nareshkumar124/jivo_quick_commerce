import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/catalog/presentation/widgets/price_tiers_table.dart';
import 'package:customer_app/features/catalog/presentation/widgets/product_tile.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import 'catalog_fixtures.dart';

/// A product tile on the fake server (ADD opens the picker when the
/// product has several sizes).
Future<void> pumpTile(WidgetTester tester, CatalogProduct tile) async {
  await tester.pumpWidget(
    harness(
      Center(
        child: SizedBox(
          width: 160,
          height: 320,
          child: ProductTile(product: tile),
        ),
      ),
      overrides: [
        cartRepositoryProvider.overrideWithValue(
          FakeCommerceBackend(latency: Duration.zero),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

/// The water slabs as the server sends them (lowest first).
const waterTiers = [
  PriceTier(minOrderUnits: 5, price: '90.00'),
  PriceTier(minOrderUnits: 25, price: '87.00'),
  PriceTier(minOrderUnits: 50, price: '85.00'),
  PriceTier(minOrderUnits: 100, price: '82.00'),
  PriceTier(minOrderUnits: 250, price: '80.00'),
];

CatalogVariant tiered({
  int id = 1501,
  String name = '1 L',
  List<PriceTier> tiers = waterTiers,
}) => CatalogVariant(
  id: id,
  name: name,
  sellingPrice: tiers.isEmpty ? '90.00' : tiers.first.price,
  mrp: '90.00',
  stockStatus: StockStatus.inStock,
  orderableQuantity: 300,
  maxQtyPerOrder: 300,
  priceTiers: tiers,
);

/// The text of the rate row starting at [from] boxes.
List<String> rowTexts(WidgetTester tester, int from) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(
      of: find.byKey(ValueKey('price-tier-$from')),
      matching: find.byType(Text),
    ),
  ))
    text.data!,
];

void main() {
  setUpAll(initializeFormatting);

  group('rows', () {
    test('each range ends one below the next minimum; the last is open', () {
      expect(priceTierRows(waterTiers), [
        (from: 5, to: 24, price: '90.00'),
        (from: 25, to: 49, price: '87.00'),
        (from: 50, to: 99, price: '85.00'),
        (from: 100, to: 249, price: '82.00'),
        (from: 250, to: null, price: '80.00'),
      ]);
    });

    test('out-of-order tiers are sorted; a one-count tier is one row', () {
      expect(
        priceTierRows(const [
          PriceTier(minOrderUnits: 10, price: '80.00'),
          PriceTier(minOrderUnits: 9, price: '85.00'),
          PriceTier(minOrderUnits: 1, price: '90.00'),
        ]),
        [
          (from: 1, to: 8, price: '90.00'),
          (from: 9, to: 9, price: '85.00'),
          (from: 10, to: null, price: '80.00'),
        ],
      );
    });

    test('no tiers, no rows', () {
      expect(priceTierRows(const []), isEmpty);
    });
  });

  group('the rate table', () {
    Future<void> pumpTable(WidgetTester tester, List<PriceTier> tiers) => tester
        .pumpWidget(harness(Scaffold(body: PriceTiersTable(tiers: tiers))));

    testWidgets('renders every slab with the server price and the note', (
      tester,
    ) async {
      await pumpTable(tester, waterTiers);

      expect(find.text('Wholesale rates (per box)'), findsOneWidget);
      expect(rowTexts(tester, 5), ['5–24 boxes', '₹90']);
      expect(rowTexts(tester, 25), ['25–49 boxes', '₹87']);
      expect(rowTexts(tester, 50), ['50–99 boxes', '₹85']);
      expect(rowTexts(tester, 100), ['100–249 boxes', '₹82']);
      expect(rowTexts(tester, 250), ['250+ boxes', '₹80']);
      expect(
        find.text('Price depends on total boxes in your order (all sizes)'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('5–24 boxes: ₹90 per box'), findsOneWidget);
    });

    testWidgets('one-count slab and paise are shown as sent', (tester) async {
      await pumpTable(tester, const [
        PriceTier(minOrderUnits: 1, price: '90.50'),
        PriceTier(minOrderUnits: 2, price: '89.00'),
      ]);
      expect(rowTexts(tester, 1), ['1 box', '₹90.50']);
      expect(rowTexts(tester, 2), ['2+ boxes', '₹89']);
    });

    testWidgets('nothing without tiers', (tester) async {
      await pumpTable(tester, const []);
      expect(find.byKey(const Key('price-tiers')), findsNothing);
      expect(find.text('Wholesale rates (per box)'), findsNothing);
    });

    testWidgets('fits at 2x text on a phone', (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          const Scaffold(body: PriceTiersTable(tiers: waterTiers)),
          textScaler: const TextScaler.linear(2),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(rowTexts(tester, 250), ['250+ boxes', '₹80']);
    });
  });

  group('product detail', () {
    GoRouter routerOf(WidgetTester tester) =>
        GoRouter.of(tester.element(find.byType(HomeScreen)));

    Future<void> openProduct(WidgetTester tester, String slug) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await TestApp(tokens: signedInTokens).pump(tester);
      routerOf(tester).push('/product/$slug');
      await tester.pumpAndSettle();
    }

    testWidgets('water shows the selected size\'s wholesale rates', (
      tester,
    ) async {
      await openProduct(tester, 'jivo-drinking-water');

      expect(find.byKey(const ValueKey('price-tiers-1501')), findsOneWidget);
      expect(rowTexts(tester, 5), ['5–24 boxes', '₹90']);
      expect(rowTexts(tester, 250), ['250+ boxes', '₹80']);
      expect(
        find.text('Price depends on total boxes in your order (all sizes)'),
        findsOneWidget,
      );

      // Each size has its own rates.
      await tester.tap(find.byKey(const ValueKey('variant-1502')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('price-tiers-1502')), findsOneWidget);
      expect(rowTexts(tester, 25), ['25–49 boxes', '₹122']);
      expect(rowTexts(tester, 250), ['250+ boxes', '₹115']);
    });

    testWidgets('a product without tiers shows no rate table', (tester) async {
      await openProduct(tester, 'jivo-canola-oil');
      expect(find.text('Jivo Canola Oil'), findsOneWidget);
      expect(find.byKey(const Key('price-tiers')), findsNothing);
      expect(find.text('Wholesale rates (per box)'), findsNothing);
    });
  });

  group('variant picker', () {
    testWidgets('each tiered size shows compact rates; the note once', (
      tester,
    ) async {
      await pumpTile(
        tester,
        product(
          name: 'Jivo Water',
          variants: [
            tiered(),
            tiered(
              id: 1502,
              name: '500 ml',
              tiers: const [
                PriceTier(minOrderUnits: 5, price: '125.00'),
                PriceTier(minOrderUnits: 25, price: '122.00'),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('variant-picker')), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-tiers-1501')), findsOneWidget);
      expect(find.byKey(const ValueKey('picker-tiers-1502')), findsOneWidget);
      expect(find.text('5–24: ₹90'), findsOneWidget);
      expect(find.text('250+: ₹80'), findsOneWidget);
      expect(find.text('25+: ₹122'), findsOneWidget);
      expect(find.byKey(const Key('picker-tiers-note')), findsOneWidget);
    });

    testWidgets('sizes without tiers: no rates, no note', (tester) async {
      await pumpTile(
        tester,
        product(
          variants: [
            variant(),
            variant(id: 102, name: '2 L'),
          ],
        ),
      );
      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('variant-picker')), findsOneWidget);
      expect(find.text('Wholesale rates (per box)'), findsNothing);
      expect(find.byKey(const Key('picker-tiers-note')), findsNothing);
    });
  });
}
