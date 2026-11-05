// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/earning_line.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'earnings_order.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EarningsOrder {
  /// Returns a new [EarningsOrder] instance.
  EarningsOrder({
    required this.taskId,

    required this.orderNumber,

    required this.completedAt,

    required this.total,

    required this.lines,
  });

  @JsonKey(name: r'task_id', required: true, includeIfNull: false)
  final int taskId;

  @JsonKey(name: r'order_number', required: true, includeIfNull: false)
  final String orderNumber;

  @JsonKey(name: r'completed_at', required: true, includeIfNull: false)
  final DateTime completedAt;

  /// Sum of `lines`.
  @JsonKey(name: r'total', required: true, includeIfNull: false)
  final String total;

  @JsonKey(name: r'lines', required: true, includeIfNull: false)
  final List<EarningLine> lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarningsOrder &&
          other.taskId == taskId &&
          other.orderNumber == orderNumber &&
          other.completedAt == completedAt &&
          other.total == total &&
          other.lines == lines;

  @override
  int get hashCode =>
      taskId.hashCode +
      orderNumber.hashCode +
      completedAt.hashCode +
      total.hashCode +
      lines.hashCode;

  factory EarningsOrder.fromJson(Map<String, dynamic> json) =>
      _$EarningsOrderFromJson(json);

  Map<String, dynamic> toJson() => _$EarningsOrderToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
