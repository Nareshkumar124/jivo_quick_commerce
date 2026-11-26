// Back from an order never closes the app (bug 2026-11-26: "When I go back
// from an order, the app closes"). Every way into the order screens is
// covered: after placing an order, the order-placed screen's button, a
// notification tap, the Home active-order card, My orders and a `go` deep
// link. Android back is `handlePopRoute`; an app exit is a
// `SystemNavigator.pop` call on the platform channel.

import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/app/redirect.dart';
import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/checkout/presentation/checkout_screen.dart';
import 'package:customer_app/features/checkout/presentation/order_success_screen.dart';
import 'package:customer_app/features/checkout/presentation/payment_failed_screen.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/cart/presentation/cart_screen.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/notifications/data/device_repository.dart';
import 'package:customer_app/features/notifications/data/push_messaging.dart';
import 'package:customer_app/features/notifications/presentation/push_registration.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/presentation/order_detail_screen.dart';
import 'package:customer_app/features/orders/presentation/orders_screen.dart';
import 'package:customer_app/features/rating/presentation/rate_order_screen.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/checkout/checkout_flow_test.dart'
    show appWithCart, openCheckout, placeOrder, tallView;
import '../features/cart/cart_fixtures.dart';
import '../features/orders/active_order_card_test.dart' show card, recheck;
import '../helpers/test_app.dart';

/// Android back, then settle.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

void expectNoCheckout() {
  expect(find.byType(CheckoutScreen), findsNothing);
  expect(find.byType(CartScreen), findsNothing);
  expect(find.byType(OrderSuccessScreen), findsNothing);
  expect(find.byType(PaymentFailedScreen), findsNothing);
}

