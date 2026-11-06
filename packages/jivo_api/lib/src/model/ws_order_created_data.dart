// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/payment_method_enum.dart';
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_created_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderCreatedData {
  /// Returns a new [WsOrderCreatedData] instance.
  WsOrderCreatedData({
    required this.orderId,

    required this.orderNumber,

    required this.storeId,

    required this.status,

    required this.paymentMethod,

    required this.itemCount,

    required this.grandTotal,

    required this.placedAt,

    required this.etaAt,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @JsonKey(name: r'store_id', required: true, includeIfNull: false)
  final int storeId;

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

  /// Units in the order.
  @JsonKey(name: r'item_count', required: true, includeIfNull: false)
  final int itemCount;

  @JsonKey(name: r'grand_total', required: true, includeIfNull: false)
  final String grandTotal;

  @JsonKey(name: r'placed_at', required: true, includeIfNull: true)
  final DateTime? placedAt;

  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderCreatedData &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.storeId == storeId &&
          other.status == status &&
          other.paymentMethod == paymentMethod &&
          other.itemCount == itemCount &&
          other.grandTotal == grandTotal &&
          other.placedAt == placedAt &&
          other.etaAt == etaAt;

  @override
  int get hashCode =>
      orderId.hashCode +
      orderNumber.hashCode +
      storeId.hashCode +
      status.hashCode +
      paymentMethod.hashCode +
      itemCount.hashCode +
      grandTotal.hashCode +
      (placedAt == null ? 0 : placedAt.hashCode) +
      (etaAt == null ? 0 : etaAt.hashCode);

  factory WsOrderCreatedData.fromJson(Map<String, dynamic> json) =>
      _$WsOrderCreatedDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderCreatedDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
