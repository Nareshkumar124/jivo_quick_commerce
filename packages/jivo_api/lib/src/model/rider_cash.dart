// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_cash.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderCash {
  /// Returns a new [RiderCash] instance.
  RiderCash({
    required this.cashInHand,

    required this.cashLimit,

    required this.limitReached,

    required this.depositRequired,
  });

  /// COD cash collected and not yet deposited.
  @JsonKey(name: r'cash_in_hand', required: true, includeIfNull: false)
  final String cashInHand;

  /// The rider's limit (default ₹5,000).
  @JsonKey(name: r'cash_limit', required: true, includeIfNull: false)
  final String cashLimit;

  /// True at or above the limit: only prepaid offers are sent (08 §5).
  @JsonKey(name: r'limit_reached', required: true, includeIfNull: false)
  final bool limitReached;

  /// Show the \"Deposit cash\" banner (DL-61): at the limit, or a COD order was not offered to you because cash in hand + its amount was over the limit. Cleared by a deposit at the store. Ops cannot override the limit.
  @JsonKey(name: r'deposit_required', required: true, includeIfNull: false)
  final bool depositRequired;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderCash &&
          other.cashInHand == cashInHand &&
          other.cashLimit == cashLimit &&
          other.limitReached == limitReached &&
          other.depositRequired == depositRequired;

  @override
  int get hashCode =>
      cashInHand.hashCode +
      cashLimit.hashCode +
      limitReached.hashCode +
      depositRequired.hashCode;

  factory RiderCash.fromJson(Map<String, dynamic> json) =>
      _$RiderCashFromJson(json);

  Map<String, dynamic> toJson() => _$RiderCashToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
