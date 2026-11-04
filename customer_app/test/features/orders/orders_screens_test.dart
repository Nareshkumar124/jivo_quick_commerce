import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// "My orders", order detail, the cancel sheet, reorder and invoice
/// (`03 §2.10`) on the fake server.
void main() {
  late FakeCommerceBackend backend;

  setUp(() {
    backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
  });

  int idOf(OrderStatus status) =>
      backend.orders.firstWhere((o) => o.status == status).id;

  TestApp app({bool tracking = false, int trackStep = 0}) => TestApp(
    tokens: signedInTokens,
    commerce: backend,
    extraOverrides: [
      trackingAvailableProvider.overrideWithValue(tracking),
      trackRepositoryProvider.overrideWithValue(
        FakeTrackRepository(startStep: trackStep),
      ),
      trackPollIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );

  Future<void> openOrders(WidgetTester tester, TestApp app) async {
    await app.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-orders')));
    await tester.pumpAndSettle();
  }

  Future<void> openOrder(WidgetTester tester, int id) async {
    await tester.tap(find.byKey(Key('order-$id')));
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(
        of: find.byKey(const Key('order-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the list shows active orders first, then past ones', (
    tester,
  ) async {
    await openOrders(tester, app());
    expect(find.text('Active orders'), findsOneWidget);
    expect(find.text('Past orders'), findsOneWidget);
    expect(find.text('Packing your order'), findsOneWidget);
    expect(find.text('Delivered'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    final activeY = tester.getTopLeft(find.text('Active orders')).dy;
    final pastY = tester.getTopLeft(find.text('Past orders')).dy;
    expect(activeY, lessThan(pastY));
  });

  testWidgets('no orders: the empty state', (tester) async {
    backend = FakeCommerceBackend(latency: Duration.zero);
    await openOrders(tester, app());
    expect(find.byKey(const Key('orders-empty')), findsOneWidget);
  });

  testWidgets('a failed load offers retry', (tester) async {
    final a = app();
    await a.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    backend.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(find.byKey(const Key('account-orders')));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-list')), findsOneWidget);
  });

  testWidgets('delivered order: timeline, bill, reorder, invoice', (
    tester,
  ) async {
    final a = app();
    final id = idOf(OrderStatus.delivered);
    await openOrders(tester, a);
    await openOrder(tester, id);

    expect(find.byKey(const Key('order-timeline')), findsOneWidget);
    expect(find.text('Jivo Canola Oil'), findsOneWidget);
    await scrollTo(tester, find.byKey(const Key('bill-to-pay')));
    expect(find.byKey(const Key('bill-to-pay')), findsOneWidget);
    expect(find.text('Paid on delivery'), findsOneWidget);
    // Delivered: no cancel, no support card.
    expect(find.byKey(const Key('cancel-order')), findsNothing);
    expect(find.byKey(const Key('contact-support')), findsNothing);

    await scrollTo(tester, find.byKey(const Key('download-invoice')));
    await tester.tap(find.byKey(const Key('download-invoice')));
    await tester.pumpAndSettle();
    expect(a.urls.opened.single.path, endsWith('.pdf'));

    await scrollTo(tester, find.byKey(const Key('reorder')));
    await tester.tap(find.byKey(const Key('reorder')));
    await tester.pumpAndSettle();
    // The groundnut oil is out of stock now.
    expect(find.byKey(const Key('reorder-result')), findsOneWidget);
    expect(find.textContaining('Jivo Groundnut Oil'), findsOneWidget);
    expect(find.textContaining('out of stock'), findsOneWidget);
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();
    expect(find.text('Jivo Canola Oil'), findsWidgets);
    expect((await backend.load()).quantityOf(101), 2);
  });

  testWidgets('a non-https invoice link shows "could not open"', (
    tester,
  ) async {
    final a = app();
    final id = idOf(OrderStatus.delivered);
    await openOrders(tester, a);
    await openOrder(tester, id);
    backend.invoiceUrlOverride = Uri.parse('http://invoices.example.com/x.pdf');
    await scrollTo(tester, find.byKey(const Key('download-invoice')));
    await tester.tap(find.byKey(const Key('download-invoice')));
    await tester.pumpAndSettle();
    expect(a.urls.opened, isEmpty);
    expect(find.textContaining("Couldn't open the invoice"), findsOneWidget);
  });

  testWidgets('a refused invoice request shows "could not open"', (
    tester,
  ) async {
    final a = app();
    await openOrders(tester, a);
    await openOrder(tester, idOf(OrderStatus.delivered));
    backend.failNext = const ApiError(code: ApiErrorCode.serviceUnavailable);
    await scrollTo(tester, find.byKey(const Key('download-invoice')));
    await tester.tap(find.byKey(const Key('download-invoice')));
    await tester.pumpAndSettle();
    expect(find.textContaining("Couldn't open the invoice"), findsOneWidget);
  });

  testWidgets('refunded order shows the refund', (tester) async {
    await openOrders(tester, app());
    await openOrder(tester, idOf(OrderStatus.cancelled));
    await scrollTo(tester, find.byKey(const Key('refund-line')));
    expect(
      find.textContaining('refunded to your original payment method'),
      findsOneWidget,
    );
    expect(find.text('Refunded'), findsOneWidget);
  });

  testWidgets('packing is past the window: contact support, no cancel', (
    tester,
  ) async {
    final a = app();
    await openOrders(tester, a);
    await openOrder(tester, idOf(OrderStatus.packing));
    await scrollTo(tester, find.byKey(const Key('contact-support')));
    expect(find.byKey(const Key('cancel-order')), findsNothing);
    await tester.tap(find.text('Contact support'));
    await tester.pumpAndSettle();
    expect(a.urls.opened.single.scheme, 'tel');
  });

  testWidgets('cancel: reason required, refund info, then cancelled', (
    tester,
  ) async {
    final id = idOf(OrderStatus.packing);
    // Make it a paid online order inside the window.
    final online = await _placePaidOnline(backend);
    await openOrders(tester, app());
    await openOrder(tester, online);
    expect(id, isNot(online));

    await scrollTo(tester, find.byKey(const Key('cancel-order')));
    await tester.tap(find.byKey(const Key('cancel-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-sheet')), findsOneWidget);
    expect(
      find.textContaining('full refund of ₹'),
      findsOneWidget,
      reason: '08 §6.4: paid online → full refund to the source',
    );
    final confirm = find.byKey(const Key('cancel-confirm'));
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(of: confirm, matching: find.byType(FilledButton)),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Changed my mind'));
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cancel-sheet')), findsNothing);
    expect(find.text('Order cancelled'), findsOneWidget);
    // The detail now shows the server's cancelled order.
    await tester.scrollUntilVisible(
      find.byKey(const Key('order-status')),
      -200,
      scrollable: find.descendant(
        of: find.byKey(const Key('order-detail')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('order-status'))).data,
      'Cancelled',
    );
    expect(backend.cancelReasonOf(online), CancelReason.changedMind);
    await scrollTo(tester, find.byKey(const Key('refund-line')));
    expect(find.textContaining('Refund of ₹'), findsOneWidget);
  });

  testWidgets('a cancel refused by the server shows the reason', (
    tester,
  ) async {
    final online = await _placePaidOnline(backend);
    await openOrders(tester, app());
    await openOrder(tester, online);
    await scrollTo(tester, find.byKey(const Key('cancel-order')));
    await tester.tap(find.byKey(const Key('cancel-order')));
    await tester.pumpAndSettle();
    // The store started packing meanwhile.
    backend.advanceOrder(online, OrderStatus.packing);
    await tester.tap(find.text('Ordered by mistake'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cancel-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cancel-error')), findsOneWidget);
  });

  testWidgets('track order opens tracking when it is available', (
    tester,
  ) async {
    await openOrders(tester, app(tracking: true));
    await openOrder(tester, idOf(OrderStatus.packing));
    await tester.tap(find.byKey(const Key('track-order')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking')), findsOneWidget);
  });

  testWidgets('out for delivery: the detail shows the delivery OTP and the '
      'rider with a call button (P5)', (tester) async {
    final a = app(tracking: true, trackStep: 2);
    await openOrders(tester, a);
    await openOrder(tester, idOf(OrderStatus.packing));

    expect(find.byKey(const Key('delivery-otp')), findsOneWidget);
    expect(find.byKey(const Key('delivery-otp-code')), findsOneWidget);
    expect(find.text('4821'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('Delivery OTP 4 8 2 1')), findsOneWidget);
    semantics.dispose();
    expect(find.byKey(const Key('rider-card')), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call-rider')));
    await tester.pumpAndSettle();
    expect(a.urls.opened.single, Uri(scheme: 'tel', path: '+919000000099'));
  });

  testWidgets('confirmed, no rider yet: no OTP or rider card', (tester) async {
    await openOrders(tester, app(tracking: true));
    await openOrder(tester, idOf(OrderStatus.packing));
    expect(find.byKey(const Key('delivery-otp')), findsNothing);
    expect(find.byKey(const Key('rider-card')), findsNothing);
  });

  testWidgets('without tracking the detail has no track button', (
    tester,
  ) async {
    await openOrders(tester, app());
    await openOrder(tester, idOf(OrderStatus.packing));
    expect(find.byKey(const Key('track-order')), findsNothing);
  });
}

/// A paid online order, `PLACED` (inside the cancel window).
Future<int> _placePaidOnline(FakeCommerceBackend backend) async {
  // Re-order the delivered demo order's canola oil into the cart.
  final delivered = backend.orders.firstWhere(
    (o) => o.status == OrderStatus.delivered,
  );
  await backend.reorder(delivered.id);
  final cart = await backend.load(addressId: 1);
  final placed = await backend.placeOrder(
    PlaceOrderRequest(
      addressId: 1,
      paymentMethod: PaymentMethod.online,
      expectedGrandTotal: cart.bill!.grandTotal,
    ),
    idempotencyKey: 'paid-online',
  );
  backend.confirmByWebhook(placed.id);
  return placed.id;
}
