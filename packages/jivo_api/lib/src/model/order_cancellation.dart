// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_cancel_reason_enum.dart';
import 'package:jivo_api/src/model/cancelled_by_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_cancellation.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderCancellation {
  /// Returns a new [OrderCancellation] instance.
  OrderCancellation({
    required this.reason,

    required this.message,

    required this.cancelledBy,

    required this.cancelledAt,
  });

  @JsonKey(
    name: r'reason',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderCancelReasonEnum.unknownDefaultOpenApi,
  )
  final OrderCancelReasonEnum reason;

  /// The reason as text to show.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// `customer`, `store`, `ops` (Jivo support) or `system` (payment window).  * `customer` - Customer * `store` - Store staff * `rider` - Rider * `ops` - Ops / support * `system` - System
  @JsonKey(
    name: r'cancelled_by',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CancelledByEnum.unknownDefaultOpenApi,
  )
  final CancelledByEnum cancelledBy;

  @JsonKey(name: r'cancelled_at', required: true, includeIfNull: false)
  final DateTime cancelledAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderCancellation &&
          other.reason == reason &&
          other.message == message &&
          other.cancelledBy == cancelledBy &&
          other.cancelledAt == cancelledAt;

  @override
  int get hashCode =>
      reason.hashCode +
      message.hashCode +
      cancelledBy.hashCode +
      cancelledAt.hashCode;

  factory OrderCancellation.fromJson(Map<String, dynamic> json) =>
      _$OrderCancellationFromJson(json);

  Map<String, dynamic> toJson() => _$OrderCancellationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
