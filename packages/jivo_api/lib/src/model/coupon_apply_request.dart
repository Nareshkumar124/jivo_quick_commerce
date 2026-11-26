// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coupon_apply_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CouponApplyRequest {
  /// Returns a new [CouponApplyRequest] instance.
  CouponApplyRequest({required this.code, this.freeVariantId});

  /// Coupon code as typed; case-insensitive.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// For a free-carton reward (`discount_type` FREE_UNIT). ADR 0003: when the store in `X-Store-Id` has a fixed free size (`free_offer.free_variant`), leave it out (or send that size's id): the server uses the fixed size; any other id is 422 `COUPON_NOT_ELIGIBLE` (FREE_VARIANT_UNAVAILABLE). Otherwise (ADR 0002) it is required: the size the customer picked (`VariantSummary.id`), sold at the store, of the same product category as a paid line in the cart (a water reward goes on a water order) and with the stock. Ignored for other coupons.
  // minimum: 1
  @JsonKey(name: r'free_variant_id', required: false, includeIfNull: false)
  final int? freeVariantId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CouponApplyRequest &&
          other.code == code &&
          other.freeVariantId == freeVariantId;

  @override
  int get hashCode =>
      code.hashCode + (freeVariantId == null ? 0 : freeVariantId.hashCode);

  factory CouponApplyRequest.fromJson(Map<String, dynamic> json) =>
      _$CouponApplyRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CouponApplyRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
