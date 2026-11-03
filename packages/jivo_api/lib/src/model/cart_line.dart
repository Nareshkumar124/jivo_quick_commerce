// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/cart_product.dart';
import 'package:jivo_api/src/model/variant_summary.dart';
import 'package:jivo_api/src/model/cart_line_issue.dart';
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

  /// `variant.mrp` x `quantity`.
  @JsonKey(name: r'line_mrp_total', required: true, includeIfNull: false)
  final String lineMrpTotal;

  /// `variant.selling_price` x `quantity`.
  @JsonKey(name: r'line_total', required: true, includeIfNull: false)
  final String lineTotal;

  /// Set when the line cannot be ordered as it is (quantity above `variant.orderable_quantity`, which is 0 when out of stock or no longer sold). Fix: set the quantity to `variant.orderable_quantity`, or remove the line when it is 0. Null when the line is fine.
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
          other.lineMrpTotal == lineMrpTotal &&
          other.lineTotal == lineTotal &&
          other.issue == issue;

  @override
  int get hashCode =>
      id.hashCode +
      product.hashCode +
      variant.hashCode +
      quantity.hashCode +
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