void main() {
  setUpAll(initializeFormatting);

  late List<String> platformCalls;

  void recordPlatform(WidgetTester tester) {
    platformCalls = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  bool exited() => platformCalls.contains('SystemNavigator.pop');

  /// A signed-in app on Home with the demo orders, tracking on.
  Future<(TestApp, FakeCommerceBackend)> appWithOrders(
    WidgetTester tester, {
    FakePushMessaging? push,
  }) async {
    tallView(tester);
    final backend = FakeCommerceBackend(latency: Duration.zero)
      ..seedDemoOrders();
    final app = TestApp(
      tokens: signedInTokens,
      commerce: backend,
      extraOverrides: [
        trackingAvailableProvider.overrideWithValue(true),
        trackRepositoryProvider.overrideWithValue(FakeTrackRepository()),
        trackPollIntervalProvider.overrideWithValue(Duration.zero),
        if (push != null) ...[
          pushMessagingProvider.overrideWithValue(push),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
        ],
      ],
    );
    await app.pump(tester);
    recordPlatform(tester);
    return (app, backend);
  }

  group('after placing an order', () {
    testWidgets('order placed → View order → back: My orders, then Home; '
        'never checkout, and the app stays open', (tester) async {
      final app = await appWithCart();
      await openCheckout(tester, app);
      recordPlatform(tester);
      await tester.tap(find.byKey(const Key('pay-cod')));
      await tester.pumpAndSettle();
      await placeOrder(tester);
      expect(find.byType(OrderSuccessScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('track-order')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      // Nothing is behind it (the `go` replaced checkout and success).
      expect(routerOf(tester).canPop(), isFalse);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(OrderDetailScreen), findsNothing);
      expect(find.byType(OrdersScreen), findsOneWidget);
      expectNoCheckout();

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
      expectNoCheckout();

      // Home is the root: back there closes the app as normal.
      await systemBack(tester);
      expect(exited(), isTrue);
    });

    testWidgets('order detail app bar back also goes to My orders', (
      tester,
    ) async {
      final app = await appWithCart();
      await openCheckout(tester, app);
      recordPlatform(tester);
      await tester.tap(find.byKey(const Key('pay-cod')));
      await tester.pumpAndSettle();
      await placeOrder(tester);
      await tester.tap(find.byKey(const Key('track-order')));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(OrdersScreen), findsOneWidget);
      expectNoCheckout();

      // My orders has nothing behind it either: its back goes Home.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exited(), isFalse);
    });

    testWidgets('online payment: back from the placed order never shows the '
        'payment or checkout again', (tester) async {
      final app = await appWithCart();
      await openCheckout(tester, app);
      recordPlatform(tester);
      await placeOrder(tester); // online, the fake sheet succeeds
      expect(find.byType(OrderSuccessScreen), findsOneWidget);

      // Back on the success screen: Home (not checkout).
      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expectNoCheckout();
      expect(exited(), isFalse);
    });
  });

  group('other ways in', () {
    testWidgets('go deep link to an order: back → My orders → Home', (
      tester,
    ) async {
      final (_, backend) = await appWithOrders(tester);
      final id = backend.orders.first.id;
      routerOf(tester).go(Routes.order(id));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(OrdersScreen), findsOneWidget);
      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exited(), isFalse);
    });

    testWidgets('go deep link to tracking: back → My orders, not exit', (
      tester,
    ) async {
      final (_, backend) = await appWithOrders(tester);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
      routerOf(tester).go(Routes.orderTracking(id));
      await tester.pumpAndSettle();
      expect(find.byType(TrackingScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(OrdersScreen), findsOneWidget);
    });

    testWidgets('rating opened alone: back → the order, not exit', (
      tester,
    ) async {
      final (_, backend) = await appWithOrders(tester);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.delivered)
          .id;
      routerOf(tester).go(Routes.rateOrder(id));
      await tester.pumpAndSettle();
      expect(find.byType(RateOrderScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });

    testWidgets('launching notification → tracking: back → Home', (
      tester,
    ) async {
      final backend = FakeCommerceBackend(latency: Duration.zero)
        ..seedDemoOrders();
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
      tallView(tester);
      final push = FakePushMessaging(
        token: 't',
        initialNotification: {'type': 'order', 'order_id': '$id'},
      );
      final app = TestApp(
        tokens: signedInTokens,
        commerce: backend,
        extraOverrides: [
          pushMessagingProvider.overrideWithValue(push),
          deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
          trackingAvailableProvider.overrideWithValue(true),
          trackRepositoryProvider.overrideWithValue(FakeTrackRepository()),
          trackPollIntervalProvider.overrideWithValue(Duration.zero),
        ],
      );
      await app.pump(tester);
      recordPlatform(tester);
      expect(find.byType(TrackingScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('tap while running → tracking: back → where the user was', (
      tester,
    ) async {
      final push = FakePushMessaging(token: 't');
      final (_, backend) = await appWithOrders(tester, push: push);
      final id = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
      push.tap({'type': 'order', 'order_id': '$id'});
      await tester.pumpAndSettle();
      expect(find.byType(TrackingScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('My orders → order → back → My orders → back → Home', (
      tester,
    ) async {
      final (_, backend) = await appWithOrders(tester);
      routerOf(tester).push(Routes.orders);
      await tester.pumpAndSettle();
      final id = backend.orders.first.id;
      await tester.tap(find.byKey(Key('order-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);

      await systemBack(tester);
      expect(find.byType(OrdersScreen), findsOneWidget);
      await systemBack(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(exited(), isFalse);
    });

    testWidgets('Home active-order card → tracking: back → Home', (
      tester,
    ) async {
      await appWithOrders(tester);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byType(TrackingScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('Home "+1 more" → My orders: back → Home, not exit', (
      tester,
    ) async {
      final (_, backend) = await appWithOrders(tester);
      // A second order (COD is PLACED at once) shows "+1 more".
      await backend.setQuantity(
        101,
        1,
        preview: CartLinePreview.of(oil(), 'Jivo Canola Oil'),
      );
      final bill = (await backend.load(addressId: 1)).bill!;
      await backend.placeOrder(
        PlaceOrderRequest(
          addressId: 1,
          paymentMethod: PaymentMethod.cod,
          expectedGrandTotal: bill.grandTotal,
        ),
        idempotencyKey: 'second-order',
      );
      await recheck(tester);
      await tester.tap(find.byKey(const Key('active-orders-more')));
      await tester.pumpAndSettle();
      expect(find.byType(OrdersScreen), findsOneWidget);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('My orders opened alone (go): back → Home, not exit', (
      tester,
    ) async {
      await appWithOrders(tester);
      routerOf(tester).go(Routes.orders);
      await tester.pumpAndSettle();
      expect(routerOf(tester).canPop(), isFalse);

      await systemBack(tester);
      expect(exited(), isFalse);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
