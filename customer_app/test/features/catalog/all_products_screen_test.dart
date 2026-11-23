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
    // ADD adds the minimum in one tap (one pack size) or opens the variant
    // picker (several).
    final picker = find.byKey(const Key('variant-picker'));
    if (picker.evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
    } else {
      expect(find.byKey(const Key('qty-dialog')), findsNothing);
      expect(find.byKey(const Key('cart-bar')), findsOneWidget);
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
