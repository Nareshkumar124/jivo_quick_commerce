// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartThresholds &&
          other.minOrderValue == minOrderValue &&
          other.amountToMinOrder == amountToMinOrder &&
          other.freeDeliveryThreshold == freeDeliveryThreshold &&
          other.amountToFreeDelivery == amountToFreeDelivery;

  @override
  int get hashCode =>
      minOrderValue.hashCode +
      (amountToMinOrder == null ? 0 : amountToMinOrder.hashCode) +
      (freeDeliveryThreshold == null ? 0 : freeDeliveryThreshold.hashCode) +
      (amountToFreeDelivery == null ? 0 : amountToFreeDelivery.hashCode);

  factory CartThresholds.fromJson(Map<String, dynamic> json) =>
      _$CartThresholdsFromJson(json);

  Map<String, dynamic> toJson() => _$CartThresholdsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
