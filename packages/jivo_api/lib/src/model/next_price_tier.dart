// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'next_price_tier.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NextPriceTier {
  /// Returns a new [NextPriceTier] instance.
  NextPriceTier({required this.minOrderUnits, required this.unitsToNextTier});

  /// The tier units the next lower prices start at.
  // minimum: 1
  @JsonKey(name: r'min_order_units', required: true, includeIfNull: false)
  final int minOrderUnits;

  /// Units still to add (any tiered item) to reach it.
  // minimum: 1
  @JsonKey(name: r'units_to_next_tier', required: true, includeIfNull: false)
  final int unitsToNextTier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NextPriceTier &&
          other.minOrderUnits == minOrderUnits &&
          other.unitsToNextTier == unitsToNextTier;

  @override
  int get hashCode => minOrderUnits.hashCode + unitsToNextTier.hashCode;

  factory NextPriceTier.fromJson(Map<String, dynamic> json) =>
      _$NextPriceTierFromJson(json);

  Map<String, dynamic> toJson() => _$NextPriceTierToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
