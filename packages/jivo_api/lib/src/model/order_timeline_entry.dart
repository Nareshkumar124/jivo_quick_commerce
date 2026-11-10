// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/order_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_timeline_entry.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderTimelineEntry {
  /// Returns a new [OrderTimelineEntry] instance.
  OrderTimelineEntry({
    required this.status,

    required this.title,

    required this.at,
  });

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: OrderStatusEnum.unknownDefaultOpenApi,
  )
  final OrderStatusEnum status;

  /// The customer label of the state, e.g. \"Order confirmed\".
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'at', required: true, includeIfNull: false)
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderTimelineEntry &&
          other.status == status &&
          other.title == title &&
          other.at == at;

  @override
  int get hashCode => status.hashCode + title.hashCode + at.hashCode;

  factory OrderTimelineEntry.fromJson(Map<String, dynamic> json) =>
      _$OrderTimelineEntryFromJson(json);

  Map<String, dynamic> toJson() => _$OrderTimelineEntryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
