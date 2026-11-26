// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'free_variant.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FreeVariant {
  /// Returns a new [FreeVariant] instance.
  FreeVariant({
    required this.id,

    required this.name,

    required this.productName,
  });

  /// `VariantSummary.id`.
  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// The size, e.g. \"1 L x 12\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  /// The product, e.g. \"Jivo Water\".
  @JsonKey(name: r'product_name', required: true, includeIfNull: false)
  final String productName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreeVariant &&
          other.id == id &&
          other.name == name &&
          other.productName == productName;

  @override
  int get hashCode => id.hashCode + name.hashCode + productName.hashCode;

  factory FreeVariant.fromJson(Map<String, dynamic> json) =>
      _$FreeVariantFromJson(json);

  Map<String, dynamic> toJson() => _$FreeVariantToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
