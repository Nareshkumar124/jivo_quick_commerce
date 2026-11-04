// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_instructions_request.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_cart_update_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedCartUpdateRequest {
  /// Returns a new [PatchedCartUpdateRequest] instance.
  PatchedCartUpdateRequest({this.tip, this.instructions, this.addressId});

  /// Rider tip, e.g. \"20.00\"; \"0.00\" removes it. At most the server's tip limit (`CART_MAX_TIP`, ₹500 by default).
  @JsonKey(name: r'tip', required: false, includeIfNull: false)
  final String? tip;

  /// Replaces the instructions (chips and note) as a whole.
  @JsonKey(name: r'instructions', required: false, includeIfNull: false)
  final DeliveryInstructionsRequest? instructions;

  /// One of the caller's saved addresses. It must be inside the service area of the store in `X-Store-Id`, else 422 `NOT_SERVICEABLE` and nothing is saved.
  // minimum: 1
  @JsonKey(name: r'address_id', required: false, includeIfNull: false)
  final int? addressId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedCartUpdateRequest &&
          other.tip == tip &&
          other.instructions == instructions &&
          other.addressId == addressId;

  @override
  int get hashCode => tip.hashCode + instructions.hashCode + addressId.hashCode;

  factory PatchedCartUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedCartUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedCartUpdateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
