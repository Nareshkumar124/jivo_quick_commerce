import 'package:customer_app/features/cart/domain/cart.dart';
import 'package:customer_app/features/orders/domain/order.dart';
import 'package:customer_app/features/orders/domain/order_history.dart';
import 'package:customer_app/features/orders/presentation/cancel_order_sheet.dart';
import 'package:customer_app/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

const bill = CartBill(
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

final t0 = DateTime.utc(2026, 11, 4, 6);
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

OrderDetail detail(
  OrderStatus status, {
  List<OrderStatusEvent> history = const [],
  PaymentMethod method = PaymentMethod.online,
  PaymentStatus paymentStatus = PaymentStatus.paid,
  bool canCancel = false,
  DateTime? placedAt,
}) => OrderDetail(
  id: 1,
  number: 'JV-1',
  status: status,
  paymentMethod: method,
  paymentStatus: paymentStatus,
  storeName: 'Store',
  lines: const [
    OrderLineItem(
      variantId: 101,
      productId: 1,
      productName: 'Jivo Canola Oil',
      variantName: '1 L',
      mrp: '299.00',
      sellingPrice: '249.00',
      quantity: 2,
      lineMrpTotal: '598.00',
      lineTotal: '498.00',
    ),
  ],
  itemCount: 2,
  bill: bill,
  createdAt: t0,
  placedAt: placedAt,
  canCancel: canCancel,
  history: history,
);

OrderStatusEvent ev(OrderStatus s, int minutes) =>
    OrderStatusEvent(status: s, at: at(minutes));

/// `buildTimeline` and the order rules the screens rely on (P4-TC: order
/// detail timeline, cancel window `08 §7`, refund text `08 §6.4`).
void main() {
  group('timeline', () {
    test('packing: earlier stages done with their times, later upcoming', () {
      final steps = buildTimeline(
        detail(
          OrderStatus.packing,
          history: [
            ev(OrderStatus.placed, 0),
            ev(OrderStatus.accepted, 1),
            ev(OrderStatus.packing, 3),
          ],
        ),
      );
      expect(steps.map((s) => s.stage), OrderStage.values);
      expect(steps.map((s) => s.state), [
        TimelineStepState.done,
        TimelineStepState.done,
        TimelineStepState.current,
        TimelineStepState.upcoming,
        TimelineStepState.upcoming,
      ]);
      expect(steps[0].at, at(0));
      expect(steps[1].at, at(1));
      expect(steps[2].at, at(3));
      expect(steps[3].at, isNull);
    });

    test('PACKED stays in the packing stage, from its first event', () {
      final steps = buildTimeline(
        detail(
          OrderStatus.packed,
          history: [ev(OrderStatus.packing, 3), ev(OrderStatus.packed, 6)],
        ),
      );
      expect(steps[2].state, TimelineStepState.current);
      expect(steps[2].at, at(3));
    });

    test('delivered: every stage done', () {
      final steps = buildTimeline(detail(OrderStatus.delivered));
      expect(steps.every((s) => s.state == TimelineStepState.done), isTrue);
    });

    test('placed_at fills the Placed time without a history', () {
      final steps = buildTimeline(detail(OrderStatus.placed, placedAt: at(0)));
      expect(steps.first.at, at(0));
      expect(steps.first.state, TimelineStepState.current);
    });

    test('cancelled after acceptance: reached stages, then the ending', () {
      final steps = buildTimeline(
        detail(
          OrderStatus.cancelled,
          history: [
            ev(OrderStatus.placed, 0),
            ev(OrderStatus.accepted, 1),
            ev(OrderStatus.cancelled, 2),
          ],
        ),
      );
      expect(steps, hasLength(3));
      expect(steps[0].stage, OrderStage.placed);
      expect(steps[1].stage, OrderStage.confirmed);
      expect(steps[2].ending, OrderStatus.cancelled);
      expect(steps[2].at, at(2));
    });

    test('payment failed before placing: only the ending', () {
      final steps = buildTimeline(
        detail(
          OrderStatus.paymentFailed,
          history: [
            ev(OrderStatus.paymentPending, 0),
            ev(OrderStatus.paymentFailed, 15),
          ],
        ),
      );
      expect(steps.single.ending, OrderStatus.paymentFailed);
    });

    test('awaiting payment: no steps', () {
      expect(buildTimeline(detail(OrderStatus.paymentPending)), isEmpty);
    });

    test('delivery failed after pickup keeps the ride stages', () {
      final steps = timelineFor(
        OrderStatus.deliveryFailed,
        history: [ev(OrderStatus.outForDelivery, 10)],
      );
      expect(steps.map((s) => s.stage).take(4), [
        OrderStage.placed,
        OrderStage.confirmed,
        OrderStage.packing,
        OrderStage.onTheWay,
      ]);
      expect(steps.last.ending, OrderStatus.deliveryFailed);
    });
  });

  group('rules', () {
    test('active statuses match 08 §1 (DELIVERY_FAILED is not terminal)', () {
      expect(
        OrderStatus.values.where((s) => !s.isActive),
        containsAll([
          OrderStatus.delivered,
          OrderStatus.cancelled,
          OrderStatus.paymentFailed,
          OrderStatus.returned,
        ]),
      );
      expect(OrderStatus.deliveryFailed.isActive, isTrue);
    });

    test('past the cancel window an active order needs support', () {
      expect(detail(OrderStatus.packing).needsSupportToCancel, isTrue);
      expect(
        detail(OrderStatus.accepted, canCancel: true).needsSupportToCancel,
        isFalse,
      );
      expect(detail(OrderStatus.delivered).needsSupportToCancel, isFalse);
      expect(detail(OrderStatus.paymentPending).needsSupportToCancel, isFalse);
    });

    test('only finished orders are reordered', () {
      expect(detail(OrderStatus.delivered).canReorder, isTrue);
      expect(detail(OrderStatus.cancelled).canReorder, isTrue);
      expect(detail(OrderStatus.packing).canReorder, isFalse);
    });

    test('wire values parse, unknown ones fall back', () {
      expect(
        PaymentStatus.fromWire('REFUND_PENDING'),
        PaymentStatus.refundPending,
      );
      expect(PaymentStatus.fromWire('NEW'), PaymentStatus.unknown);
      expect(RefundStatus.fromWire('PROCESSED'), RefundStatus.processed);
      expect(RefundStatus.fromWire(null), RefundStatus.unknown);
      expect(
        ReorderSkipReason.fromWire('OUT_OF_STOCK'),
        ReorderSkipReason.outOfStock,
      );
      expect(ReorderSkipReason.fromWire('X'), ReorderSkipReason.unknown);
    });
  });

  group('cancel sheet text (08 §6.4)', () {
    final l10n = AppLocalizationsEn();

    test('paid online: full refund of the server total in 5–7 days', () {
      expect(
        cancelRefundText(l10n, detail(OrderStatus.placed)),
        'You will get a full refund of ₹503 to your original payment method '
        'in 5–7 working days.',
      );
    });

    test('COD: nothing due; awaiting payment: nothing to refund', () {
      expect(
        cancelRefundText(
          l10n,
          detail(
            OrderStatus.accepted,
            method: PaymentMethod.cod,
            paymentStatus: PaymentStatus.codPending,
          ),
        ),
        l10n.cancelRefundCod,
      );
      expect(
        cancelRefundText(
          l10n,
          detail(
            OrderStatus.paymentPending,
            paymentStatus: PaymentStatus.pending,
          ),
        ),
        l10n.cancelRefundUnpaid,
      );
    });

    test('reasons: payment ones only while awaiting payment', () {
      expect(
        cancelReasonsFor(OrderStatus.paymentPending),
        contains(CancelReason.changePaymentMethod),
      );
      expect(
        cancelReasonsFor(OrderStatus.placed),
        isNot(contains(CancelReason.paymentProblem)),
      );
      expect(cancelReasonsFor(OrderStatus.accepted).last, CancelReason.other);
    });
  });
}
