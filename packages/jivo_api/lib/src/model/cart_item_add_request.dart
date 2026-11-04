// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_item_add_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartItemAddRequest {
  /// Returns a new [CartItemAddRequest] instance.
  CartItemAddRequest({required this.variantId, required this.quantity});

  /// `VariantSummary.id`.
  // minimum: 1
  @JsonKey(name: r'variant_id', required: true, includeIfNull: false)
  final int variantId;

  /// The line's **new** quantity for this variant (not an increment), so a retried request does not add twice. 0 removes the line.
  // minimum: 0
  // maximum: 1000
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemAddRequest &&
          other.variantId == variantId &&
          other.quantity == quantity;

  @override
  int get hashCode => variantId.hashCode + quantity.hashCode;

  factory CartItemAddRequest.fromJson(Map<String, dynamic> json) =>
      _$CartItemAddRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CartItemAddRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
