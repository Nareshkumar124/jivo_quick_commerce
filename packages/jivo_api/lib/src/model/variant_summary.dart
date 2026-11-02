// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/stock_status_enum.dart';
import 'package:jivo_api/src/model/unit_price.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'variant_summary.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class VariantSummary {
  /// Returns a new [VariantSummary] instance.
  VariantSummary({
    required this.id,

    required this.name,

    required this.mrp,

    required this.sellingPrice,

    required this.discountAmount,

    required this.discountPercent,

    required this.unitPrice,

    required this.stockStatus,

    required this.orderableQuantity,

    required this.unitsLeft,

    required this.maxQtyPerOrder,

    required this.image,
  });

  /// Variant id: what the cart adds (Phase 3).
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Variant label shown on tiles and chips, e.g. \"1 L\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// MRP (inclusive of all taxes). Show struck out when above `selling_price`.
  @JsonKey(name: r'mrp', required: true, includeIfNull: false)
  final String mrp;

  /// Price at this store (the store's price override when set).
  @JsonKey(name: r'selling_price', required: true, includeIfNull: false)
  final String sellingPrice;

  /// `mrp` - `selling_price`, \"0.00\" when none (\"You save ₹70\").
  @JsonKey(name: r'discount_amount', required: true, includeIfNull: false)
  final String discountAmount;

  /// Whole percent off MRP, rounded down (never overstated). Show the badge ('20% OFF') only when above 0.
  // minimum: 0
  // maximum: 99
  @JsonKey(name: r'discount_percent', required: true, includeIfNull: false)
  final int discountPercent;

  /// Unit sale price; null when not applicable.
  @JsonKey(name: r'unit_price', required: true, includeIfNull: true)
  final UnitPrice? unitPrice;

  @JsonKey(
    name: r'stock_status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: StockStatusEnum.unknownDefaultOpenApi,
  )
  final StockStatusEnum stockStatus;

  /// Units a customer can add right now: min(units in stock at this store, `max_qty_per_order`). 0 when out of stock. Cap the ADD stepper here.
  // minimum: 0
  @JsonKey(name: r'orderable_quantity', required: true, includeIfNull: false)
  final int orderableQuantity;

  /// Set only when `stock_status` is LOW_STOCK: the units left, for 'Only 2 left'. Null otherwise (exact stock is not published).
  // minimum: 1
  @JsonKey(name: r'units_left', required: true, includeIfNull: true)
  final int? unitsLeft;

  /// Per-order limit for this variant (also enforced by the cart).
  // minimum: 1
  @JsonKey(name: r'max_qty_per_order', required: true, includeIfNull: false)
  final int maxQtyPerOrder;

  /// The variant's own first image, else the product's. Null when none.
  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariantSummary &&
          other.id == id &&
          other.name == name &&
          other.mrp == mrp &&
          other.sellingPrice == sellingPrice &&
          other.discountAmount == discountAmount &&
          other.discountPercent == discountPercent &&
          other.unitPrice == unitPrice &&
          other.stockStatus == stockStatus &&
          other.orderableQuantity == orderableQuantity &&
          other.unitsLeft == unitsLeft &&
          other.maxQtyPerOrder == maxQtyPerOrder &&
          other.image == image;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      mrp.hashCode +
      sellingPrice.hashCode +
      discountAmount.hashCode +
      discountPercent.hashCode +
      (unitPrice == null ? 0 : unitPrice.hashCode) +
      stockStatus.hashCode +
      orderableQuantity.hashCode +
      (unitsLeft == null ? 0 : unitsLeft.hashCode) +
      maxQtyPerOrder.hashCode +
      (image == null ? 0 : image.hashCode);

  factory VariantSummary.fromJson(Map<String, dynamic> json) =>
      _$VariantSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$VariantSummaryToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
