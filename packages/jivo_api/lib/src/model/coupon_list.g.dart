// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CouponListCWProxy {
  CouponList results(List<CouponOffer> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponList(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponList call({List<CouponOffer> results});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCouponList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCouponList.copyWith.fieldName(...)`
class _$CouponListCWProxyImpl implements _$CouponListCWProxy {
  const _$CouponListCWProxyImpl(this._value);

  final CouponList _value;

  @override
  CouponList results(List<CouponOffer> results) => this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CouponList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CouponList(...).copyWith(id: 12, name: "My name")
  /// ````
  CouponList call({Object? results = const $CopyWithPlaceholder()}) {
    return CouponList(
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<CouponOffer>,
    );
  }
}

extension $CouponListCopyWith on CouponList {
  /// Returns a callable class that can be used as follows: `instanceOfCouponList.copyWith(...)` or like so:`instanceOfCouponList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CouponListCWProxy get copyWith => _$CouponListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CouponList _$CouponListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('CouponList', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['results']);
      final val = CouponList(
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => CouponOffer.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$CouponListToJson(CouponList instance) =>
    <String, dynamic>{
      'results': instance.results.map((e) => e.toJson()).toList(),
    };
