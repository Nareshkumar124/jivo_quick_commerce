// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cart_product.dart';
import 'package:jivo_api/src/model/free_source_enum.dart';
import 'package:jivo_api/src/model/variant_summary.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'free_line.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FreeLine {
  /// Returns a new [FreeLine] instance.
  FreeLine({
    required this.product,

    required this.variant,

    required this.quantity,

    required this.mrp,

    required this.value,

    required this.source_,
  });

  @JsonKey(name: r'product', required: true, includeIfNull: false)
  final CartProduct product;

  /// The free carton's size (same shape as the catalog).
  @JsonKey(name: r'variant', required: true, includeIfNull: false)
  final VariantSummary variant;

  /// Free cartons of this size.
  // minimum: 1
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  /// Unit MRP of the free carton.
  @JsonKey(name: r'mrp', required: true, includeIfNull: false)
  final String mrp;

  /// `mrp` x `quantity`: what the customer saves (part of `bill.free_items_value`).
  @JsonKey(name: r'value', required: true, includeIfNull: false)
  final String value;

  /// VOLUME_OFFER: 1 free for every `free_offer.every` paid cartons (the cheapest size in the cart). REWARD: the free-carton reward applied as the cart's coupon.  * `VOLUME_OFFER` - Volume offer * `REWARD` - Reward
  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue: FreeSourceEnum.unknownDefaultOpenApi,
  )
  final FreeSourceEnum source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreeLine &&
          other.product == product &&
          other.variant == variant &&
          other.quantity == quantity &&
          other.mrp == mrp &&
          other.value == value &&
          other.source_ == source_;

  @override
  int get hashCode =>
      product.hashCode +
      variant.hashCode +
      quantity.hashCode +
      mrp.hashCode +
      value.hashCode +
      source_.hashCode;

  factory FreeLine.fromJson(Map<String, dynamic> json) =>
      _$FreeLineFromJson(json);

  Map<String, dynamic> toJson() => _$FreeLineToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
