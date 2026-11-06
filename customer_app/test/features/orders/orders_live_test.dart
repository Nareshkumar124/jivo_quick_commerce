import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_ws.dart';
import '../../helpers/test_app.dart';

/// Order status over the order socket on "My orders" and the order detail
/// (T-613, `06 §4`).
void main() {
  late FakeCommerceBackend backend;
  late FakeOrderRealtime rt;

  setUp(() {
    backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
    rt = FakeOrderRealtime();
  });

  TestApp app() => TestApp(
    tokens: signedInTokens,
    commerce: backend,
    realtime: rt,
    extraOverrides: [
      trackingAvailableProvider.overrideWithValue(false),
      trackPollIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );

  Future<void> openOrders(WidgetTester tester) async {
    await app().pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-orders')));
    await tester.pumpAndSettle();
  }

  testWidgets('the list opens sockets for active orders and re-reads on a '
      'new status', (tester) async {
    final packing = backend.orders
        .firstWhere((o) => o.status == OrderStatus.packing)
        .id;
    await openOrders(tester);
    final active = backend.orders.where((o) => o.status.isActive).length;
    expect(rt.sockets.length, active.clamp(0, 3));
    expect(rt.sockets.keys, contains(packing));

    // The store packs and the rider picks up; the socket says so.
    backend
      ..advanceOrder(packing, OrderStatus.packed)
      ..advanceOrder(packing, OrderStatus.outForDelivery);
    final conn = rt.server.connections.firstWhere(
      (c) => c.uri.path == '/ws/v1/orders/$packing/',
    );
    conn
      ..authOk()
      ..push('order.status', statusData(packing, 'OUT_FOR_DELIVERY'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(Key('order-$packing')),
        matching: find.text('On the way'),
      ),
      findsOneWidget,
    );

    // The detail shares the socket and follows the next status.
    await tester.tap(find.byKey(Key('order-$packing')));
    await tester.pumpAndSettle();
    expect(
      rt.server.connections.where(
        (c) => c.uri.path == '/ws/v1/orders/$packing/',
      ),
      hasLength(1),
    );
    backend.advanceOrder(packing, OrderStatus.delivered);
    conn.push('order.status', statusData(packing, 'DELIVERED'));
    await tester.pumpAndSettle();
    expect(find.text('Delivered'), findsWidgets);
  });
}
