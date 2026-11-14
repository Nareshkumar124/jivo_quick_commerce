import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/catalog/presentation/all_products_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('All products (the cart "Add more" target) lists products, '
      'ADD works, back returns', (tester) async {
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.push(Routes.allProducts);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('All products'),
      ),
      findsOneWidget,
    );
    final add = find.descendant(
      of: find.byType(AllProductsScreen),
      matching: find.text('ADD'),
    );
    expect(add, findsWidgets);
    await tester.tap(add.first);
    await tester.pumpAndSettle();
    // ADD opens the quantity dialog (one pack size) or the variant picker.
    final opened =
        find.byKey(const Key('qty-dialog')).evaluate().isNotEmpty ||
        find.byKey(const Key('variant-picker')).evaluate().isNotEmpty;
    expect(opened, isTrue);
    if (find.byKey(const Key('variant-picker')).evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    } else {
      await tester.tap(find.byKey(const Key('qty-update')));
      await tester.pumpAndSettle();
    }

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Home header gradient covers the status-bar inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 40);
    addTearDown(tester.view.reset);
    final app = TestApp(tokens: signedInTokens);
    await app.pump(tester);
    final header = find.byKey(const Key('home-header'));
    expect(header, findsOneWidget);
    expect(tester.getTopLeft(header).dy, 0, reason: 'no ivory gap above');
    expect(
      tester.getTopLeft(find.byKey(const Key('home-search'))).dy,
      greaterThanOrEqualTo(40),
    );
  });
}
