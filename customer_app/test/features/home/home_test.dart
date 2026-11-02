import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// Tall enough to build every home section without scrolling.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(HomeScreen)));

void main() {
  setUpAll(initializeFormatting);

  testWidgets('home renders every section for the selected store', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    expect(find.text('Delivery in 14 mins'), findsOneWidget);
    expect(find.text('Home · Flat 4B, MG Road, New Delhi'), findsOneWidget);
    expect(find.text('Search for oils, ghee and more'), findsOneWidget);
    expect(find.byKey(const Key('banner-carousel')), findsOneWidget);
    expect(find.text('Up to 20% off on olive oils'), findsOneWidget);
    expect(find.text('Shop by category'), findsOneWidget);
    for (final category in ['Edible Oils', 'Ghee', 'Health Foods']) {
      expect(find.text(category), findsOneWidget);
    }
    expect(find.text('Bestsellers'), findsOneWidget);
    expect(find.text('Offers'), findsOneWidget);
    expect(find.text('New launches'), findsOneWidget);
    expect(find.text('Previously bought'), findsOneWidget);
    expect(find.text('See all'), findsWidgets);
    expect(find.byKey(const Key('store-closed-banner')), findsNothing);
    expect(find.byKey(const Key('cart-bar')), findsNothing);
    // The bottom tabs.
    for (final tab in ['Home', 'Categories', 'Order again', 'Account']) {
      expect(find.text(tab), findsWidgets);
    }
  });

  testWidgets('ADD on a rail shows the floating cart bar, without a total', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    await tester.tap(find.byKey(const ValueKey('add-1001')).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-bar')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.textContaining('· ₹'), findsNothing);
    expect(find.text('View cart'), findsOneWidget);
  });

  testWidgets('without a location, home asks for one', (tester) async {
    final app = TestApp(tokens: signedInTokens, deliveryLocation: null);
    await app.pump(tester);

    expect(
      find.text("Choose a delivery location to see what's in stock near you."),
      findsOneWidget,
    );
    expect(app.catalog.calls, isNot(contains('home')));
    await tester.tap(
      find.widgetWithText(FilledButton, 'Select delivery location'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Where should we deliver?'), findsOneWidget);
  });

  testWidgets('a closed store shows the banner; browsing still works', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    app.serviceability.storeOpen = false;
    app.catalog.store = StoreInfo(
      id: 1,
      name: 'Jivo CP',
      isOpen: false,
      opensAt: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    await app.pump(tester);

    expect(find.byKey(const Key('store-closed-banner')), findsOneWidget);
    expect(find.text('Store closed'), findsOneWidget);
    expect(find.text('Bestsellers'), findsOneWidget);
  });

  testWidgets('a saved location that is no longer served says so', (
    tester,
  ) async {
    final app = TestApp(tokens: signedInTokens);
    app.serviceability.radiusMeters = -1;
    await app.pump(tester);

    expect(find.text('Not delivering here'), findsOneWidget);
    expect(find.text("We don't deliver to this location yet."), findsOneWidget);
    expect(find.text('Change location'), findsOneWidget);
  });

  testWidgets('a failed load shows an error with retry', (tester) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    app.catalog.failNext = const ApiError(code: ApiErrorCode.network);
    await app.pump(tester);

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Bestsellers'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Bestsellers'), findsOneWidget);
  });

  testWidgets('STORE_NOT_FOUND drops the store and checks the location again', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    app.catalog.failNext = const ApiError(
      code: ApiErrorCode.storeNotFound,
      statusCode: 404,
    );
    await app.pump(tester);

    expect(app.serviceability.checks, hasLength(2));
    expect(find.text('Bestsellers'), findsOneWidget);
  });

  testWidgets('browse: category list, sub-category rail, sort, next page', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    await tester.tap(find.byKey(const ValueKey('home-category-edible-oils')));
    await tester.pumpAndSettle();
    // 8 oils, 6 per page: the second page loads at the end of the grid.
    expect(app.catalog.calls, contains('products:edible-oils:relevance:2'));
    expect(find.text('Jivo Sunflower Oil'), findsOneWidget);
    expect(find.text('Jivo Groundnut Oil'), findsOneWidget);
    expect(find.text('Out of stock'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rail-olive-oil')));
    await tester.pumpAndSettle();
    expect(find.text('Jivo Pomace Olive Oil'), findsOneWidget);
    expect(find.text('Jivo Canola Oil'), findsNothing);
    expect(find.text('Only 3 left'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sort-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: low to high'));
    await tester.pumpAndSettle();
    expect(app.catalog.calls, contains('products:olive-oil:priceLowToHigh:1'));
    expect(find.text('Sort: Price: low to high'), findsOneWidget);
  });

  testWidgets('product detail: variants, savings, label info, ADD', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    routerOf(tester).push('/product/jivo-canola-oil');
    await tester.pumpAndSettle();

    expect(find.text('Jivo Canola Oil'), findsOneWidget);
    expect(find.text('Pack size'), findsOneWidget);
    expect(find.text('You save ₹50'), findsOneWidget);
    expect(find.text('₹24.90/100 ml'), findsOneWidget);
    expect(find.text('Product information'), findsOneWidget);
    expect(find.text('FSSAI licence no.'), findsOneWidget);
    expect(find.text('Energy (kcal)'), findsOneWidget);
    expect(find.text('Similar products'), findsNothing); // only one canola

    await tester.tap(find.byKey(const ValueKey('variant-102')));
    await tester.pumpAndSettle();
    expect(find.text('You save ₹101'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-102')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qty-102')), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gallery-0')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('an unknown product is a friendly empty state', (tester) async {
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    routerOf(tester).push('/product/nope');
    await tester.pumpAndSettle();
    expect(find.text("This product isn't available."), findsOneWidget);
  });

  testWidgets('See all opens the collection page', (tester) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    await tester.tap(find.text('See all').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Bestsellers'), findsOneWidget);
    expect(find.text('Jivo Wheatgrass Powder'), findsOneWidget);
  });

  testWidgets('the order again tab lists previously bought items', (
    tester,
  ) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    await tester.tap(find.text('Order again'));
    await tester.pumpAndSettle();
    expect(find.text('Jivo Desi Ghee'), findsOneWidget);
  });

  testWidgets('the categories tab shows the tree', (tester) async {
    tallView(tester);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    await tester.tap(find.text('Categories').last);
    await tester.pumpAndSettle();
    expect(find.text('Olive Oil'), findsOneWidget);
    expect(find.text('Desi Ghee'), findsOneWidget);
  });
}
