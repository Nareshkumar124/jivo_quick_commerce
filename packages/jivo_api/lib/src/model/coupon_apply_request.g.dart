// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_apply_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CouponApplyRequestCWProxy {
  CouponApplyRequest code(String code);

  CouponApplyRequest freeVariantId(int? freeVariantId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponApplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponApplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponApplyRequest call({String code, int? freeVariantId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCouponApplyRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCouponApplyRequest.copyWith.fieldName(...)`
class _$CouponApplyRequestCWProxyImpl implements _$CouponApplyRequestCWProxy {
  const _$CouponApplyRequestCWProxyImpl(this._value);

  final CouponApplyRequest _value;

  @override
  CouponApplyRequest code(String code) => this(code: code);

  @override
  CouponApplyRequest freeVariantId(int? freeVariantId) =>
      this(freeVariantId: freeVariantId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponApplyRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponApplyRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponApplyRequest call({
    Object? code = const $CopyWithPlaceholder(),
    Object? freeVariantId = const $CopyWithPlaceholder(),
  }) {
    return CouponApplyRequest(
      code: code == const $CopyWithPlaceholder()
          ? _value.code
          // ignore: cast_nullable_to_non_nullable
          : code as String,
      freeVariantId: freeVariantId == const $CopyWithPlaceholder()
          ? _value.freeVariantId
          // ignore: cast_nullable_to_non_nullable
          : freeVariantId as int?,
    );
  }
}

extension $CouponApplyRequestCopyWith on CouponApplyRequest {
  /// Returns a callable class that can be used as follows: `instanceOfCouponApplyRequest.copyWith(...)` or like so:`instanceOfCouponApplyRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CouponApplyRequestCWProxy get copyWith =>
      _$CouponApplyRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CouponApplyRequest _$CouponApplyRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CouponApplyRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['code']);
      final val = CouponApplyRequest(
        code: $checkedConvert('code', (v) => v as String),
        freeVariantId: $checkedConvert(
          'free_variant_id',
          (v) => (v as num?)?.toInt(),
        ),
      );
      return val;
    }, fieldKeyMap: const {'freeVariantId': 'free_variant_id'});

Map<String, dynamic> _$CouponApplyRequestToJson(CouponApplyRequest instance) =>
    <String, dynamic>{
      'code': instance.code,
      'free_variant_id': ?instance.freeVariantId,
    };
