// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
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
          other.discount == discount &&
          other.isApplicable == isApplicable &&
          other.message == message &&
          other.amountToUnlock == amountToUnlock;

  @override
  int get hashCode =>
      code.hashCode +
      title.hashCode +
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
