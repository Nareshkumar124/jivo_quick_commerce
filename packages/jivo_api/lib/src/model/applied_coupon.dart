// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/coupon_discount_type_enum.dart';
import 'package:jivo_api/src/model/coupon_source_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'applied_coupon.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AppliedCoupon {
  /// Returns a new [AppliedCoupon] instance.
  AppliedCoupon({
    required this.code,

    required this.title,

    required this.discountType,

    required this.source_,

    required this.freeVariantId,

    required this.discount,

    required this.isApplicable,

    required this.message,

    required this.amountToUnlock,
  });

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// e.g. \"Flat ₹50 off\".
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// FREE_UNIT: a free-carton reward (ADR 0002). It gives no money off (`discount` is \"0.00\"); its carton is in `free_lines` with `source` REWARD.  * `FLAT` - Flat amount off * `PERCENT` - Percent off * `FREE_UNIT` - One free carton (reward)
  @JsonKey(
    name: r'discount_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CouponDiscountTypeEnum.unknownDefaultOpenApi,
  )
  final CouponDiscountTypeEnum discountType;

  /// Why the coupon exists: WELCOME / REFERRAL_* rewards, NONE for staff coupons.  * `NONE` - Made by staff * `WELCOME` - Welcome reward (new account) * `REFERRAL_REFERRER` - Referral reward (you invited a friend) * `REFERRAL_REFERRED` - Referral reward (you joined with a friend's code)
  @JsonKey(
    name: r'source',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CouponSourceEnum.unknownDefaultOpenApi,
  )
  final CouponSourceEnum source_;

  /// FREE_UNIT only: the size picked for the free carton (`VariantSummary.id`, sent as `free_variant_id` when applying). Null for other coupons.
  @JsonKey(name: r'free_variant_id', required: true, includeIfNull: true)
  final int? freeVariantId;

  /// The discount it gives this cart now (\"0.00\" when it does not apply).
  @JsonKey(name: r'discount', required: true, includeIfNull: false)
  final String discount;

  /// False when the cart no longer qualifies (e.g. items removed): the coupon stays applied but gives nothing, and checkout is blocked until it is removed or the cart qualifies again (see `checkout.blockers`).
  @JsonKey(name: r'is_applicable', required: true, includeIfNull: false)
  final bool isApplicable;

  /// Why it does not apply (e.g. 'Add items worth ₹74 more'); null when it does.
  @JsonKey(name: r'message', required: true, includeIfNull: true)
  final String? message;

  /// When it does not apply because the item total is below its minimum: the item value still needed (for the app's own 'Add items worth ₹X more'). Null otherwise. Added in Phase 3 R2b, like `CouponOffer.amount_to_unlock`.
  @JsonKey(name: r'amount_to_unlock', required: true, includeIfNull: true)
  final String? amountToUnlock;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppliedCoupon &&
          other.code == code &&
          other.title == title &&
          other.discountType == discountType &&
          other.source_ == source_ &&
          other.freeVariantId == freeVariantId &&
          other.discount == discount &&
          other.isApplicable == isApplicable &&
          other.message == message &&
          other.amountToUnlock == amountToUnlock;

  @override
  int get hashCode =>
      code.hashCode +
      title.hashCode +
      discountType.hashCode +
      source_.hashCode +
      (freeVariantId == null ? 0 : freeVariantId.hashCode) +
      discount.hashCode +
      isApplicable.hashCode +
      (message == null ? 0 : message.hashCode) +
      (amountToUnlock == null ? 0 : amountToUnlock.hashCode);

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) =>
      _$AppliedCouponFromJson(json);

  Map<String, dynamic> toJson() => _$AppliedCouponToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
