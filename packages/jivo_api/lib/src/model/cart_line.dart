// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cart_product.dart';
import 'package:jivo_api/src/model/variant_summary.dart';
import 'package:jivo_api/src/model/cart_line_issue.dart';
import 'package:jivo_api/src/model/price_tier.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_line.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartLine {
  /// Returns a new [CartLine] instance.
  CartLine({
    required this.id,

    required this.product,

    required this.variant,

    required this.quantity,

    required this.pricePerUnit,

    required this.priceTier,

    required this.nextTierPrice,

    required this.lineMrpTotal,

    required this.lineTotal,

    required this.issue,
  });

  /// Line id for `PATCH`/`DELETE /cart/items/{id}/`.
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'product', required: true, includeIfNull: false)
  final CartProduct product;

  /// The variant with its current price and stock at this store (same shape as the catalog). Cap the stepper at `orderable_quantity`.
  @JsonKey(name: r'variant', required: true, includeIfNull: false)
  final VariantSummary variant;

  // minimum: 1
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  /// The price each unit of this line is billed at (show it, e.g. '₹85/box'): the volume tier's price when `price_tier` is set, else `variant.selling_price`.
  @JsonKey(name: r'price_per_unit', required: true, includeIfNull: false)
  final String pricePerUnit;

  /// The volume tier applied to this line (ADR 0001): reached by the units of all tiered items in the cart together. Null when the normal price applies.
  @JsonKey(name: r'price_tier', required: true, includeIfNull: true)
  final PriceTier? priceTier;

  /// This line's lower unit price once the cart reaches `thresholds.next_price_tier`; null when that tier does not lower this line's price (or there is no next tier).
  @JsonKey(name: r'next_tier_price', required: true, includeIfNull: true)
  final String? nextTierPrice;

  /// `variant.mrp` x `quantity`.
  @JsonKey(name: r'line_mrp_total', required: true, includeIfNull: false)
  final String lineMrpTotal;

  /// `price_per_unit` x `quantity`.
  @JsonKey(name: r'line_total', required: true, includeIfNull: false)
  final String lineTotal;

  /// Set when the line cannot be ordered as it is: quantity above `variant.orderable_quantity` (which is 0 when out of stock or no longer sold), or below `variant.min_qty_per_order` (`MIN_QTY_REQUIRED`, e.g. the minimum was raised after the line was added). Fix: set the quantity to `variant.orderable_quantity` (for `MIN_QTY_REQUIRED`, to `variant.min_qty_per_order`), or remove the line when `orderable_quantity` is 0. Null when the line is fine.
  @JsonKey(name: r'issue', required: true, includeIfNull: true)
  final CartLineIssue? issue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartLine &&
          other.id == id &&
          other.product == product &&
          other.variant == variant &&
          other.quantity == quantity &&
          other.pricePerUnit == pricePerUnit &&
          other.priceTier == priceTier &&
          other.nextTierPrice == nextTierPrice &&
          other.lineMrpTotal == lineMrpTotal &&
          other.lineTotal == lineTotal &&
          other.issue == issue;

  @override
  int get hashCode =>
      id.hashCode +
      product.hashCode +
      variant.hashCode +
      quantity.hashCode +
      pricePerUnit.hashCode +
      (priceTier == null ? 0 : priceTier.hashCode) +
      (nextTierPrice == null ? 0 : nextTierPrice.hashCode) +
      lineMrpTotal.hashCode +
      lineTotal.hashCode +
      (issue == null ? 0 : issue.hashCode);

  factory CartLine.fromJson(Map<String, dynamic> json) =>
      _$CartLineFromJson(json);

  Map<String, dynamic> toJson() => _$CartLineToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
