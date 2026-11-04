// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'applied_coupon.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppliedCouponCWProxy {
  AppliedCoupon code(String code);

  AppliedCoupon title(String title);

  AppliedCoupon discount(String discount);

  AppliedCoupon isApplicable(bool isApplicable);

  AppliedCoupon message(String? message);

  AppliedCoupon amountToUnlock(String? amountToUnlock);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AppliedCoupon(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AppliedCoupon(...).copyWith(id: 12, name: "My name")
  /// ````
  AppliedCoupon call({
    String code,
    String title,
    String discount,
    bool isApplicable,
    String? message,
    String? amountToUnlock,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAppliedCoupon.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAppliedCoupon.copyWith.fieldName(...)`
class _$AppliedCouponCWProxyImpl implements _$AppliedCouponCWProxy {
  const _$AppliedCouponCWProxyImpl(this._value);

  final AppliedCoupon _value;

  @override
  AppliedCoupon code(String code) => this(code: code);

  @override
  AppliedCoupon title(String title) => this(title: title);

  @override
  AppliedCoupon discount(String discount) => this(discount: discount);

  @override
  AppliedCoupon isApplicable(bool isApplicable) =>
      this(isApplicable: isApplicable);

  @override
  AppliedCoupon message(String? message) => this(message: message);

  @override
  AppliedCoupon amountToUnlock(String? amountToUnlock) =>
      this(amountToUnlock: amountToUnlock);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AppliedCoupon(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AppliedCoupon(...).copyWith(id: 12, name: "My name")
  /// ````
  AppliedCoupon call({
    Object? code = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? discount = const $CopyWithPlaceholder(),
    Object? isApplicable = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? amountToUnlock = const $CopyWithPlaceholder(),
  }) {
    return AppliedCoupon(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      discount: discount == const $CopyWithPlaceholder()
          ? _value.discount
          // ignore: cast_nullable_to_non_nullable
          : discount as String,
      isApplicable: isApplicable == const $CopyWithPlaceholder()
          ? _value.isApplicable
          // ignore: cast_nullable_to_non_nullable
          : isApplicable as bool,
      message: message == const $CopyWithPlaceholder()
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String?,
      amountToUnlock: amountToUnlock == const $CopyWithPlaceholder()
          ? _value.amountToUnlock
          // ignore: cast_nullable_to_non_nullable
          : amountToUnlock as String?,
    );
  }
}

extension $AppliedCouponCopyWith on AppliedCoupon {
  /// Returns a callable class that can be used as follows: `instanceOfAppliedCoupon.copyWith(...)` or like so:`instanceOfAppliedCoupon.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AppliedCouponCWProxy get copyWith => _$AppliedCouponCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppliedCoupon _$AppliedCouponFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AppliedCoupon',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'code',
            'title',
            'discount',
            'is_applicable',
            'message',
            'amount_to_unlock',
          ],
        );
        final val = AppliedCoupon(
          code: $checkedConvert('code', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          discount: $checkedConvert('discount', (v) => v as String),
          isApplicable: $checkedConvert('is_applicable', (v) => v as bool),
          message: $checkedConvert('message', (v) => v as String?),
          amountToUnlock: $checkedConvert(
            'amount_to_unlock',
            (v) => v as String?,
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'isApplicable': 'is_applicable',
        'amountToUnlock': 'amount_to_unlock',
      },
    );

Map<String, dynamic> _$AppliedCouponToJson(AppliedCoupon instance) =>
    <String, dynamic>{
      'code': instance.code,
      'title': instance.title,
      'discount': instance.discount,
      'is_applicable': instance.isApplicable,
      'message': instance.message,
      'amount_to_unlock': instance.amountToUnlock,
    };
