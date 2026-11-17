import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_screen.dart';
import 'package:customer_app/features/cart/presentation/widgets/bill_details.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import 'cart_fixtures.dart';
import 'cart_screen_test.dart' show appWithOil, openCart, textOf, typeLineQty;

/// CA-19 cart part: `previous_selling_price` (API #56) on cart lines.
void main() {
  setUpAll(initializeFormatting);

  const flagText = 'Price changed: was ₹129, now ₹119';
  CartLine changedLine() => cartLine(
    price: '119.00',
    mrp: '150.00',
    pricePerUnit: '119.00',
    previousSellingPrice: '129.00',
  );

  testWidgets('a changed line shows was/now with an icon; the bill is the '
      "server's and checkout stays open", (tester) async {
    final semantics = tester.ensureSemantics();
    final stub = StubCartRepository(cartSnapshot(lines: [changedLine()]));
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );

    final flag = find.byKey(const ValueKey('cart-line-price-changed-101'));
    expect(flag, findsOneWidget);
    expect(find.text(flagText), findsOneWidget);
    // Not colour only: an icon marks it.
    expect(
      find.descendant(of: flag, matching: find.byIcon(Icons.info_outline)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(flagText), findsOneWidget);

    // One-line summary above the bill, neutral wording.
    final notice = find.byKey(const Key('cart-prices-changed'));
    expect(notice, findsOneWidget);
    expect(
      find.descendant(
        of: notice,
        matching: find.textContaining(
          'The price of 1 item has changed since you last saw it',
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.getRect(notice).bottom,
      lessThanOrEqualTo(tester.getRect(find.byType(BillDetails)).top),
    );

    // The bill is the inconsistent fixture, rendered as sent.
    expect(textOf(tester, 'bill-to-pay'), '₹999');
    expect(textOf(tester, 'checkout-bar-total'), '₹999');
    expect(textOf(tester, 'cart-line-total-101'), '₹498');
    // Not a problem line: no blocking banner, no issue flag.
    expect(find.byKey(const Key('cart-problems')), findsNothing);
    expect(find.byKey(const ValueKey('cart-line-issue-101')), findsNothing);
    semantics.dispose();
  });

  testWidgets('summary counts the changed lines', (tester) async {
    final stub = StubCartRepository(
      cartSnapshot(
        lines: [
          changedLine(),
          cartLine(id: 2, variantId: 102, previousSellingPrice: '239.00'),
          cartLine(id: 3, variantId: 103),
        ],
      ),
    );
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(
      find.textContaining('Prices of 2 items have changed'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cart-line-price-changed-103')),
      findsNothing,
    );
  });

  testWidgets('no flag and no summary when nothing changed', (tester) async {
    final stub = StubCartRepository(cartSnapshot());
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(find.textContaining('Price changed'), findsNothing);
    expect(find.byKey(const Key('cart-prices-changed')), findsNothing);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('readable at ${scale}x: wraps, nothing clipped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CartLineTile(line: changedLine()),
              const CartPricesChangedNotice(count: 1),
            ],
          ),
          overrides: [
            cartRepositoryProvider.overrideWithValue(
              StubCartRepository(cartSnapshot()),
            ),
          ],
          textScaler: TextScaler.linear(scale),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text(flagText));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      // The flag stays inside the 360 dp screen.
      final rect = tester.getRect(find.text(flagText));
      expect(rect.right, lessThanOrEqualTo(360));
    });
  }

  testWidgets('a quantity change clears the flag (server resets it)', (
    tester,
  ) async {
    final app = await appWithOil();
    app.cart.changeSellingPrice(101, '239.00');
    await openCart(tester, app);

    expect(find.text('Price changed: was ₹249, now ₹239'), findsOneWidget);
    expect(find.byKey(const Key('cart-prices-changed')), findsOneWidget);
    expect(textOf(tester, 'cart-line-total-101'), '₹478');

    await typeLineQty(tester, 101, '3');

    expect(find.textContaining('Price changed'), findsNothing);
    expect(find.byKey(const Key('cart-prices-changed')), findsNothing);
    expect(textOf(tester, 'cart-line-total-101'), '₹717');
  });

  group('fake server', () {
    Future<FakeCommerceBackend> withChangedOil() async {
      final fake = FakeCommerceBackend(latency: Duration.zero);
      await fake.setQuantity(
        101,
        2,
        preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
      );
      fake.changeSellingPrice(101, '239.00');
      return fake;
    }

    test('reports the price last seen until the quantity is set', () async {
      final fake = await withChangedOil();
      final before = (await fake.load()).lines.single;
      expect(before.previousSellingPrice, '249.00');
      expect(before.sellingPrice, '239.00');

      // Re-sending the same quantity acknowledges it.
      final after = (await fake.setQuantity(101, 2)).lines.single;
      expect(after.previousSellingPrice, isNull);
      expect(after.quantity, 2);
    });

    test('a price back at the one last seen is not a change', () async {
      final fake = await withChangedOil();
      fake.changeSellingPrice(101, '249.00');
      expect((await fake.load()).lines.single.previousSellingPrice, isNull);
    });
  });
}
