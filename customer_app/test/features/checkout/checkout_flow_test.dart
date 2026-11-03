import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_screen.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/checkout/presentation/order_success_screen.dart';
import 'package:customer_app/features/checkout/presentation/payment_failed_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/location/domain/delivery_location.dart';
import 'package:customer_app/features/location/data/serviceability_repository.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';
import '../cart/cart_fixtures.dart';

void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 2 × ₹249 in the fake server cart: item total ₹498, free delivery,
/// ₹5 handling, so ₹503 to pay (the fake backend's demo rules).
Future<TestApp> appWithCart({
  FakeCommerceBackend? commerce,
  DeliveryLocation? location = testDeliveryLocation,
}) async {
  final app = TestApp(
    tokens: signedInTokens,
    commerce: commerce,
    deliveryLocation: location,
  );
  await app.cart.setQuantity(
    101,
    2,
    preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
  );
  return app;
}

/// Starts on Home, then pushes the cart and checkout like the customer.
Future<void> openCheckout(WidgetTester tester, TestApp app) async {
  tallView(tester);
  await app.pump(tester);
  final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
  router.push(Routes.cart);
  await tester.pumpAndSettle();
  router.push(Routes.checkout);
  await tester.pumpAndSettle();
  expect(find.byType(CheckoutScreen), findsOneWidget);
}

Future<void> placeOrder(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('place-order')));
  await tester.pumpAndSettle();
}

FilledButton placeButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byKey(const Key('place-order')),
    matching: find.byType(FilledButton),
  ),
);

