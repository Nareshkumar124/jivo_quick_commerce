import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_controller.dart';
import 'package:customer_app/features/cart/presentation/cart_screen.dart';
import 'package:customer_app/features/checkout/data/fake_payment_launcher.dart';
import 'package:customer_app/features/checkout/presentation/checkout_controller.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/checkout/presentation/payment_failed_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<TestApp> appWithCart({FakeCommerceBackend? commerce}) async {
  final app = TestApp(tokens: signedInTokens, commerce: commerce);
  await app.cart.setQuantity(
    101,
    2,
    preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
  );
  return app;
}

/// An ONLINE order left unpaid before the app "restarted".
Future<PlacedOrder> leaveUnpaid(TestApp app) => app.cart.placeOrder(
  const PlaceOrderRequest(
    addressId: 1,
    paymentMethod: PaymentMethod.online,
    expectedGrandTotal: '503.00',
  ),
  idempotencyKey: 'before-restart-1',
);

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Scaffold).first));

Future<void> openCheckout(WidgetTester tester, TestApp app) async {
  tallView(tester);
  await app.pump(tester);
  routerOf(tester).push(Routes.cart);
  await tester.pumpAndSettle();
  routerOf(tester).push(Routes.checkout);
  await tester.pumpAndSettle();
}

ButtonStyleButton buttonIn(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        matchRoot: true,
      ),
    );

/// The status read fails until [fail] is cleared.
class _StatusDown extends FakeCommerceBackend {
  _StatusDown() : super(latency: Duration.zero);

  bool fail = true;

  @override
  Future<PlacedOrder> getOrder(int orderId) async {
    if (fail) throw const ApiError(code: ApiErrorCode.network);
    return super.getOrder(orderId);
  }
}

/// The order list isn't live yet (backend R2b answers 503).
class _OrdersDown extends FakeCommerceBackend {
  _OrdersDown() : super(latency: Duration.zero);

  @override
  Future<List<PlacedOrder>> activeOrders() async => throw const ApiError(
    code: ApiErrorCode.serviceUnavailable,
    rawCode: 'SERVICE_UNAVAILABLE',
    statusCode: 503,
  );
}

/// The server says retry is no longer allowed, while the device clock
/// still thinks the window is open.
class _RetryClosed extends FakeCommerceBackend {
  _RetryClosed() : super(latency: Duration.zero);

  @override
  Future<PlacedOrder> getOrder(int orderId) async {
    final order = await super.getOrder(orderId);
    return PlacedOrder(
      id: order.id,
      number: order.number,
      status: order.status,
      paymentMethod: order.paymentMethod,
      grandTotal: order.grandTotal,
      paymentExpiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
      canCancel: order.canCancel,
    );
  }
}

