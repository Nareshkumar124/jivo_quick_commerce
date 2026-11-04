// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/payment_method_enum.dart';
import 'package:jivo_api/src/model/payment_status_enum.dart';
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:jivo_api/src/model/order_store.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderSummary {
  /// Returns a new [OrderSummary] instance.
  OrderSummary({
    required this.id,

    required this.orderNumber,

    required this.status,

    required this.paymentMethod,

    required this.paymentStatus,

    required this.store,

    required this.itemCount,

    required this.images,

    required this.grandTotal,

    required this.createdAt,

    required this.placedAt,

    required this.paymentExpiresAt,

    required this.etaAt,

    required this.canRetryPayment,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

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

  // minimum: 1
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  /// Pictures of up to the first 4 lines, for the row thumbnails.
  @JsonKey(name: r'images', required: true, includeIfNull: false)
  final List<ImageSet> images;

  /// The order's `bill.grand_total`.
  @JsonKey(name: r'grand_total', required: true, includeIfNull: false)
  final String grandTotal;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'placed_at', required: true, includeIfNull: true)
  final DateTime? placedAt;

  /// As on `Order`: set only while PAYMENT_PENDING.
  @JsonKey(name: r'payment_expires_at', required: true, includeIfNull: true)
  final DateTime? paymentExpiresAt;

  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  @JsonKey(name: r'can_retry_payment', required: true, includeIfNull: false)
  final bool canRetryPayment;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderSummary &&
          other.id == id &&
          other.orderNumber == orderNumber &&
          other.status == status &&
          other.paymentMethod == paymentMethod &&
          other.paymentStatus == paymentStatus &&
          other.store == store &&
          other.itemCount == itemCount &&
          other.images == images &&
          other.grandTotal == grandTotal &&
          other.createdAt == createdAt &&
          other.placedAt == placedAt &&
          other.paymentExpiresAt == paymentExpiresAt &&
          other.etaAt == etaAt &&
          other.canRetryPayment == canRetryPayment;

  @override
  int get hashCode =>
      id.hashCode +
      orderNumber.hashCode +
      status.hashCode +
      paymentMethod.hashCode +
      paymentStatus.hashCode +
      store.hashCode +
      itemCount.hashCode +
      images.hashCode +
      grandTotal.hashCode +
      createdAt.hashCode +
      (placedAt == null ? 0 : placedAt.hashCode) +
      (paymentExpiresAt == null ? 0 : paymentExpiresAt.hashCode) +
      (etaAt == null ? 0 : etaAt.hashCode) +
      canRetryPayment.hashCode;

  factory OrderSummary.fromJson(Map<String, dynamic> json) =>
      _$OrderSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$OrderSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
