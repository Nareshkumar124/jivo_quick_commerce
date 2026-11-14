import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/catalog/domain/catalog_models.dart';
import 'package:customer_app/features/catalog/presentation/widgets/product_tile.dart';
import 'package:customer_app/features/home/presentation/banner_carousel.dart';
import 'package:customer_app/features/home/presentation/banner_viewer.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

const _banners = [
  HomeBanner(
    id: 1,
    title: 'Rate list',
    link: CollectionBannerLink('offers'),
  ),
  HomeBanner(id: 2, title: 'No link banner'),
];

Future<void> _pumpCarousel(WidgetTester tester) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            const Scaffold(body: BannerCarousel(banners: _banners)),
      ),
      GoRoute(
        path: Routes.collection('offers'),
        builder: (_, _) => const Scaffold(body: Text('COLLECTION SCREEN')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PageView _pageView(WidgetTester tester) =>
    tester.widget<PageView>(find.byKey(const Key('banner-carousel')));

void main() {
  testWidgets('banners never move on their own', (tester) async {
    await _pumpCarousel(tester);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(_pageView(tester).controller!.page, 0);
    expect(find.text('No link banner'), findsNothing);
  });

  testWidgets('a swipe changes the page', (tester) async {
    await _pumpCarousel(tester);
    await tester.drag(
      find.byKey(const Key('banner-carousel')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    expect(_pageView(tester).controller!.page, 1);
  });

  testWidgets('a tap opens the viewer; the button follows the link', (
    tester,
  ) async {
    await _pumpCarousel(tester);
    await tester.tap(find.byKey(const Key('banner-carousel')));
    await tester.pumpAndSettle();
    expect(find.byType(BannerViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Shop now'), findsOneWidget);

    await tester.tap(find.byKey(const Key('banner-viewer-action')));
    await tester.pumpAndSettle();
    expect(find.text('COLLECTION SCREEN'), findsOneWidget);
  });

  testWidgets('a banner without a link has no button; close works', (
    tester,
  ) async {
    await _pumpCarousel(tester);
    await tester.drag(
      find.byKey(const Key('banner-carousel')),
      const Offset(-700, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('banner-carousel')));
    await tester.pumpAndSettle();
    expect(find.byType(BannerViewer), findsOneWidget);
    expect(find.byKey(const Key('banner-viewer-action')), findsNothing);

    await tester.tap(find.byKey(const Key('banner-viewer-close')));
    await tester.pumpAndSettle();
    expect(find.byType(BannerViewer), findsNothing);
  });

  testWidgets('All products lists the store and ADD works', (tester) async {
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);

    expect(find.text('All products'), findsOneWidget);
    expect(find.byKey(const Key('all-products-grid')), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
    final add = find.descendant(
      of: find.byKey(const Key('all-products-grid')),
      matching: find.byKey(const ValueKey('add-1001')),
    );
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qty-update')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-bar')), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('home and product cards fit at ${scale}x text on 360 dp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final app = TestApp(tokens: signedInTokens);
      await app.pump(tester);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductTile), findsWidgets);
    });
  }
}
