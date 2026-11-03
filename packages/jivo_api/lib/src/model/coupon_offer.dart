// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/coupon_discount_type_enum.dart';
import 'package:jivo_api/src/model/coupon_ineligible_reason_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'coupon_offer.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CouponOffer {
  /// Returns a new [CouponOffer] instance.
  CouponOffer({
    required this.code,

    required this.title,

    required this.description,

    required this.discountType,

    required this.value,

    required this.maxDiscount,

    required this.minOrderValue,

    required this.endsAt,

    required this.isApplied,

    required this.isEligible,

    required this.savings,

    required this.ineligibleReason,

    required this.message,

    required this.amountToUnlock,
  });

  /// Upper case. Apply with `POST /cart/coupon/`.
  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  /// e.g. \"Flat ₹50 off\".
  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  /// Terms in one line, e.g. \"On orders above ₹299\".
  @JsonKey(name: r'description', required: true, includeIfNull: false)
  final String description;

  @JsonKey(
    name: r'discount_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: CouponDiscountTypeEnum.unknownDefaultOpenApi,
  )
  final CouponDiscountTypeEnum discountType;

  /// FLAT: rupees off (\"50.00\"). PERCENT: percent off (\"10.00\" = 10%).
  @JsonKey(name: r'value', required: true, includeIfNull: false)
  final String value;

  /// Cap on the discount (PERCENT coupons); null when uncapped.
  @JsonKey(name: r'max_discount', required: true, includeIfNull: true)
  final String? maxDiscount;

  /// Minimum `item_total` (before the coupon), \"0.00\" when none.
  @JsonKey(name: r'min_order_value', required: true, includeIfNull: false)
  final String minOrderValue;

  /// UTC expiry (show 'Expires on ...' in IST); null = no expiry.
  @JsonKey(name: r'ends_at', required: true, includeIfNull: true)
  final DateTime? endsAt;

  /// True for the coupon on the cart now.
  @JsonKey(name: r'is_applied', required: true, includeIfNull: false)
  final bool isApplied;

  /// Show APPLY enabled only when true.
  @JsonKey(name: r'is_eligible', required: true, includeIfNull: false)
  final bool isEligible;

  /// What it would save on this cart now (the server's `coupon_discount`); null when not eligible.
  @JsonKey(name: r'savings', required: true, includeIfNull: true)
  final String? savings;

  @JsonKey(
    name: r'ineligible_reason',
    required: true,
    includeIfNull: true,
    unknownEnumValue: CouponIneligibleReasonEnum.unknownDefaultOpenApi,
  )
  final CouponIneligibleReasonEnum? ineligibleReason;

  /// Why it is not eligible, with the fix (e.g. 'Add items worth ₹716 more').
  @JsonKey(name: r'message', required: true, includeIfNull: true)
  final String? message;

  /// MIN_ORDER_VALUE only: item value still needed. Null otherwise.
  @JsonKey(name: r'amount_to_unlock', required: true, includeIfNull: true)
  final String? amountToUnlock;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CouponOffer &&
          other.code == code &&
          other.title == title &&
          other.description == description &&
          other.discountType == discountType &&
          other.value == value &&
          other.maxDiscount == maxDiscount &&
          other.minOrderValue == minOrderValue &&
          other.endsAt == endsAt &&
          other.isApplied == isApplied &&
          other.isEligible == isEligible &&
          other.savings == savings &&
          other.ineligibleReason == ineligibleReason &&
          other.message == message &&
          other.amountToUnlock == amountToUnlock;

  @override
  int get hashCode =>
      code.hashCode +
      title.hashCode +
      description.hashCode +
      discountType.hashCode +
      value.hashCode +
      (maxDiscount == null ? 0 : maxDiscount.hashCode) +
      minOrderValue.hashCode +
      (endsAt == null ? 0 : endsAt.hashCode) +
      isApplied.hashCode +
      isEligible.hashCode +
      (savings == null ? 0 : savings.hashCode) +
      (ineligibleReason == null ? 0 : ineligibleReason.hashCode) +
      (message == null ? 0 : message.hashCode) +
      (amountToUnlock == null ? 0 : amountToUnlock.hashCode);

  factory CouponOffer.fromJson(Map<String, dynamic> json) =>
      _$CouponOfferFromJson(json);

  Map<String, dynamic> toJson() => _$CouponOfferToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
