import 'package:flutter/foundation.dart';

import '../../addresses/domain/saved_address.dart';
import '../../cart/domain/cart.dart';
import 'order.dart';

/// Order history as the "My orders" and order-detail screens show it
/// (`03 §2.10`, `06 §2.6`: `OrderSummary`, `Order`). Money fields are the
/// server's decimal strings, shown with `formatRupees` and never added up.

/// `PaymentStatusEnum` (`07 §2.6`, `08 §4`).
enum PaymentStatus {
  pending('PENDING'),
  paid('PAID'),
  failed('FAILED'),
  refundPending('REFUND_PENDING'),
  refunded('REFUNDED'),
  partiallyRefunded('PARTIALLY_REFUNDED'),
  codPending('COD_PENDING'),
  codCollected('COD_COLLECTED'),

  /// A status this build doesn't know (a newer server).
  unknown(null);

  const PaymentStatus(this.wireValue);

  final String? wireValue;

  static PaymentStatus fromWire(String? value) => values.firstWhere(
    (status) => status.wireValue != null && status.wireValue == value,
    orElse: () => unknown,
  );
}

/// A row of the order list (`OrderSummary`).
@immutable
class OrderListItem {
  const OrderListItem({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.storeName,
    required this.itemCount,
    required this.grandTotal,
    required this.createdAt,
    this.imageUrls = const [],
    this.placedAt,
    this.etaAt,
    this.canRetryPayment = false,
  });

  final int id;
  final String number;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;
  final PaymentStatus paymentStatus;
  final String storeName;

  /// Units in the order, from the server.
  final int itemCount;

  /// Up to 4 thumbnails.
  final List<String> imageUrls;
  final String grandTotal;
  final DateTime createdAt;
  final DateTime? placedAt;
  final DateTime? etaAt;
  final bool canRetryPayment;

  bool get isActive => status.isActive;
}

/// One page of `GET /orders/` (all orders; the server lists active ones
/// first, newest first within each group).
@immutable
class OrderPage {
  const OrderPage({required this.items, this.nextPage});

  final List<OrderListItem> items;

  /// Null on the last page.
  final int? nextPage;
}

/// An order line (`OrderLine`): the price snapshot taken at placement.
@immutable
class OrderLineItem {
  const OrderLineItem({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.variantName,
    required this.mrp,
    required this.sellingPrice,
    required this.quantity,
    required this.lineMrpTotal,
    required this.lineTotal,
    this.imageUrl,
    this.quantityUnavailable = 0,
  });

  final int variantId;
  final int productId;
  final String productName;
  final String variantName;
  final String? imageUrl;
  final String mrp;
  final String sellingPrice;
  final int quantity;
  final String lineMrpTotal;
  final String lineTotal;

  /// Units the store marked unavailable (`08` T8a); the bill already
  /// reflects them.
  final int quantityUnavailable;
}

/// Who cancelled an order (`CancelledByEnum`).
enum CancelledBy { customer, store, rider, ops, system, unknown }

/// Why and when an order was cancelled (`OrderCancellation`).
@immutable
class OrderCancellationInfo {
  const OrderCancellationInfo({
    required this.reason,
    required this.message,
    required this.cancelledBy,
    required this.cancelledAt,
  });

  /// The `OrderCancelReasonEnum` wire value.
  final String reason;

  /// The server's customer-facing explanation.
  final String message;
  final CancelledBy cancelledBy;
  final DateTime cancelledAt;
}

/// The delivery address as it was when the order was placed
/// (`OrderAddress`).
@immutable
class OrderAddressSnapshot {
  const OrderAddressSnapshot({
    required this.label,
    required this.receiverName,
    required this.receiverPhone,
    required this.text,
    this.customLabel,
  });

  final AddressLabel label;

  /// Shown instead of the label when set.
  final String? customLabel;
  final String receiverName;
  final String receiverPhone;

  /// The address as one line: house, street, landmark, area, city, PIN.
  final String text;
}

/// One row of the status history (`OrderStatusHistory`, `08 §2`).
@immutable
class OrderStatusEvent {
  const OrderStatusEvent({required this.status, required this.at});

  final OrderStatus status;
  final DateTime at;
}

/// `Refund.status`.
enum RefundStatus {
  pending('PENDING'),
  processed('PROCESSED'),
  failed('FAILED'),
  unknown(null);

