// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_address.dart';
import 'package:jivo_api/src/model/payment_method_enum.dart';
import 'package:jivo_api/src/model/order_cancellation.dart';
import 'package:jivo_api/src/model/order_line.dart';
import 'package:jivo_api/src/model/payment_status_enum.dart';
import 'package:jivo_api/src/model/delivery_instructions.dart';
import 'package:jivo_api/src/model/order_refund.dart';
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:jivo_api/src/model/order_timeline_entry.dart';
import 'package:jivo_api/src/model/bill.dart';
import 'package:jivo_api/src/model/order_store.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Order {
  /// Returns a new [Order] instance.
  Order({
    required this.id,

    required this.orderNumber,

    required this.status,

    required this.paymentMethod,

    required this.paymentStatus,

    required this.store,

    required this.items,

    required this.itemCount,

    required this.bill,

    required this.couponCode,

    required this.address,

    required this.instructions,

    required this.createdAt,

    required this.placedAt,

    required this.paymentExpiresAt,

    required this.etaAt,

    required this.canCancel,

    required this.canRetryPayment,

    required this.timeline,

    required this.cancellation,

    required this.amountRefunded,

    required this.refunds,

    required this.canDownloadInvoice,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Shown to the customer, e.g. \"JV-261103-000123\".
  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  /// 08 §1.  * `PAYMENT_PENDING` - Completing payment… * `PLACED` - Order placed * `ACCEPTED` - Order confirmed * `PACKING` - Packing your order * `PACKED` - Packed, rider on the way to store * `OUT_FOR_DELIVERY` - On the way * `DELIVERED` - Delivered * `CANCELLED` - Cancelled * `PAYMENT_FAILED` - Payment failed * `DELIVERY_FAILED` - Delivery unsuccessful * `RETURNED` - Delivery unsuccessful
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum status;

  @JsonKey(
    name: r'payment_method',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PaymentMethodEnum.unknownDefaultOpenApi,
  )
  final PaymentMethodEnum paymentMethod;

  @JsonKey(
    name: r'payment_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PaymentStatusEnum.unknownDefaultOpenApi,
  )
  final PaymentStatusEnum paymentStatus;

  @JsonKey(name: r'store', required: true, includeIfNull: false)
  final OrderStore store;

  @JsonKey(name: r'items', required: true, includeIfNull: false)
  final List<OrderLine> items;

  /// Units (sum of quantities).
  // minimum: 1
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  @JsonKey(name: r'bill', required: true, includeIfNull: false)
  final Bill bill;

  /// Null when none was used.
  @JsonKey(name: r'coupon_code', required: true, includeIfNull: true)
  final String? couponCode;

  @JsonKey(name: r'address', required: true, includeIfNull: false)
  final OrderAddress address;

  @JsonKey(name: r'instructions', required: true, includeIfNull: false)
  final DeliveryInstructions instructions;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// When it reached PLACED (paid online, or confirmed COD); null before.
  @JsonKey(name: r'placed_at', required: true, includeIfNull: true)
  final DateTime? placedAt;

  /// PAYMENT_PENDING only: the end of the online payment window (15 minutes from placement, a server setting). Retrying the payment does not extend it. After it the order fails and the stock is released. Null in every other state.
  @JsonKey(name: r'payment_expires_at', required: true, includeIfNull: true)
  final DateTime? paymentExpiresAt;

  /// Promised delivery time (UTC; show it in IST). Null until PLACED.
  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  /// True when `POST /orders/{id}/cancel/` is allowed now (08 §7): PAYMENT_PENDING, PLACED or ACCEPTED (from PACKING on, show 'Contact support').
  @JsonKey(name: r'can_cancel', required: true, includeIfNull: false)
  final bool canCancel;

  /// True when `POST /orders/{id}/retry-payment/` is allowed now: an ONLINE order in PAYMENT_PENDING before `payment_expires_at`.
  @JsonKey(name: r'can_retry_payment', required: true, includeIfNull: false)
  final bool canRetryPayment;

  /// Every state reached, oldest first (Phase 4).
  @JsonKey(name: r'timeline', required: true, includeIfNull: false)
  final List<OrderTimelineEntry> timeline;

  /// Set when the order is CANCELLED; null otherwise (Phase 4).
  @JsonKey(name: r'cancellation', required: true, includeIfNull: true)
  final OrderCancellation? cancellation;

  /// Refunded so far (processed refunds), Phase 4. `bill` is always the current bill: after items were found unavailable it is the reduced one.
  @JsonKey(name: r'amount_refunded', required: true, includeIfNull: false)
  final String amountRefunded;

  /// Refunds of this order, oldest first; [] when none (Phase 4).
  @JsonKey(name: r'refunds', required: true, includeIfNull: false)
  final List<OrderRefund> refunds;

  /// True when `GET /orders/{id}/invoice/` has an invoice: DELIVERED orders (Phase 4).
  @JsonKey(name: r'can_download_invoice', required: true, includeIfNull: false)
  final bool canDownloadInvoice;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Order &&
          other.id == id &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.paymentMethod == paymentMethod &&
          other.paymentStatus == paymentStatus &&
          other.store == store &&
          other.items == items &&
          other.itemCount == itemCount &&
          other.bill == bill &&
          other.couponCode == couponCode &&
          other.address == address &&
          other.instructions == instructions &&
          other.createdAt == createdAt &&
          other.placedAt == placedAt &&
          other.paymentExpiresAt == paymentExpiresAt &&
          other.etaAt == etaAt &&
          other.canCancel == canCancel &&
          other.canRetryPayment == canRetryPayment &&
          other.timeline == timeline &&
          other.cancellation == cancellation &&
          other.amountRefunded == amountRefunded &&
          other.refunds == refunds &&
          other.canDownloadInvoice == canDownloadInvoice;

  @override
  int get hashCode =>
      id.hashCode +
      orderNumber.hashCode +
      status.hashCode +
      paymentMethod.hashCode +
      paymentStatus.hashCode +
      store.hashCode +
      items.hashCode +
      itemCount.hashCode +
      bill.hashCode +
      (couponCode == null ? 0 : couponCode.hashCode) +
      address.hashCode +
      instructions.hashCode +
      createdAt.hashCode +
      (placedAt == null ? 0 : placedAt.hashCode) +
      (paymentExpiresAt == null ? 0 : paymentExpiresAt.hashCode) +
      (etaAt == null ? 0 : etaAt.hashCode) +
      canCancel.hashCode +
      canRetryPayment.hashCode +
      timeline.hashCode +
      (cancellation == null ? 0 : cancellation.hashCode) +
      amountRefunded.hashCode +
      refunds.hashCode +
      canDownloadInvoice.hashCode;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
