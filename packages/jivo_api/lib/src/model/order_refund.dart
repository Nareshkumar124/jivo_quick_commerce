// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_refund_status_enum.dart';
import 'package:jivo_api/src/model/order_refund_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_refund.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderRefund {
  /// Returns a new [OrderRefund] instance.
  OrderRefund({
    required this.id,

    required this.amount,

    required this.status,

    required this.reason,

    required this.createdAt,

    required this.processedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Amount refunded.
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  /// PENDING: started; banks usually take 5-7 working days. PROCESSED: the gateway has sent it.  * `PENDING` - Refund in progress * `PROCESSED` - Refunded
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderRefundStatusEnum.unknownDefaultOpenApi,
  )
  final OrderRefundStatusEnum status;

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderRefundReasonEnum.unknownDefaultOpenApi,
  )
  final OrderRefundReasonEnum reason;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'processed_at', required: true, includeIfNull: true)
  final DateTime? processedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderRefund &&
          other.id == id &&
          other.amount == amount &&
          other.status == status &&
          other.reason == reason &&
          other.createdAt == createdAt &&
          other.processedAt == processedAt;

  @override
  int get hashCode =>
      id.hashCode +
      amount.hashCode +
      status.hashCode +
      reason.hashCode +
      createdAt.hashCode +
      (processedAt == null ? 0 : processedAt.hashCode);

  factory OrderRefund.fromJson(Map<String, dynamic> json) =>
      _$OrderRefundFromJson(json);

  Map<String, dynamic> toJson() => _$OrderRefundToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
