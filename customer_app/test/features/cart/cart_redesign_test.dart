import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import 'cart_fixtures.dart';
import 'cart_screen_test.dart' show appWithOil, openCart, textOf;

void main() {
  setUpAll(initializeFormatting);

  testWidgets('cart line − qty + steps through the cart controller', (
    tester,
  ) async {
    final app = await openCart(tester, await appWithOil(quantity: 2));
    expect(textOf(tester, 'qty-line-101'), '2');

    await tester.tap(find.byKey(const ValueKey('step-plus-line-101')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'qty-line-101'), '3');
    expect((await app.cart.load()).quantityOf(101), 3);

    await tester.tap(find.byKey(const ValueKey('step-minus-line-101')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'qty-line-101'), '2');
    expect((await app.cart.load()).quantityOf(101), 2);
  });

  testWidgets('− at the minimum removes the line, says so (also to screen '
      'readers) and Undo restores the previous quantity', (tester) async {
    final app = await openCart(tester, await appWithOil(quantity: 1));
    tester.takeAnnouncements();

    await tester.tap(find.byKey(const ValueKey('step-minus-line-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(101), 0);
    expect(find.byKey(const ValueKey('cart-line-101')), findsNothing);
    expect(find.textContaining('Removed Jivo Canola Oil'), findsOneWidget);
    final said = tester.takeAnnouncements().map((a) => a.message).toList();
    expect(said, [startsWith('Removed Jivo Canola Oil')]);

    await tester.tap(find.byKey(const ValueKey('cart-line-undo-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(101), 1);
    expect(textOf(tester, 'qty-line-101'), '1');
  });

  testWidgets('− at a minimum of 5 removes the line; Undo puts 5 back', (
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

    await tester.tap(find.byKey(const ValueKey('step-minus-line-1501')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(1501), 0);
    expect(find.textContaining('Removed Jivo Water 1 L x 12'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cart-line-undo-1501')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(1501), 5);
  });

  testWidgets('− above the minimum only lowers the quantity (no notice)', (
    tester,
  ) async {
    final app = await openCart(tester, await appWithOil(quantity: 2));
    await tester.tap(find.byKey(const ValueKey('step-minus-line-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(101), 1);
    expect(find.textContaining('Removed'), findsNothing);
  });

  testWidgets('+ stops at the orderable quantity with the usual message', (
    tester,
  ) async {
    await openCart(tester, await appWithOil(quantity: 2, orderable: 2));
    await tester.tap(find.byKey(const ValueKey('step-plus-line-101')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'qty-line-101'), '2');
    expect(find.text('You can add up to 2 of this item'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('the cart fits at 320 dp, ${scale}x text', (tester) async {
      final app = await appWithOil(quantity: 2);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await openCart(tester, app);
      tester.view.physicalSize = const Size(320, 3200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('step-plus-line-101')), findsOneWidget);
    });
  }
}
