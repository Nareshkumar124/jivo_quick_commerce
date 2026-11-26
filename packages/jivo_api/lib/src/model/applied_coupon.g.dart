// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'applied_coupon.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AppliedCouponCWProxy {
  AppliedCoupon code(String code);

  AppliedCoupon title(String title);

  AppliedCoupon discountType(CouponDiscountTypeEnum discountType);

  AppliedCoupon source_(CouponSourceEnum source_);

  AppliedCoupon freeVariantId(int? freeVariantId);

  AppliedCoupon freeQuantity(int? freeQuantity);

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
    CouponDiscountTypeEnum discountType,
    CouponSourceEnum source_,
    int? freeVariantId,
    int? freeQuantity,
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
  AppliedCoupon discountType(CouponDiscountTypeEnum discountType) =>
      this(discountType: discountType);

  @override
  AppliedCoupon source_(CouponSourceEnum source_) => this(source_: source_);

  @override
  AppliedCoupon freeVariantId(int? freeVariantId) =>
      this(freeVariantId: freeVariantId);

  @override
  AppliedCoupon freeQuantity(int? freeQuantity) =>
      this(freeQuantity: freeQuantity);

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
    Object? discountType = const $CopyWithPlaceholder(),
    Object? source_ = const $CopyWithPlaceholder(),
    Object? freeVariantId = const $CopyWithPlaceholder(),
    Object? freeQuantity = const $CopyWithPlaceholder(),
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
      discountType: discountType == const $CopyWithPlaceholder()
          ? _value.discountType
          // ignore: cast_nullable_to_non_nullable
          : discountType as CouponDiscountTypeEnum,
      source_: source_ == const $CopyWithPlaceholder()
          ? _value.source_
          // ignore: cast_nullable_to_non_nullable
          : source_ as CouponSourceEnum,
      freeVariantId: freeVariantId == const $CopyWithPlaceholder()
          ? _value.freeVariantId
          // ignore: cast_nullable_to_non_nullable
          : freeVariantId as int?,
      freeQuantity: freeQuantity == const $CopyWithPlaceholder()
          ? _value.freeQuantity
          // ignore: cast_nullable_to_non_nullable
          : freeQuantity as int?,
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
            'discount_type',
            'source',
            'free_variant_id',
            'free_quantity',
            'discount',
            'is_applicable',
            'message',
            'amount_to_unlock',
          ],
        );
        final val = AppliedCoupon(
          code: $checkedConvert('code', (v) => v as String),
          title: $checkedConvert('title', (v) => v as String),
          discountType: $checkedConvert(
            'discount_type',
            (v) => $enumDecode(
              _$CouponDiscountTypeEnumEnumMap,
              v,
              unknownValue: CouponDiscountTypeEnum.unknownDefaultOpenApi,
            ),
          ),
          source_: $checkedConvert(
            'source',
            (v) => $enumDecode(
              _$CouponSourceEnumEnumMap,
              v,
              unknownValue: CouponSourceEnum.unknownDefaultOpenApi,
            ),
          ),
          freeVariantId: $checkedConvert(
            'free_variant_id',
            (v) => (v as num?)?.toInt(),
          ),
          freeQuantity: $checkedConvert(
            'free_quantity',
            (v) => (v as num?)?.toInt(),
          ),
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
        'discountType': 'discount_type',
        'source_': 'source',
        'freeVariantId': 'free_variant_id',
        'freeQuantity': 'free_quantity',
        'isApplicable': 'is_applicable',
        'amountToUnlock': 'amount_to_unlock',
      },
    );

Map<String, dynamic> _$AppliedCouponToJson(AppliedCoupon instance) =>
    <String, dynamic>{
      'code': instance.code,
      'title': instance.title,
      'discount_type': _$CouponDiscountTypeEnumEnumMap[instance.discountType]!,
      'source': _$CouponSourceEnumEnumMap[instance.source_]!,
      'free_variant_id': instance.freeVariantId,
      'free_quantity': instance.freeQuantity,
      'discount': instance.discount,
      'is_applicable': instance.isApplicable,
      'message': instance.message,
      'amount_to_unlock': instance.amountToUnlock,
    };

const _$CouponDiscountTypeEnumEnumMap = {
  CouponDiscountTypeEnum.FLAT: 'FLAT',
  CouponDiscountTypeEnum.PERCENT: 'PERCENT',
  CouponDiscountTypeEnum.FREE_UNIT: 'FREE_UNIT',
  CouponDiscountTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$CouponSourceEnumEnumMap = {
  CouponSourceEnum.NONE: 'NONE',
  CouponSourceEnum.WELCOME: 'WELCOME',
  CouponSourceEnum.REFERRAL_REFERRER: 'REFERRAL_REFERRER',
  CouponSourceEnum.REFERRAL_REFERRED: 'REFERRAL_REFERRED',
  CouponSourceEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