void main() {
  setUpAll(initializeFormatting);

  group('PAYMENT_PENDING recovery on launch (03 §2.9)', () {
    testWidgets('the unpaid order opens by itself, then from the banner', (
      tester,
    ) async {
      tallView(tester);
      final app = await appWithCart();
      final order = await leaveUnpaid(app);
      await app.pump(tester);

      // Launch: the server status of the pending order is shown.
      expect(find.byType(PaymentFailedScreen), findsOneWidget);
      expect(
        find.text("The payment for order ${order.number} wasn't completed."),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('pending-payment-banner')), findsOneWidget);
      expect(
        find.text('Order ${order.number} is waiting for payment'),
        findsOneWidget,
      );

      // Not again by itself; the banner opens it.
      await tester.tap(find.byKey(const Key('pending-payment-banner')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentFailedScreen), findsOneWidget);

      // Paid now: the banner goes away.
      await tester.tap(find.byKey(const Key('retry-payment')));
      await tester.pumpAndSettle();
      expect(find.text('Order placed!'), findsOneWidget);
      await tester.tap(find.byKey(const Key('continue-shopping')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pending-payment-banner')), findsNothing);
    });

    testWidgets('an order list that answers 503 never blocks Home', (
      tester,
    ) async {
      tallView(tester);
      final app = TestApp(tokens: signedInTokens, commerce: _OrdersDown());
      await app.pump(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('pending-payment-banner')), findsNothing);
      // An outage, not maintenance mode.
      expect(app.signals.current, isNull);
    });

    testWidgets('a webhook-paid order goes straight to success', (
      tester,
    ) async {
      tallView(tester);
      final app = await appWithCart();
      final order = await leaveUnpaid(app);
      app.cart.confirmByWebhook(order.id);
      await app.pump(tester);
      // Not pending any more: no screen, no banner.
      expect(find.byType(PaymentFailedScreen), findsNothing);
      expect(find.byKey(const Key('pending-payment-banner')), findsNothing);
    });
  });

  group('retry needs a fresh server read (review fix)', () {
    testWidgets('a failed status read keeps Retry and Cancel disabled', (
      tester,
    ) async {
      final backend = _StatusDown();
      final app = await appWithCart(commerce: backend);
      app.onPay = (_) => FakePaymentChoice.cancel;
      await openCheckout(tester, app);
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentFailedScreen), findsOneWidget);
      expect(
        find.text(
          "We couldn't check this order's payment status, so payment can't "
          'be retried yet.',
        ),
        findsOneWidget,
      );
      expect(buttonIn(tester, 'retry-payment').onPressed, isNull);
      expect(buttonIn(tester, 'change-payment-method').onPressed, isNull);
      expect(buttonIn(tester, 'cancel-order').onPressed, isNull);

      backend.fail = false;
      await tester.tap(find.byKey(const Key('check-again')));
      await tester.pumpAndSettle();
      expect(buttonIn(tester, 'retry-payment').onPressed, isNotNull);
      expect(find.byKey(const Key('check-again')), findsNothing);
    });

    testWidgets('the server, not the device clock, decides about retry', (
      tester,
    ) async {
      final app = await appWithCart(commerce: _RetryClosed());
      app.onPay = (_) => FakePaymentChoice.cancel;
      await openCheckout(tester, app);
      await tester.tap(find.byKey(const Key('place-order')));
      await tester.pumpAndSettle();

      // The device clock says an hour is left; the server says no.
      expect(buttonIn(tester, 'retry-payment').onPressed, isNull);
      expect(find.textContaining('Pay by'), findsNothing);
      expect(buttonIn(tester, 'cancel-order').onPressed, isNotNull);
    });
  });

  testWidgets('another unpaid order: offered instead of a second one', (
    tester,
  ) async {
    final app = await appWithCart();
    final first = await leaveUnpaid(app);
    tallView(tester);
    await app.pump(tester);
    // Launch opened the pending order; go to checkout from home anyway.
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    routerOf(tester).push(Routes.cart);
    await tester.pumpAndSettle();
    routerOf(tester).push(Routes.checkout);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('place-order')));
    await tester.pumpAndSettle();
    expect(find.text('An order is waiting for payment'), findsOneWidget);
    expect(app.cart.orders, hasLength(1));

    await tester.tap(find.byKey(const Key('open-pending-order')));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentFailedScreen), findsOneWidget);
    expect(
      find.text("The payment for order ${first.number} wasn't completed."),
      findsOneWidget,
    );
  });

  testWidgets('PRICE_CHANGED says what the total changed to', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    app.cart.failNext = const ApiError(
      code: ApiErrorCode.priceChanged,
      details: {'expected_grand_total': '503.00', 'grand_total': '528.00'},
    );
    await tester.tap(find.byKey(const Key('place-order')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your total changed from ₹503 to ₹528. Please check the updated bill.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CheckoutScreen), findsOneWidget);
  });

  testWidgets('STOCK_UNAVAILABLE names the item and how many are left', (
    tester,
  ) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    app.cart.stock[101] = 1;
    await tester.tap(find.byKey(const Key('place-order')));
    await tester.pumpAndSettle();
    expect(
      find.text('Only 1 of Jivo Canola Oil 1 L can be ordered now.'),
      findsOneWidget,
    );
    expect(find.byType(CartScreen), findsOneWidget);
  });

  testWidgets('sign-out drops the cart and checkout state', (tester) async {
    final app = await appWithCart();
    await openCheckout(tester, app);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CheckoutScreen)),
    );
    container.read(checkoutProvider.notifier).selectMethod(PaymentMethod.cod);
    expect(container.read(cartProvider).snapshot.isEmpty, isFalse);

    await app.cart.clear(); // the next user's server cart is empty
    await app.session.signOut();
    await tester.pumpAndSettle();
    expect(container.read(checkoutProvider).method, PaymentMethod.online);
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).snapshot.isEmpty, isTrue);
  });
}
