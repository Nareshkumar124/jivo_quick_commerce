// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_offer.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CouponOfferCWProxy {
  CouponOffer code(String code);

  CouponOffer title(String title);

  CouponOffer description(String description);

  CouponOffer discountType(CouponDiscountTypeEnum discountType);

  CouponOffer value(String value);

  CouponOffer maxDiscount(String? maxDiscount);

  CouponOffer minOrderValue(String minOrderValue);

  CouponOffer endsAt(DateTime? endsAt);

  CouponOffer isApplied(bool isApplied);

  CouponOffer isEligible(bool isEligible);

  CouponOffer savings(String? savings);

  CouponOffer ineligibleReason(CouponIneligibleReasonEnum? ineligibleReason);

  CouponOffer message(String? message);

  CouponOffer amountToUnlock(String? amountToUnlock);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponOffer call({
    String code,
    String title,
    String description,
    CouponDiscountTypeEnum discountType,
    String value,
    String? maxDiscount,
    String minOrderValue,
    DateTime? endsAt,
    bool isApplied,
    bool isEligible,
    String? savings,
    CouponIneligibleReasonEnum? ineligibleReason,
    String? message,
    String? amountToUnlock,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCouponOffer.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCouponOffer.copyWith.fieldName(...)`
class _$CouponOfferCWProxyImpl implements _$CouponOfferCWProxy {
  const _$CouponOfferCWProxyImpl(this._value);

  final CouponOffer _value;

  @override
  CouponOffer code(String code) => this(code: code);

  @override
  CouponOffer title(String title) => this(title: title);

  @override
  CouponOffer description(String description) => this(description: description);

  @override
  CouponOffer discountType(CouponDiscountTypeEnum discountType) =>
      this(discountType: discountType);

  @override
  CouponOffer value(String value) => this(value: value);

  @override
  CouponOffer maxDiscount(String? maxDiscount) =>
      this(maxDiscount: maxDiscount);

  @override
  CouponOffer minOrderValue(String minOrderValue) =>
      this(minOrderValue: minOrderValue);

  @override
  CouponOffer endsAt(DateTime? endsAt) => this(endsAt: endsAt);

  @override
  CouponOffer isApplied(bool isApplied) => this(isApplied: isApplied);

  @override
  CouponOffer isEligible(bool isEligible) => this(isEligible: isEligible);

  @override
  CouponOffer savings(String? savings) => this(savings: savings);

  @override
  CouponOffer ineligibleReason(CouponIneligibleReasonEnum? ineligibleReason) =>
      this(ineligibleReason: ineligibleReason);

  @override
  CouponOffer message(String? message) => this(message: message);

  @override
  CouponOffer amountToUnlock(String? amountToUnlock) =>
      this(amountToUnlock: amountToUnlock);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponOffer(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponOffer(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponOffer call({
    Object? code = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? discountType = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
    Object? maxDiscount = const $CopyWithPlaceholder(),
    Object? minOrderValue = const $CopyWithPlaceholder(),
    Object? endsAt = const $CopyWithPlaceholder(),
    Object? isApplied = const $CopyWithPlaceholder(),
    Object? isEligible = const $CopyWithPlaceholder(),
    Object? savings = const $CopyWithPlaceholder(),
    Object? ineligibleReason = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? amountToUnlock = const $CopyWithPlaceholder(),
  }) {
    return CouponOffer(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String,
      discountType: discountType == const $CopyWithPlaceholder()
          ? _value.discountType
          // ignore: cast_nullable_to_non_nullable
          : discountType as CouponDiscountTypeEnum,
      value: value == const $CopyWithPlaceholder()
          ? _value.value
          // ignore: cast_nullable_to_non_nullable
          : value as String,
      maxDiscount: maxDiscount == const $CopyWithPlaceholder()
          ? _value.maxDiscount
          // ignore: cast_nullable_to_non_nullable
          : maxDiscount as String?,
      minOrderValue: minOrderValue == const $CopyWithPlaceholder()
          ? _value.minOrderValue
          // ignore: cast_nullable_to_non_nullable
          : minOrderValue as String,
      endsAt: endsAt == const $CopyWithPlaceholder()
          ? _value.endsAt
          // ignore: cast_nullable_to_non_nullable
          : endsAt as DateTime?,
      isApplied: isApplied == const $CopyWithPlaceholder()
          ? _value.isApplied
          // ignore: cast_nullable_to_non_nullable
          : isApplied as bool,
      isEligible: isEligible == const $CopyWithPlaceholder()
          ? _value.isEligible
          // ignore: cast_nullable_to_non_nullable
          : isEligible as bool,
      savings: savings == const $CopyWithPlaceholder()
          ? _value.savings
          // ignore: cast_nullable_to_non_nullable
          : savings as String?,
      ineligibleReason: ineligibleReason == const $CopyWithPlaceholder()
          ? _value.ineligibleReason
          // ignore: cast_nullable_to_non_nullable
          : ineligibleReason as CouponIneligibleReasonEnum?,
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

extension $CouponOfferCopyWith on CouponOffer {
  /// Returns a callable class that can be used as follows: `instanceOfCouponOffer.copyWith(...)` or like so:`instanceOfCouponOffer.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CouponOfferCWProxy get copyWith => _$CouponOfferCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CouponOffer _$CouponOfferFromJson(Map<String, dynamic> json) => $checkedCreate(
  'CouponOffer',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'code',
        'title',
        'description',
        'discount_type',
        'value',
        'max_discount',
        'min_order_value',
        'ends_at',
        'is_applied',
        'is_eligible',
        'savings',
        'ineligible_reason',
        'message',
        'amount_to_unlock',
      ],
    );
    final val = CouponOffer(
      code: $checkedConvert('code', (v) => v as String),
      title: $checkedConvert('title', (v) => v as String),
      description: $checkedConvert('description', (v) => v as String),
      discountType: $checkedConvert(
        'discount_type',
        (v) => $enumDecode(
          _$CouponDiscountTypeEnumEnumMap,
          v,
          unknownValue: CouponDiscountTypeEnum.unknownDefaultOpenApi,
        ),
      ),
      value: $checkedConvert('value', (v) => v as String),
      maxDiscount: $checkedConvert('max_discount', (v) => v as String?),
      minOrderValue: $checkedConvert('min_order_value', (v) => v as String),
      endsAt: $checkedConvert(
        'ends_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      isApplied: $checkedConvert('is_applied', (v) => v as bool),
      isEligible: $checkedConvert('is_eligible', (v) => v as bool),
      savings: $checkedConvert('savings', (v) => v as String?),
      ineligibleReason: $checkedConvert(
        'ineligible_reason',
        (v) => $enumDecodeNullable(
          _$CouponIneligibleReasonEnumEnumMap,
          v,
          unknownValue: CouponIneligibleReasonEnum.unknownDefaultOpenApi,
        ),
      ),
      message: $checkedConvert('message', (v) => v as String?),
      amountToUnlock: $checkedConvert('amount_to_unlock', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'discountType': 'discount_type',
    'maxDiscount': 'max_discount',
    'minOrderValue': 'min_order_value',
    'endsAt': 'ends_at',
    'isApplied': 'is_applied',
    'isEligible': 'is_eligible',
    'ineligibleReason': 'ineligible_reason',
    'amountToUnlock': 'amount_to_unlock',
  },
);

Map<String, dynamic> _$CouponOfferToJson(CouponOffer instance) =>
    <String, dynamic>{
      'code': instance.code,
      'title': instance.title,
      'description': instance.description,
      'discount_type': _$CouponDiscountTypeEnumEnumMap[instance.discountType]!,
      'value': instance.value,
      'max_discount': instance.maxDiscount,
      'min_order_value': instance.minOrderValue,
      'ends_at': instance.endsAt?.toIso8601String(),
      'is_applied': instance.isApplied,
      'is_eligible': instance.isEligible,
      'savings': instance.savings,
      'ineligible_reason':
          _$CouponIneligibleReasonEnumEnumMap[instance.ineligibleReason],
      'message': instance.message,
      'amount_to_unlock': instance.amountToUnlock,
    };

const _$CouponDiscountTypeEnumEnumMap = {
  CouponDiscountTypeEnum.FLAT: 'FLAT',
  CouponDiscountTypeEnum.PERCENT: 'PERCENT',
  CouponDiscountTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$CouponIneligibleReasonEnumEnumMap = {
  CouponIneligibleReasonEnum.MIN_ORDER_VALUE: 'MIN_ORDER_VALUE',
  CouponIneligibleReasonEnum.FIRST_ORDER_ONLY: 'FIRST_ORDER_ONLY',
  CouponIneligibleReasonEnum.NO_ELIGIBLE_ITEMS: 'NO_ELIGIBLE_ITEMS',
  CouponIneligibleReasonEnum.STORE: 'STORE',
  CouponIneligibleReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
