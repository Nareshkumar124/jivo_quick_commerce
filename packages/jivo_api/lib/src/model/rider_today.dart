// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/date_only.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_today.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderToday {
  /// Returns a new [RiderToday] instance.
  RiderToday({
    required this.date,

    required this.ordersDelivered,

    required this.earnings,

    required this.cashInHand,

    required this.onlineSeconds,
  });

  /// IST calendar date, YYYY-MM-DD.
  @JsonKey(
    name: r'date',
    toJson: jivoDateToJson,
    required: true,
    includeIfNull: false,
  )
  final DateTime date;

  @JsonKey(name: r'orders_delivered', required: true, includeIfNull: false)
  final int ordersDelivered;

  /// Everything earned today (orders, tips, adjustments).
  @JsonKey(name: r'earnings', required: true, includeIfNull: false)
  final String earnings;

  /// Same as `cash.cash_in_hand`.
  @JsonKey(name: r'cash_in_hand', required: true, includeIfNull: false)
  final String cashInHand;

  /// Time online today, the current shift included up to now.
  @JsonKey(name: r'online_seconds', required: true, includeIfNull: false)
  final int onlineSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderToday &&
          other.date == date &&
          other.ordersDelivered == ordersDelivered &&
          other.earnings == earnings &&
          other.cashInHand == cashInHand &&
          other.onlineSeconds == onlineSeconds;

  @override
  int get hashCode =>
      date.hashCode +
      ordersDelivered.hashCode +
      earnings.hashCode +
      cashInHand.hashCode +
      onlineSeconds.hashCode;

  factory RiderToday.fromJson(Map<String, dynamic> json) =>
      _$RiderTodayFromJson(json);

  Map<String, dynamic> toJson() => _$RiderTodayToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
