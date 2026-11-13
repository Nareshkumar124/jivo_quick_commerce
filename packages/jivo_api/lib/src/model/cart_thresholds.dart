// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/next_price_tier.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_thresholds.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartThresholds {
  /// Returns a new [CartThresholds] instance.
  CartThresholds({
    required this.minOrderValue,

    required this.amountToMinOrder,

    required this.freeDeliveryThreshold,

    required this.amountToFreeDelivery,

    required this.minOrderUnits,

    required this.unitsToMinOrder,

    required this.tierUnits,

    required this.nextPriceTier,

    required this.orderUnitLabel,
  });

  /// Minimum item total to place an order.
  @JsonKey(name: r'min_order_value', required: true, includeIfNull: false)
  final String minOrderValue;

  /// Item value still needed to reach the minimum; null when it is reached.
  @JsonKey(name: r'amount_to_min_order', required: true, includeIfNull: true)
  final String? amountToMinOrder;

  /// Item total from which delivery is free; null when the store charges no delivery fee.
  @JsonKey(
    name: r'free_delivery_threshold',
    required: true,
    includeIfNull: true,
  )
  final String? freeDeliveryThreshold;

  /// For the nudge 'Add ₹X more for free delivery'; null when delivery is already free.
  @JsonKey(
    name: r'amount_to_free_delivery',
    required: true,
    includeIfNull: true,
  )
  final String? amountToFreeDelivery;

  /// Fewest units one order must have, any mix of items (e.g. 5 cartons); 0 = no minimum. Not compared with `bill.item_total`: units are counted per line as min(`quantity`, `variant.orderable_quantity`), so an out-of-stock line counts 0.
  // minimum: 0
  @JsonKey(name: r'min_order_units', required: true, includeIfNull: false)
  final int minOrderUnits;

  /// Units still needed ('Add 2 more cartons'); null when the minimum is met or there is none. While set, checkout is blocked with `MIN_UNITS_NOT_MET`.
  // minimum: 1
  @JsonKey(name: r'units_to_min_order', required: true, includeIfNull: true)
  final int? unitsToMinOrder;

  /// Units that choose the volume price tier (ADR 0001): every line whose variant has `price_tiers`, any mix, each counting min(`quantity`, `orderable_quantity`). 0 when no line has tiers.
  // minimum: 0
  @JsonKey(name: r'tier_units', required: true, includeIfNull: false)
  final int tierUnits;

  /// The nudge 'Add 3 more boxes to get ₹87/box': the next tier at which a line's price drops (each line's new price is its `next_tier_price`). Null at the top tier or when no line has tiers.
  @JsonKey(name: r'next_price_tier', required: true, includeIfNull: true)
  final NextPriceTier? nextPriceTier;

  /// What a unit is called, in the plural, e.g. \"cartons\" (\"items\" by default).
  @JsonKey(name: r'order_unit_label', required: true, includeIfNull: false)
  final String orderUnitLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartThresholds &&
          other.minOrderValue == minOrderValue &&
          other.amountToMinOrder == amountToMinOrder &&
          other.freeDeliveryThreshold == freeDeliveryThreshold &&
          other.amountToFreeDelivery == amountToFreeDelivery &&
          other.minOrderUnits == minOrderUnits &&
          other.unitsToMinOrder == unitsToMinOrder &&
          other.tierUnits == tierUnits &&
          other.nextPriceTier == nextPriceTier &&
          other.orderUnitLabel == orderUnitLabel;

  @override
  int get hashCode =>
      minOrderValue.hashCode +
      (amountToMinOrder == null ? 0 : amountToMinOrder.hashCode) +
      (freeDeliveryThreshold == null ? 0 : freeDeliveryThreshold.hashCode) +
      (amountToFreeDelivery == null ? 0 : amountToFreeDelivery.hashCode) +
      minOrderUnits.hashCode +
      (unitsToMinOrder == null ? 0 : unitsToMinOrder.hashCode) +
      tierUnits.hashCode +
      (nextPriceTier == null ? 0 : nextPriceTier.hashCode) +
      orderUnitLabel.hashCode;

  factory CartThresholds.fromJson(Map<String, dynamic> json) =>
      _$CartThresholdsFromJson(json);

  Map<String, dynamic> toJson() => _$CartThresholdsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
