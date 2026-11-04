// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_line.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderLine {
  /// Returns a new [OrderLine] instance.
  OrderLine({
    required this.id,

    required this.variantId,

    required this.productId,

    required this.productName,

    required this.variantName,

    required this.image,

    required this.mrp,

    required this.sellingPrice,

    required this.quantity,

    required this.lineMrpTotal,

    required this.lineTotal,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'variant_id', required: true, includeIfNull: false)
  final int variantId;

  @JsonKey(name: r'product_id', required: true, includeIfNull: false)
  final int productId;

  @JsonKey(name: r'product_name', required: true, includeIfNull: false)
  final String productName;

  /// e.g. \"1 L\".
  @JsonKey(name: r'variant_name', required: true, includeIfNull: false)
  final String variantName;

  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  /// Unit MRP at order time.
  @JsonKey(name: r'mrp', required: true, includeIfNull: false)
  final String mrp;

  /// Unit price paid at order time.
  @JsonKey(name: r'selling_price', required: true, includeIfNull: false)
  final String sellingPrice;

  // minimum: 1
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  /// `mrp` x `quantity`.
  @JsonKey(name: r'line_mrp_total', required: true, includeIfNull: false)
  final String lineMrpTotal;

  /// `selling_price` x `quantity`.
  @JsonKey(name: r'line_total', required: true, includeIfNull: false)
  final String lineTotal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderLine &&
          other.id == id &&
          other.variantId == variantId &&
          other.productId == productId &&
          other.productName == productName &&
          other.variantName == variantName &&
          other.image == image &&
          other.mrp == mrp &&
          other.sellingPrice == sellingPrice &&
          other.quantity == quantity &&
          other.lineMrpTotal == lineMrpTotal &&
          other.lineTotal == lineTotal;

  @override
  int get hashCode =>
      id.hashCode +
      variantId.hashCode +
      productId.hashCode +
      productName.hashCode +
      variantName.hashCode +
      (image == null ? 0 : image.hashCode) +
      mrp.hashCode +
      sellingPrice.hashCode +
      quantity.hashCode +
      lineMrpTotal.hashCode +
      lineTotal.hashCode;

  factory OrderLine.fromJson(Map<String, dynamic> json) =>
      _$OrderLineFromJson(json);

  Map<String, dynamic> toJson() => _$OrderLineToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
