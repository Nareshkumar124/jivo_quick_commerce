// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'earning_totals.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EarningTotals {
  /// Returns a new [EarningTotals] instance.
  EarningTotals({
    required this.BASE,

    required this.DISTANCE,

    required this.TIP,

    required this.INCENTIVE,

    required this.PENALTY,
  });

  /// Base pay.
  @JsonKey(name: r'BASE', required: true, includeIfNull: false)
  final String BASE;

  /// Distance pay.
  @JsonKey(name: r'DISTANCE', required: true, includeIfNull: false)
  final String DISTANCE;

  /// Tips.
  @JsonKey(name: r'TIP', required: true, includeIfNull: false)
  final String TIP;

  /// Incentives.
  @JsonKey(name: r'INCENTIVE', required: true, includeIfNull: false)
  final String INCENTIVE;

  /// Penalties (zero or negative).
  @JsonKey(name: r'PENALTY', required: true, includeIfNull: false)
  final String PENALTY;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarningTotals &&
          other.BASE == BASE &&
          other.DISTANCE == DISTANCE &&
          other.TIP == TIP &&
          other.INCENTIVE == INCENTIVE &&
          other.PENALTY == PENALTY;

  @override
  int get hashCode =>
      BASE.hashCode +
      DISTANCE.hashCode +
      TIP.hashCode +
      INCENTIVE.hashCode +
      PENALTY.hashCode;

  factory EarningTotals.fromJson(Map<String, dynamic> json) =>
      _$EarningTotalsFromJson(json);

  Map<String, dynamic> toJson() => _$EarningTotalsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
