import 'package:customer_app/app/bootstrap.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/home/presentation/home_screen.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/presentation/order_detail_screen.dart';
import 'package:customer_app/features/orders/presentation/orders_screen.dart';
import 'package:customer_app/features/orders/presentation/pending_payment.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';
import '../cart/cart_fixtures.dart';

/// CA-10 (`design/screens/customer/home-active-order-card.md`): an order
/// in progress is one tap from Home.

final card = find.byKey(const Key('active-order-card'));

void view(WidgetTester tester, {Size size = const Size(800, 2400)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// A delivered, a cancelled and a packing order.
Future<(TestApp, FakeCommerceBackend)> homeWithDemoOrders(
  WidgetTester tester,
) async {
  final backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
  final app = TestApp(tokens: signedInTokens, commerce: backend);
  await app.pump(tester);
  return (app, backend);
}

Future<void> recheck(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(HomeScreen)),
  );
  await container.read(pendingPaymentProvider.notifier).check();
  await tester.pumpAndSettle();
}

Future<void> advance(
  FakeCommerceBackend backend,
  List<OrderStatus> statuses,
) async {
  final order = (await backend.activeOrders()).single;
  for (final status in statuses) {
    backend.advanceOrder(order.id, status);
  }
}

void main() {
  setUpAll(initializeFormatting);

  testWidgets('an order in progress: one button with its label and arrival '
      'time that opens tracking', (tester) async {
    view(tester);
    await homeWithDemoOrders(tester);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Packing your order')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('Arriving by')),
      findsOneWidget,
    );
    expect(find.text('Track ›'), findsOneWidget);
    expect(find.byKey(const Key('active-order-otp-ready')), findsNothing);
    expect(find.byKey(const Key('active-orders-more')), findsNothing);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(TrackingScreen), findsOneWidget);
  });

  testWidgets('out for delivery: "Delivery OTP ready", never the OTP', (
    tester,
  ) async {
    view(tester);
    final (_, backend) = await homeWithDemoOrders(tester);
    await advance(backend, [OrderStatus.packed, OrderStatus.outForDelivery]);
    await recheck(tester);

    expect(find.text('On the way'), findsOneWidget);
    expect(find.byKey(const Key('active-order-otp-ready')), findsOneWidget);
    expect(find.textContaining(RegExp(r'\b\d{4}\b')), findsNothing);
  });

  testWidgets('delivery failed: the red variant opens the order detail', (
    tester,
  ) async {
    view(tester);
    final (_, backend) = await homeWithDemoOrders(tester);
    await advance(backend, [
      OrderStatus.packed,
      OrderStatus.outForDelivery,
      OrderStatus.deliveryFailed,
    ]);
    await recheck(tester);

    expect(find.text('Delivery unsuccessful'), findsOneWidget);
    expect(
      find.text("We couldn't deliver it. See what happens next."),
      findsOneWidget,
    );
    expect(find.text('Details ›'), findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(OrderDetailScreen), findsOneWidget);
  });

  testWidgets('two orders: the newest on the card, "+1 more" opens My '
      'orders', (tester) async {
    view(tester);
    final (_, backend) = await homeWithDemoOrders(tester);
    // A second order: a COD order is PLACED at once.
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

    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Order placed')),
      findsOneWidget,
    );
    final more = find.byKey(const Key('active-orders-more'));
    expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
  });

  testWidgets('delivered: no card', (tester) async {
    view(tester);
    final (_, backend) = await homeWithDemoOrders(tester);
    await advance(backend, [
      OrderStatus.packed,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ]);
    await recheck(tester);
    expect(card, findsNothing);
  });

  testWidgets('one screen-reader stop that can be tapped and says where it '
      'goes', (tester) async {
    view(tester);
    final semantics = tester.ensureSemantics();
    await homeWithDemoOrders(tester);
    final node = tester.getSemantics(card);
    expect(node.label, startsWith('Packing your order. Arriving by '));
    expect(node.label, endsWith('. Opens tracking.'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('fits at 360×640 and ${scale}x text', (tester) async {
      view(tester, size: const Size(360, 640));
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (_, backend) = await homeWithDemoOrders(tester);
      await advance(backend, [OrderStatus.packed, OrderStatus.outForDelivery]);
      await recheck(tester);
      expect(card, findsOneWidget);
      final error = tester.takeException();
      if (error is FlutterError) fail(error.toStringDeep());
      expect(error, isNull);
    });
  }
}