  const RefundStatus(this.wireValue);

  final String? wireValue;

  static RefundStatus fromWire(String? value) => values.firstWhere(
    (status) => status.wireValue != null && status.wireValue == value,
    orElse: () => unknown,
  );
}

/// A refund on the order (`08 §4` rule 4, `§6.4`).
@immutable
class OrderRefund {
  const OrderRefund({
    required this.amount,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  final String amount;
  final RefundStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
}

/// The order-detail screen's order (`Order`, plus the Phase 4 additions:
/// timeline, refunds and invoice).
@immutable
class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.number,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.storeName,
    required this.lines,
    required this.itemCount,
    required this.bill,
    required this.createdAt,
    this.couponCode,
    this.address,
    this.placedAt,
    this.etaAt,
    this.paymentExpiresAt,
    this.canCancel = false,
    this.canRetryPayment = false,
    this.history = const [],
    this.refunds = const [],
    this.amountRefunded,
    this.invoiceAvailable = false,
    this.cancellation,
  });

  final int id;
  final String number;
  final OrderStatus status;
  final PaymentMethod? paymentMethod;
  final PaymentStatus paymentStatus;
  final String storeName;
  final List<OrderLineItem> lines;
  final int itemCount;
  final CartBill bill;
  final String? couponCode;
  final OrderAddressSnapshot? address;
  final DateTime createdAt;
  final DateTime? placedAt;
  final DateTime? etaAt;
  final DateTime? paymentExpiresAt;

  /// The server allows `POST /orders/{id}/cancel/` now (`08 §7`).
  final bool canCancel;
  final bool canRetryPayment;

  /// Status changes, oldest first.
  final List<OrderStatusEvent> history;
  final List<OrderRefund> refunds;

  /// The server's total refunded so far, or null when nothing was.
  final String? amountRefunded;

  /// The server's `can_download_invoice`: `GET /orders/{id}/invoice/` has a
  /// PDF for this order.
  final bool invoiceAvailable;

  /// Set once the order is cancelled.
  final OrderCancellationInfo? cancellation;

  bool get isActive => status.isActive;

  /// Active, but past the customer cancellation window (`08 §7`): the
  /// screen offers "Contact support" instead of Cancel.
  bool get needsSupportToCancel =>
      isActive && !canCancel && status != OrderStatus.paymentPending;

  /// The order can be ordered again: it is finished (`03 §2.10`).
  bool get canReorder => !isActive && lines.isNotEmpty;

  /// What to pay the rider at the door for a cash-on-delivery order still
  /// to be collected: the server's `bill.grand_total` exactly as sent (the
  /// bill is recomputed by the server after any change, `08 §5`). Null for
  /// an online order, once collected, or when the delivery failed (T13/T14:
  /// nothing to collect).
  String? get codAmountDue {
    if (paymentMethod != PaymentMethod.cod ||
        paymentStatus != PaymentStatus.codPending) {
      return null;
    }
    return switch (status) {
      OrderStatus.placed ||
      OrderStatus.accepted ||
      OrderStatus.packing ||
      OrderStatus.packed ||
      OrderStatus.outForDelivery => bill.grandTotal,
      _ => null,
    };
  }
}

/// The customer-facing progress steps (`03 §2.10`: Placed → Confirmed →
/// Packing → On the way → Delivered).
enum OrderStage { placed, confirmed, packing, onTheWay, delivered }

/// A stage's place in the timeline.
enum TimelineStepState { done, current, upcoming }

/// A row of the timeline: a progress stage, or the end of an order that
/// left the happy path ([ending]: cancelled, payment failed, delivery
/// unsuccessful).
@immutable
class TimelineStep {
  const TimelineStep({required this.state, this.stage, this.ending, this.at});

  final OrderStage? stage;
  final OrderStatus? ending;
  final TimelineStepState state;

  /// When the step was reached, from the status history.
  final DateTime? at;
}

/// The stage [status] puts the order in, or null (awaiting payment, or a
/// status off the happy path).
OrderStage? stageOf(OrderStatus status) => switch (status) {
  OrderStatus.placed => OrderStage.placed,
  OrderStatus.accepted => OrderStage.confirmed,
  OrderStatus.packing || OrderStatus.packed => OrderStage.packing,
  OrderStatus.outForDelivery => OrderStage.onTheWay,
  OrderStatus.delivered => OrderStage.delivered,
  _ => null,
};

