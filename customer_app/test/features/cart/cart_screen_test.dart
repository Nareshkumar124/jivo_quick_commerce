import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/widgets/bill_details.dart';
import 'package:customer_app/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../../helpers/widget_harness.dart';
import 'cart_fixtures.dart';

/// Tall enough to build the whole cart without scrolling.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Starts the app on Home and opens the cart.
Future<TestApp> openCart(WidgetTester tester, [TestApp? app]) async {
  tallView(tester);
  final started = app ?? TestApp(tokens: signedInTokens);
  await started.pump(tester);
  GoRouter.of(tester.element(find.byType(HomeScreen))).push(Routes.cart);
  await tester.pumpAndSettle();
  return started;
}

/// Puts [quantity] × Jivo Canola Oil (₹249) in the fake server cart.
Future<TestApp> appWithOil({int quantity = 2, int orderable = 5}) async {
  final app = TestApp(tokens: signedInTokens);
  await app.cart.setQuantity(
    101,
    quantity,
    preview: CartLinePreview.of(oil(orderable: orderable), 'Jivo Canola Oil'),
  );
  return app;
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  setUpAll(initializeFormatting);

  testWidgets('the bill is rendered exactly as the server sent it', (
    tester,
  ) async {
    // The fixture's numbers don't add up (₹999 to pay): a screen that sums
    // or derives money fails here.
    final stub = StubCartRepository(cartSnapshot());
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );

    expect(find.byType(BillDetails), findsOneWidget);
    expect(textOf(tester, 'bill-mrp-total'), '₹598');
    expect(textOf(tester, 'bill-product-discount'), '−₹100');
    expect(textOf(tester, 'bill-delivery-fee'), 'FREE');
    expect(textOf(tester, 'bill-handling-fee'), '₹5');
    expect(textOf(tester, 'bill-to-pay'), '₹999');
    expect(textOf(tester, 'checkout-bar-total'), '₹999');
    expect(textOf(tester, 'cart-line-total-101'), '₹498');
    // Zero rows are hidden; nothing the server didn't send is derived.
    for (final key in ['coupon-discount', 'small-cart-fee', 'tip']) {
      expect(find.byKey(ValueKey('bill-$key')), findsNothing, reason: key);
    }
    expect(find.byKey(const Key('bill-savings')), findsNothing);
    expect(find.byKey(const Key('free-delivery-nudge')), findsNothing);
    expect(stub.calls, contains('load:1')); // priced for the saved address
  });

  testWidgets('savings and the free-delivery nudge come from the server', (
    tester,
  ) async {
    final stub = StubCartRepository(
      cartSnapshot(
        bill: const CartBill(
          mrpTotal: '160.00',
          itemTotal: '148.00',
          productDiscount: '12.00',
          couponDiscount: '10.00',
          deliveryFee: '25.00',
          smallCartFee: '15.00',
          handlingFee: '5.00',
          tip: '20.00',
          grandTotal: '203.00',
          totalSavings: '77.00',
          freeDeliveryShortfall: '51.00',
        ),
        coupon: const AppliedCoupon(code: 'WELCOME10', discount: '10.00'),
      ),
    );
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );

    expect(textOf(tester, 'bill-coupon-discount'), '−₹10');
    expect(find.text('Coupon (WELCOME10)'), findsOneWidget);
    expect(textOf(tester, 'bill-delivery-fee'), '₹25');
    expect(textOf(tester, 'bill-small-cart-fee'), '₹15');
    expect(textOf(tester, 'bill-tip'), '₹20');
    expect(find.text('You save ₹77 on this order'), findsOneWidget);
    expect(find.text('Add ₹51 more for FREE delivery'), findsOneWidget);
    expect(find.text('WELCOME10 applied'), findsOneWidget);
  });

  testWidgets('an empty cart shows the empty state', (tester) async {
    await openCart(tester);
    expect(find.byKey(const Key('cart-empty')), findsOneWidget);
    expect(find.byKey(const Key('proceed-to-checkout')), findsNothing);

    await tester.tap(find.text('Start shopping'));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('a failed load shows retry, and retry loads the cart', (
    tester,
  ) async {
    final stub = StubCartRepository(cartSnapshot())
      ..loadError = const ApiError(code: ApiErrorCode.network);
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(find.text('Retry'), findsOneWidget);

    stub.loadError = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-content')), findsOneWidget);
  });

  testWidgets('a line with less stock is flagged, fixed, and blocks checkout', (
    tester,
  ) async {
    final app = await appWithOil(quantity: 4);
    app.cart.stock[101] = 2;
    await openCart(tester, app);

    expect(find.byKey(const Key('cart-problems')), findsOneWidget);
    expect(find.text('Only 2 available'), findsOneWidget);
    final proceed = find.byKey(const Key('proceed-to-checkout'));
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(of: proceed, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Update to 2'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cart-problems')), findsNothing);
    expect(find.text('2', skipOffstage: false), findsWidgets);
    expect((await app.cart.load()).lines.single.quantity, 2);
  });

  testWidgets('below the minimum order, checkout shows why and waits', (
    tester,
  ) async {
    final stub = StubCartRepository(
      cartSnapshot(
        minimumOrder: const MinimumOrder(
          met: false,
          amount: '99.00',
          shortfall: '20.00',
        ),
      ),
    );
    await openCart(
      tester,
      TestApp(tokens: signedInTokens, cartRepository: stub),
    );
    expect(
      find.text('Minimum order is ₹99. Add ₹20 more to check out.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('proceed-to-checkout')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('steppers and remove change the server cart', (tester) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const ValueKey('inc-line-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).quantityOf(101), 3);
    expect(textOf(tester, 'cart-line-total-101'), '₹747');

    await tester.tap(find.byKey(const ValueKey('cart-line-remove-101')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).isEmpty, isTrue);
    expect(find.byKey(const Key('cart-empty')), findsOneWidget);
  });

  testWidgets('coupons: reasons, apply and remove', (tester) async {
    final app = await appWithOil(); // ₹498 of items
    await openCart(tester, app);

    await tester.tap(find.byKey(const Key('apply-coupon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coupon-sheet')), findsOneWidget);
    expect(find.text('Save ₹50 on this order'), findsOneWidget);
    expect(find.text("You've already used this coupon"), findsOneWidget);
    expect(find.text('This coupon has expired'), findsOneWidget);
    expect(find.byKey(const ValueKey('coupon-apply-OILFEST')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('coupon-apply-JIVO50')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coupon-sheet')), findsNothing);
    expect(find.text('JIVO50 applied. You save ₹50.'), findsOneWidget);
    expect(find.text('JIVO50 applied'), findsOneWidget);
    expect(textOf(tester, 'bill-coupon-discount'), '−₹50');

    await tester.tap(find.byKey(const Key('remove-coupon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('apply-coupon')), findsOneWidget);
    expect(find.byKey(const ValueKey('bill-coupon-discount')), findsNothing);
  });

  testWidgets("a typed code shows the server's reason under the field", (
    tester,
  ) async {
    final app = await appWithOil(quantity: 1); // ₹249, below JIVO50's ₹299
    await openCart(tester, app);
    await tester.tap(find.byKey(const Key('apply-coupon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a coupon code'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coupon-code')), 'nope');
    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text("This coupon code isn't valid."), findsOneWidget);

    await tester.enterText(find.byKey(const Key('coupon-code')), 'jivo50');
    await tester.tap(find.byKey(const Key('coupon-apply-code')));
    await tester.pumpAndSettle();
    expect(find.text('Add ₹50 more to use this coupon'), findsWidgets);
    expect(find.byKey(const Key('coupon-sheet')), findsOneWidget);
  });

  testWidgets('tip chips set and clear the tip; custom asks for an amount', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const ValueKey('tip-20')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'bill-tip'), '₹20');
    expect((await app.cart.load()).bill!.tip, '20.00');

    await tester.tap(find.byKey(const ValueKey('tip-20')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bill-tip')), findsNothing);

    await tester.tap(find.byKey(const Key('tip-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tip-custom-field')), '0');
    await tester.tap(find.byKey(const Key('tip-custom-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a whole amount from ₹1 to ₹500'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('tip-custom-field')), '45');
    await tester.tap(find.byKey(const Key('tip-custom-save')));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'bill-tip'), '₹45');
    expect(
      find.descendant(
        of: find.byKey(const Key('tip-custom')),
        matching: find.text('₹45'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('instruction chips and the note go to the server', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const ValueKey('instruction-LEAVE_AT_DOOR')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).instructions.tags, {
      InstructionTag.leaveAtDoor,
    });

    await tester.enterText(
      find.byKey(const Key('instructions-note')),
      'Gate code 1234',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('instructions-save')));
    await tester.pumpAndSettle();
    expect((await app.cart.load()).instructions.note, 'Gate code 1234');
    expect(find.text('Instructions saved'), findsOneWidget);
    expect(find.byKey(const Key('instructions-save')), findsNothing);
  });

  testWidgets('proceed re-validates the cart, then opens checkout', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    await tester.tap(find.byKey(const Key('proceed-to-checkout')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('proceed stops when re-validation finds a stock change', (
    tester,
  ) async {
    final app = await appWithOil();
    await openCart(tester, app);

    app.cart.stock[101] = 0; // sold out since the cart was opened
    await tester.tap(find.byKey(const Key('proceed-to-checkout')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsNothing);
    expect(
      find.text('Some items in your cart changed. Please review them.'),
      findsOneWidget,
    );
    expect(find.text('Out of stock'), findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('line and bill fit at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        harness(
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CartLineTile(
                line: cartLine(
                  name: 'Jivo Cold Pressed Canola Oil Pouch',
                  issue: CartLineIssue.reduced,
                  available: 1,
                ),
              ),
              const BillDetails(bill: inconsistentBill),
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
    });
  }
}