void main() {
  setUpAll(initializeFormatting);

  testWidgets('COD goes straight to success, and the cart is cleared', (
    tester,
  ) async {
    final app = await appWithCart();
    await openCheckout(tester, app);

    expect(find.text('Pay ₹503'), findsOneWidget); // online is the default
    await tester.tap(find.byKey(const Key('pay-cod')));
    await tester.pumpAndSettle();
    expect(find.text('Place order'), findsOneWidget);
    await placeOrder(tester);

    expect(find.byType(OrderSuccessScreen), findsOneWidget);
    expect(find.text('Order placed!'), findsOneWidget);
    expect(find.text('Order JQ001001'), findsOneWidget);
    expect(find.text('Arriving in about 15 min'), findsOneWidget);
    expect(find.text('Pay ₹503 on delivery'), findsOneWidget);
    expect(app.payments.requests, isEmpty); // no gateway for COD
    final order = app.cart.orders.single;
    expect(order.status, OrderStatus.placed);
    expect(order.paymentMethod, PaymentMethod.cod);
    expect((await app.cart.load()).isEmpty, isTrue);
    expect(find.byKey(const Key('cart-bar')), findsNothing);

    // Back goes Home, never to checkout.
    await tester.tap(find.byKey(const Key('continue-shopping')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('online: success only after the server verifies', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    await placeOrder(tester);

    final request = app.payments.requests.single;
    expect(request.checkout.keyId, 'rzp_test_fake');
    expect(request.checkout.amountPaise, 50300); // the server's, as sent
    expect(request.grandTotal, '503.00');
    expect(find.byType(OrderSuccessScreen), findsOneWidget);
    expect(find.text('Paid ₹503 online'), findsOneWidget);
    expect(app.cart.orders.single.status, OrderStatus.placed);
  });

  testWidgets('online: a bad signature is never a success', (tester) async {
    final app = await appWithCart();
    app.onPay = (_) => FakePaymentChoice.badSignature;
    await openCheckout(tester, app);
    await placeOrder(tester);

    expect(find.byType(OrderSuccessScreen), findsNothing);
    expect(find.byType(PaymentFailedScreen), findsOneWidget);
    expect(
      find.text(
        "We couldn't confirm your payment. Please check your order status "
        'before paying again.',
      ),
      findsOneWidget,
    );
    expect(app.cart.orders.single.status, OrderStatus.paymentPending);
  });

  testWidgets('online: the SDK says success but verify fails: not a success', (
    tester,
  ) async {
    final app = await appWithCart(commerce: _VerifyDown());
    await openCheckout(tester, app);
    await placeOrder(tester);

    expect(find.byType(OrderSuccessScreen), findsNothing);
    expect(find.byType(PaymentFailedScreen), findsOneWidget);
    expect(find.text('Retry payment'), findsOneWidget);
  });

  testWidgets('cancelled payment: retry, then success', (tester) async {
    final app = await appWithCart();
    app.onPay = (_) => FakePaymentChoice.cancel;
    await openCheckout(tester, app);
    await placeOrder(tester);

    expect(find.byType(PaymentFailedScreen), findsOneWidget);
    expect(
      find.text('The payment for order JQ001001 wasn\'t completed.'),
      findsOneWidget,
    );
    expect(
      find.text('You closed the payment before it finished.'),
      findsOneWidget,
    );
    expect(find.textContaining('Pay by '), findsOneWidget);

    app.onPay = (_) => FakePaymentChoice.succeed;
    await tester.tap(find.byKey(const Key('retry-payment')));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSuccessScreen), findsOneWidget);
    // The retry got a new Razorpay order from the server.
    expect(
      app.payments.requests.map((r) => r.checkout.orderId).toSet(),
      hasLength(2),
    );
    expect(app.cart.orders.single.status, OrderStatus.placed);
  });

  testWidgets('a webhook-confirmed payment moves on to success', (
    tester,
  ) async {
    final app = await appWithCart();
    app.onPay = (_) {
      // The app never hears back, but the webhook confirms the payment.
      app.cart.confirmByWebhook(app.cart.orders.single.id);
      return FakePaymentChoice.externalWallet;
    };
    await openCheckout(tester, app);
    await placeOrder(tester);

    expect(find.byType(OrderSuccessScreen), findsOneWidget);
    expect(find.text('Order placed!'), findsOneWidget);
  });

  testWidgets('change payment method cancels the unpaid order (T5)', (
    tester,
  ) async {
    final app = await appWithCart();
    app.onPay = (_) => FakePaymentChoice.fail;
    await openCheckout(tester, app);
    await placeOrder(tester);

    await tester.tap(find.byKey(const Key('change-payment-method')));
    await tester.pumpAndSettle();
    expect(app.cart.orders.single.status, OrderStatus.cancelled);
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect((await app.cart.load()).isEmpty, isFalse); // the cart stays

    // Checkout → back → cart → back → Home.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('cancel order asks first, then opens the cart', (tester) async {
    final app = await appWithCart();
    app.onPay = (_) => FakePaymentChoice.cancel;
    await openCheckout(tester, app);
    await placeOrder(tester);

    await tester.tap(find.byKey(const Key('cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep order'));
    await tester.pumpAndSettle();
    expect(app.cart.orders.single.status, OrderStatus.paymentPending);

    await tester.tap(find.byKey(const Key('cancel-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-order')));
    await tester.pumpAndSettle();
    expect(app.cart.orders.single.status, OrderStatus.cancelled);
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Order cancelled'), findsOneWidget);
  });

  testWidgets('after the payment window, the order failed (T4)', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 3, 10);
    final app = await appWithCart(
      commerce: FakeCommerceBackend(latency: Duration.zero, clock: () => now),
    );
    app.onPay = (_) {
      now = now.add(const Duration(minutes: 16));
      return FakePaymentChoice.cancel;
    };
    await openCheckout(tester, app);
    await placeOrder(tester);

    expect(app.cart.orders.single.status, OrderStatus.paymentFailed);
    expect(
      find.text(
        'The time to pay for order JQ001001 has run out, so it wasn\'t '
        'placed. Your items are still in your cart.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('retry-payment')), findsNothing);
    await tester.tap(find.byKey(const Key('back-to-cart')));
    await tester.pumpAndSettle();
    expect(find.byType(CartScreen), findsOneWidget);
  });

  testWidgets('PRICE_CHANGED refreshes the bill and says so', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);

    app.cart.failNext = const ApiError(code: ApiErrorCode.priceChanged);
    await placeOrder(tester);
    expect(
      find.text('Prices have changed. Please review your updated bill.'),
      findsOneWidget,
    );
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(app.cart.orders, isEmpty);
    expect(placeButton(tester).onPressed, isNotNull); // can try again
  });

  testWidgets('STOCK_UNAVAILABLE goes back to the cart with the flag', (
    tester,
  ) async {
    final app = await appWithCart();
    await openCheckout(tester, app);

    app.cart.stock[101] = 1;
    await placeOrder(tester);
    expect(find.byType(CartScreen), findsOneWidget);
    expect(find.text('Only 1 available'), findsOneWidget);
    expect(app.cart.orders, isEmpty);
  });

  testWidgets('double tap on Place order places one order', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    await tester.tap(find.byKey(const Key('pay-cod')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('place-order')));
    await tester.tap(find.byKey(const Key('place-order')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(app.cart.orders, hasLength(1));
  });

  testWidgets('COD is offered only when the server says the cart is eligible', (
    tester,
  ) async {
    final app = await appWithCart(
      commerce: FakeCommerceBackend(
        latency: Duration.zero,
        rules: const FakeBillRules(codMaxOrderValue: 10000),
      ),
    );
    await openCheckout(tester, app);
    expect(find.byKey(const Key('pay-online')), findsOneWidget);
    expect(find.byKey(const Key('pay-cod')), findsNothing);
  });

  testWidgets('a pin without a saved address cannot place an order', (
    tester,
  ) async {
    final app = await appWithCart(
      location: const DeliveryLocation(
        point: FakeServiceabilityRepository.storeLocation,
        title: 'Pinned location',
      ),
    );
    await openCheckout(tester, app);
    expect(find.byKey(const Key('needs-saved-address')), findsOneWidget);
    expect(placeButton(tester).onPressed, isNull);
  });
}

/// The verify endpoint can't be reached.
class _VerifyDown extends FakeCommerceBackend {
  _VerifyDown() : super(latency: Duration.zero);

  @override
  Future<PlacedOrder> verifyPayment(PaymentProof proof) async =>
      throw const ApiError(code: ApiErrorCode.network);
}
