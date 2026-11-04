// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_product.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartProduct {
  /// Returns a new [CartProduct] instance.
  CartProduct({
    required this.id,

    required this.slug,

    required this.name,

    required this.brand,

    required this.isVeg,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// `GET /products/{slug}/`.
  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'brand', required: true, includeIfNull: false)
  final String brand;

  @JsonKey(name: r'is_veg', required: true, includeIfNull: false)
  final bool isVeg;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartProduct &&
          other.id == id &&
          other.slug == slug &&
          other.name == name &&
          other.brand == brand &&
          other.isVeg == isVeg;

  @override
  int get hashCode =>
      id.hashCode +
      slug.hashCode +
      name.hashCode +
      brand.hashCode +
      isVeg.hashCode;

  factory CartProduct.fromJson(Map<String, dynamic> json) =>
      _$CartProductFromJson(json);

  Map<String, dynamic> toJson() => _$CartProductToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
