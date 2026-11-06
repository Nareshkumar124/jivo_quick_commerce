// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/payment_status_enum.dart';
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_status_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderStatusData {
  /// Returns a new [WsOrderStatusData] instance.
  WsOrderStatusData({
    required this.orderId,

    required this.orderNumber,

    required this.storeId,

    required this.status,

    required this.paymentStatus,

    required this.etaAt,

    required this.updatedAt,
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
    name: r'payment_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: PaymentStatusEnum.unknownDefaultOpenApi,
  )
  final PaymentStatusEnum paymentStatus;

  /// Promised delivery time (08 §8), UTC.
  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  /// When the order last changed.
  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderStatusData &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.storeId == storeId &&
          other.status == status &&
          other.paymentStatus == paymentStatus &&
          other.etaAt == etaAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      orderId.hashCode +
      orderNumber.hashCode +
      storeId.hashCode +
      status.hashCode +
      paymentStatus.hashCode +
      (etaAt == null ? 0 : etaAt.hashCode) +
      updatedAt.hashCode;

  factory WsOrderStatusData.fromJson(Map<String, dynamic> json) =>
      _$WsOrderStatusDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderStatusDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
