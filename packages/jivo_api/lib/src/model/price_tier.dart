// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'price_tier.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PriceTier {
  /// Returns a new [PriceTier] instance.
  PriceTier({required this.minOrderUnits, required this.price});

  /// From this many units in the order, counting every item that has price tiers together (any mix).
  // minimum: 1
  @JsonKey(name: r'min_order_units', required: true, includeIfNull: false)
  final int minOrderUnits;

  /// Price per unit at this tier (inclusive of all taxes).
  @JsonKey(name: r'price', required: true, includeIfNull: false)
  final String price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceTier &&
          other.minOrderUnits == minOrderUnits &&
          other.price == price;

  @override
  int get hashCode => minOrderUnits.hashCode + price.hashCode;

  factory PriceTier.fromJson(Map<String, dynamic> json) =>
      _$PriceTierFromJson(json);

  Map<String, dynamic> toJson() => _$PriceTierToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
