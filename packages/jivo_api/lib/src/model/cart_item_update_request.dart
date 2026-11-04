// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cart_item_update_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CartItemUpdateRequest {
  /// Returns a new [CartItemUpdateRequest] instance.
  CartItemUpdateRequest({required this.quantity});

  /// The line's new quantity. Use `DELETE` to remove the line.
  // minimum: 1
  // maximum: 1000
  @JsonKey(name: r'quantity', required: true, includeIfNull: false)
  final int quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemUpdateRequest && other.quantity == quantity;

  @override
  int get hashCode => quantity.hashCode;

  factory CartItemUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$CartItemUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CartItemUpdateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