/// The timeline for [order]: the server's status and history only, no
/// guessing. The happy path shows every stage (done, current, upcoming);
/// an order that ended elsewhere shows the stages it reached, then how it
/// ended. An order still awaiting payment has no steps yet.
List<TimelineStep> buildTimeline(OrderDetail order) =>
    timelineFor(order.status, history: order.history, placedAt: order.placedAt);

/// [buildTimeline] from a status and its history alone (e.g. tracking).
List<TimelineStep> timelineFor(
  OrderStatus status, {
  List<OrderStatusEvent> history = const [],
  DateTime? placedAt,
}) {
  DateTime? reachedAt(OrderStage stage) {
    DateTime? at;
    for (final event in history) {
      if (stageOf(event.status) == stage) at ??= event.at;
    }
    if (stage == OrderStage.placed) at ??= placedAt;
    return at;
  }

  if (status == OrderStatus.paymentPending) return const [];
  final current = stageOf(status);
  if (current != null) {
    return [
      for (final stage in OrderStage.values)
        TimelineStep(
          stage: stage,
          state: stage.index < current.index
              ? TimelineStepState.done
              : stage == current
              ? (stage == OrderStage.delivered
                    ? TimelineStepState.done
                    : TimelineStepState.current)
              : TimelineStepState.upcoming,
          at: stage.index <= current.index ? reachedAt(stage) : null,
        ),
    ];
  }

  // Off the happy path: the stages the history shows, then the ending.
  var furthest = -1;
  for (final event in history) {
    final stage = stageOf(event.status);
    if (stage != null && stage.index > furthest) furthest = stage.index;
  }
  if (furthest < 0 && placedAt != null) furthest = 0;
  DateTime? endedAt;
  for (final event in history) {
    if (event.status == status) endedAt = event.at;
  }
  return [
    for (final stage in OrderStage.values.take(furthest + 1))
      TimelineStep(
        stage: stage,
        state: TimelineStepState.done,
        at: reachedAt(stage),
      ),
    TimelineStep(ending: status, state: TimelineStepState.current, at: endedAt),
  ];
}

/// `POST /orders/{id}/reorder/`: what was added to the cart and what
/// wasn't.
@immutable
class ReorderResult {
  const ReorderResult({
    this.unavailable = const [],
    this.cart,
    this.addedCount,
  });

  /// Lines that couldn't be added as ordered.
  final List<ReorderSkippedItem> unavailable;

  /// The cart after the reorder, when the server returns it.
  final CartSnapshot? cart;

  /// The server's count of order lines now in the cart (`added_count`);
  /// null from a source that doesn't send it.
  final int? addedCount;

  bool get addedAll => unavailable.isEmpty;

  /// Nothing at all was added from an order of [orderLines] lines: the
  /// server's `added_count` when sent, else counted from [unavailable].
  bool addedNothing(int orderLines) {
    final added = addedCount;
    if (added != null) return added == 0;
    return unavailable.where((i) => i.addedQuantity == 0).length >= orderLines;
  }
}

/// Why a line couldn't be reordered as it was.
enum ReorderSkipReason {
  outOfStock('OUT_OF_STOCK'),
  quantityReduced('LIMITED_STOCK'),
  discontinued('NOT_AVAILABLE'),
  unknown(null);

  const ReorderSkipReason(this.wireValue);

  final String? wireValue;

  static ReorderSkipReason fromWire(String? value) => values.firstWhere(
    (reason) => reason.wireValue != null && reason.wireValue == value,
    orElse: () => unknown,
  );
}

@immutable
class ReorderSkippedItem {
  const ReorderSkippedItem({
    required this.variantId,
    required this.productName,
    required this.variantName,
    required this.reason,
    required this.requestedQuantity,
    this.addedQuantity = 0,
  });

  final int variantId;
  final String productName;
  final String variantName;
  final ReorderSkipReason reason;
  final int requestedQuantity;

  /// Units added anyway (when the quantity was reduced).
  final int addedQuantity;
}

/// `GET /orders/{id}/invoice/`: a short-lived signed link to the PDF.
@immutable
class InvoiceLink {
  const InvoiceLink({required this.url, this.expiresAt, this.number});

  final Uri url;
  final DateTime? expiresAt;

  /// The GST invoice number.
  final String? number;
}
