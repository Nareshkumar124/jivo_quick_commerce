import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cart/data/fake_commerce_backend.dart';
import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/tracking/data/track_repository.dart';
import 'package:customer_app/features/tracking/domain/order_track.dart';
import 'package:customer_app/features/tracking/presentation/delivery_cards.dart';
import 'package:customer_app/features/tracking/presentation/tracking_providers.dart';
import 'package:customer_app/features/tracking/presentation/tracking_screen.dart';
import 'package:customer_app/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/widget_harness.dart';

const _bill = CartBill(
  mrpTotal: '598.00',
  itemTotal: '498.00',
  productDiscount: '100.00',
  couponDiscount: '0.00',
  deliveryFee: '0.00',
  smallCartFee: '0.00',
  handlingFee: '5.00',
  tip: '0.00',
  grandTotal: '503.00',
  totalSavings: '100.00',
);

OrderDetail _detail(
  OrderStatus status, {
  PaymentMethod method = PaymentMethod.online,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  String? amountRefunded,
}) => OrderDetail(
  id: 1,
  number: 'JV-1',
  status: status,
  paymentMethod: method,
  paymentStatus: paymentStatus,
  storeName: 'Store',
  lines: const [],
  itemCount: 0,
  bill: _bill,
  createdAt: DateTime.utc(2026, 11, 5),
  amountRefunded: amountRefunded,
);

