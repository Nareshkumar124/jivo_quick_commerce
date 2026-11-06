// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ticket_category_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket_create_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TicketCreateRequest {
  /// Returns a new [TicketCreateRequest] instance.
  TicketCreateRequest({
    required this.category,

    required this.message,

    this.orderId,
  });

  /// MISSING_ITEMS, DAMAGED_ITEMS, WRONG_ITEMS and LATE_DELIVERY need `order_id`.  * `MISSING_ITEMS` - Missing items * `DAMAGED_ITEMS` - Damaged items * `WRONG_ITEMS` - Wrong items * `LATE_DELIVERY` - Late delivery * `PAYMENT_REFUND` - Payment or refund * `ACCOUNT` - Account * `OTHER` - Other
  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TicketCategoryEnum.unknownDefaultOpenApi,
  )
  final TicketCategoryEnum category;

  /// Plain text, 10 to 1000 characters after trimming.
  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  /// One of the caller's orders (another user's order is refused as not found).
  // minimum: 1
  @JsonKey(name: r'order_id', required: false, includeIfNull: false)
  final int? orderId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketCreateRequest &&
          other.category == category &&
          other.message == message &&
          other.orderId == orderId;

  @override
  int get hashCode =>
      category.hashCode +
      message.hashCode +
      (orderId == null ? 0 : orderId.hashCode);

  factory TicketCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$TicketCreateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TicketCreateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
