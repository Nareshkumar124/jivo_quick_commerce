// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ticket_status_enum.dart';
import 'package:jivo_api/src/model/ticket_category_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ticket_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TicketSummary {
  /// Returns a new [TicketSummary] instance.
  TicketSummary({
    required this.id,

    required this.number,

    required this.category,

    required this.status,

    required this.orderId,

    required this.orderNumber,

    required this.lastMessage,

    required this.createdAt,

    required this.updatedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Shown to the customer and support, e.g. \"TK-000123\".
  @JsonKey(name: r'number', required: true, includeIfNull: false)
  final String number;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TicketCategoryEnum.unknownDefaultOpenApi,
  )
  final TicketCategoryEnum category;

  /// The customer can reply unless CLOSED; a reply to RESOLVED reopens it (OPEN).  * `OPEN` - Open * `IN_PROGRESS` - In progress * `RESOLVED` - Resolved * `CLOSED` - Closed
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TicketStatusEnum.unknownDefaultOpenApi,
  )
  final TicketStatusEnum status;

  @JsonKey(name: r'order_id', required: true, includeIfNull: true)
  final int? orderId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: true)
  final String? orderNumber;

  /// The newest message, cut to 140 characters (plain text).
  @JsonKey(name: r'last_message', required: true, includeIfNull: true)
  final String? lastMessage;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// Last message or status change; the list is sorted by it, newest first.
  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TicketSummary &&
          other.id == id &&
          other.number == number &&
          other.category == category &&
          other.status == status &&
          other.orderId == orderId &&
          other.orderNumber == orderNumber &&
          other.lastMessage == lastMessage &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
      number.hashCode +
      category.hashCode +
      status.hashCode +
      (orderId == null ? 0 : orderId.hashCode) +
      (orderNumber == null ? 0 : orderNumber.hashCode) +
      (lastMessage == null ? 0 : lastMessage.hashCode) +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory TicketSummary.fromJson(Map<String, dynamic> json) =>
      _$TicketSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$TicketSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