/// P5 slice 5.3 (T-516b): delivery task stages, the delivery OTP, the
/// refund note on a failed delivery and "pay ₹X to the rider" for COD.
void main() {
  final l10n = AppLocalizationsEn();

  group('delivery stage', () {
    test('task status from the wire', () {
      expect(
        DeliveryTaskStatus.fromWire('AT_CUSTOMER'),
        DeliveryTaskStatus.atCustomer,
      );
      expect(
        DeliveryTaskStatus.fromWire('PICKED_UP'),
        DeliveryTaskStatus.pickedUp,
      );
      expect(
        DeliveryTaskStatus.fromWire('NEW_STATE'),
        DeliveryTaskStatus.unknown,
      );
      expect(DeliveryTaskStatus.fromWire(null), isNull);
    });

    test('stage from the order status, refined by the task', () {
      expect(deliveryStageFor(OrderStatus.packing), isNull);
      expect(deliveryStageFor(OrderStatus.packed), isNull);
      expect(
        deliveryStageFor(OrderStatus.outForDelivery),
        DeliveryStage.pickedUp,
      );
      expect(
        deliveryStageFor(
          OrderStatus.outForDelivery,
          task: DeliveryTaskStatus.pickedUp,
        ),
        DeliveryStage.pickedUp,
      );
      expect(
        deliveryStageFor(
          OrderStatus.outForDelivery,
          task: DeliveryTaskStatus.atCustomer,
        ),
        DeliveryStage.arriving,
      );
      expect(
        deliveryStageFor(OrderStatus.deliveryFailed),
        DeliveryStage.failed,
      );
      expect(deliveryStageFor(OrderStatus.returned), DeliveryStage.returned);
      expect(deliveryStageFor(OrderStatus.delivered), isNull);
      expect(deliveryStageFor(OrderStatus.cancelled), isNull);
    });

    test('fake: picked up, arriving at the door, failed, returned', () async {
      final repo = FakeTrackRepository(ridePings: 2, failDelivery: true);
      final steps = [for (var i = 0; i < 6; i++) await repo.fetch(9)];
      expect(steps.map((t) => t.stage), [
        null,
        null,
        DeliveryStage.pickedUp,
        DeliveryStage.arriving,
        DeliveryStage.failed,
        DeliveryStage.returned,
      ]);
      expect(steps[3].deliveryOtp, '4821');
      expect(steps[4].deliveryOtp, isNull);
      expect(steps[4].etaAt, isNull);
      expect(steps[5].rider, isNull);
    });
  });

  group('codAmountDue', () {
    test('the server grand total while a COD order is to be collected', () {
      for (final status in [
        OrderStatus.placed,
        OrderStatus.packing,
        OrderStatus.outForDelivery,
      ]) {
        expect(
          _detail(
            status,
            method: PaymentMethod.cod,
            paymentStatus: PaymentStatus.codPending,
          ).codAmountDue,
          '503.00',
        );
      }
    });

    test('nothing for online, collected, failed or cancelled orders', () {
      expect(_detail(OrderStatus.outForDelivery).codAmountDue, isNull);
      expect(
        _detail(
          OrderStatus.delivered,
          method: PaymentMethod.cod,
          paymentStatus: PaymentStatus.codCollected,
        ).codAmountDue,
        isNull,
      );
      for (final status in [
        OrderStatus.deliveryFailed,
        OrderStatus.returned,
        OrderStatus.cancelled,
      ]) {
        expect(
          _detail(
            status,
            method: PaymentMethod.cod,
            paymentStatus: PaymentStatus.codPending,
          ).codAmountDue,
          isNull,
        );
      }
    });
  });

  group('refundNoteFor', () {
    test('refund pending, refunded with the server amount, COD', () {
      expect(
        refundNoteFor(
          l10n,
          _detail(
            OrderStatus.returned,
            paymentStatus: PaymentStatus.refundPending,
          ),
        ),
        l10n.refundNoteStarted,
      );
      final done = refundNoteFor(
        l10n,
        _detail(
          OrderStatus.returned,
          paymentStatus: PaymentStatus.refunded,
          amountRefunded: '503.00',
        ),
      );
      expect(done, contains('503'));
      expect(done, contains('refunded'));
      expect(
        refundNoteFor(
          l10n,
          _detail(
            OrderStatus.deliveryFailed,
            method: PaymentMethod.cod,
            paymentStatus: PaymentStatus.codPending,
          ),
        ),
        l10n.nothingToPay,
      );
    });

    test('nothing while the server has no refund to report', () {
      expect(refundNoteFor(l10n, _detail(OrderStatus.deliveryFailed)), isNull);
      expect(
        refundNoteFor(
          l10n,
          _detail(OrderStatus.returned, paymentStatus: PaymentStatus.refunded),
        ),
        isNull,
      );
    });
  });

  group('tracking screen', () {
    late FakeCommerceBackend backend;
    late int codOrder;

    setUp(() {
      backend = FakeCommerceBackend(latency: Duration.zero)..seedDemoOrders();
      codOrder = backend.orders
          .firstWhere((o) => o.status == OrderStatus.packing)
          .id;
    });

    Widget screen(FakeTrackRepository track) => harness(
      TrackingScreen(orderId: codOrder),
      overrides: [
        trackRepositoryProvider.overrideWithValue(track),
        orderHistoryRepositoryProvider.overrideWithValue(backend),
        trackPollIntervalProvider.overrideWithValue(Duration.zero),
      ],
    );

    testWidgets('arriving: stage, OTP with the share hint, COD amount', (
      tester,
    ) async {
      backend
        ..advanceOrder(codOrder, OrderStatus.packed)
        ..advanceOrder(codOrder, OrderStatus.outForDelivery);
      await tester.pumpWidget(
        screen(FakeTrackRepository(ridePings: 2, startStep: 3)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery-stage-arriving')), findsOneWidget);
      expect(find.text('Rider is arriving'), findsOneWidget);
      expect(find.text('4821'), findsOneWidget);
      expect(find.text(l10n.trackingOtpHint), findsOneWidget);
      expect(find.textContaining('Share this with your rider'), findsOneWidget);
      final grandTotal = (await backend.getOrderDetail(codOrder))
          .bill
          .grandTotal;
      final cod = tester.widget<Text>(find.byKey(const Key('cod-due-amount')));
      expect(cod.data, contains(grandTotal.split('.').first));
      expect(cod.data, startsWith('Pay ₹'));
    });

    testWidgets(
      'picked up: stage card, COD hidden until the order catches up',
      (tester) async {
        await tester.pumpWidget(
          screen(FakeTrackRepository(ridePings: 3, startStep: 2)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('delivery-stage-pickedUp')),
          findsOneWidget,
        );
        // The fake order is still PACKING: no amount from a stale order.
        expect(find.byKey(const Key('cod-due')), findsNothing);
      },
    );

    testWidgets('delivery failed (COD): nothing to pay, no OTP', (
      tester,
    ) async {
      backend
        ..advanceOrder(codOrder, OrderStatus.packed)
        ..advanceOrder(codOrder, OrderStatus.outForDelivery)
        ..advanceOrder(codOrder, OrderStatus.deliveryFailed);
      await tester.pumpWidget(
        screen(
          FakeTrackRepository(ridePings: 2, startStep: 4, failDelivery: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery-stage-failed')), findsOneWidget);
      expect(find.text('Delivery failed'), findsOneWidget);
      final note = tester.widget<Text>(
        find.byKey(const Key('delivery-refund-note')),
      );
      expect(note.data, l10n.nothingToPay);
      expect(find.byKey(const Key('delivery-otp')), findsNothing);
      expect(find.byKey(const Key('cod-due')), findsNothing);
    });
  });

  testWidgets('returned: the card shows the refund note', (tester) async {
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: DeliveryStageCard(
            stage: DeliveryStage.returned,
            refundNote: l10n.refundNoteStarted,
          ),
        ),
      ),
    );
    expect(find.text('Order returned'), findsOneWidget);
    expect(find.byKey(const Key('delivery-refund-note')), findsOneWidget);
    expect(find.text(l10n.refundNoteStarted), findsOneWidget);
  });

  testWidgets('picked up: no refund note even when one is passed', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: DeliveryStageCard(
            stage: DeliveryStage.pickedUp,
            refundNote: l10n.refundNoteStarted,
          ),
        ),
      ),
    );
    expect(find.text('Order picked up'), findsOneWidget);
    expect(find.byKey(const Key('delivery-refund-note')), findsNothing);
  });
}
