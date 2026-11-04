// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/earnings_order.dart';
import 'package:jivo_api/src/model/earning_totals.dart';
import 'package:jivo_api/src/model/earnings_adjustment.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'earnings.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Earnings {
  /// Returns a new [Earnings] instance.
  Earnings({
    required this.from,

    required this.to,

    required this.total,

    required this.ordersCount,

    required this.totalsByType,

    required this.orders,

    required this.ordersTruncated,

    required this.adjustments,
  });

  /// IST calendar date, YYYY-MM-DD.
  @JsonKey(name: r'from', required: true, includeIfNull: false)
  final DateTime from;

  /// IST calendar date, YYYY-MM-DD. Inclusive.
  @JsonKey(name: r'to', required: true, includeIfNull: false)
  final DateTime to;

  /// All earnings in the range.
  @JsonKey(name: r'total', required: true, includeIfNull: false)
  final String total;

  /// Delivered orders in the range.
  @JsonKey(name: r'orders_count', required: true, includeIfNull: false)
  final int ordersCount;

  @JsonKey(name: r'totals_by_type', required: true, includeIfNull: false)
  final EarningTotals totalsByType;

  /// Newest first, at most 200 (see `orders_truncated`).
  @JsonKey(name: r'orders', required: true, includeIfNull: false)
  final List<EarningsOrder> orders;

  /// True when the range has more than 200 orders: the totals still cover all.
  @JsonKey(name: r'orders_truncated', required: true, includeIfNull: false)
  final bool ordersTruncated;

  @JsonKey(name: r'adjustments', required: true, includeIfNull: false)
  final List<EarningsAdjustment> adjustments;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Earnings &&
          other.from == from &&
          other.to == to &&
          other.total == total &&
          other.ordersCount == ordersCount &&
          other.totalsByType == totalsByType &&
          other.orders == orders &&
          other.ordersTruncated == ordersTruncated &&
          other.adjustments == adjustments;

  @override
  int get hashCode =>
      from.hashCode +
      to.hashCode +
      total.hashCode +
      ordersCount.hashCode +
      totalsByType.hashCode +
      orders.hashCode +
      ordersTruncated.hashCode +
      adjustments.hashCode;

  factory Earnings.fromJson(Map<String, dynamic> json) =>
      _$EarningsFromJson(json);

  Map<String, dynamic> toJson() => _$EarningsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
