// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earning_totals.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EarningTotalsCWProxy {
  EarningTotals BASE(String BASE);

  EarningTotals DISTANCE(String DISTANCE);

  EarningTotals TIP(String TIP);

  EarningTotals INCENTIVE(String INCENTIVE);

  EarningTotals PENALTY(String PENALTY);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningTotals(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningTotals(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningTotals call({
    String BASE,
    String DISTANCE,
    String TIP,
    String INCENTIVE,
    String PENALTY,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEarningTotals.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEarningTotals.copyWith.fieldName(...)`
class _$EarningTotalsCWProxyImpl implements _$EarningTotalsCWProxy {
  const _$EarningTotalsCWProxyImpl(this._value);

  final EarningTotals _value;

  @override
  EarningTotals BASE(String BASE) => this(BASE: BASE);

  @override
  EarningTotals DISTANCE(String DISTANCE) => this(DISTANCE: DISTANCE);

  @override
  EarningTotals TIP(String TIP) => this(TIP: TIP);

  @override
  EarningTotals INCENTIVE(String INCENTIVE) => this(INCENTIVE: INCENTIVE);

  @override
  EarningTotals PENALTY(String PENALTY) => this(PENALTY: PENALTY);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningTotals(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningTotals(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningTotals call({
    Object? BASE = const $CopyWithPlaceholder(),
    Object? DISTANCE = const $CopyWithPlaceholder(),
    Object? TIP = const $CopyWithPlaceholder(),
    Object? INCENTIVE = const $CopyWithPlaceholder(),
    Object? PENALTY = const $CopyWithPlaceholder(),
  }) {
    return EarningTotals(
      BASE: BASE == const $CopyWithPlaceholder()
          ? _value.BASE
          // ignore: cast_nullable_to_non_nullable
          : BASE as String,
      DISTANCE: DISTANCE == const $CopyWithPlaceholder()
          ? _value.DISTANCE
          // ignore: cast_nullable_to_non_nullable
          : DISTANCE as String,
      TIP: TIP == const $CopyWithPlaceholder()
          ? _value.TIP
          // ignore: cast_nullable_to_non_nullable
          : TIP as String,
      INCENTIVE: INCENTIVE == const $CopyWithPlaceholder()
          ? _value.INCENTIVE
          // ignore: cast_nullable_to_non_nullable
          : INCENTIVE as String,
      PENALTY: PENALTY == const $CopyWithPlaceholder()
          ? _value.PENALTY
          // ignore: cast_nullable_to_non_nullable
          : PENALTY as String,
    );
  }
}

extension $EarningTotalsCopyWith on EarningTotals {
  /// Returns a callable class that can be used as follows: `instanceOfEarningTotals.copyWith(...)` or like so:`instanceOfEarningTotals.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EarningTotalsCWProxy get copyWith => _$EarningTotalsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EarningTotals _$EarningTotalsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EarningTotals', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['BASE', 'DISTANCE', 'TIP', 'INCENTIVE', 'PENALTY'],
      );
      final val = EarningTotals(
        BASE: $checkedConvert('BASE', (v) => v as String),
        DISTANCE: $checkedConvert('DISTANCE', (v) => v as String),
        TIP: $checkedConvert('TIP', (v) => v as String),
        INCENTIVE: $checkedConvert('INCENTIVE', (v) => v as String),
        PENALTY: $checkedConvert('PENALTY', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$EarningTotalsToJson(EarningTotals instance) =>
    <String, dynamic>{
      'BASE': instance.BASE,
      'DISTANCE': instance.DISTANCE,
      'TIP': instance.TIP,
      'INCENTIVE': instance.INCENTIVE,
      'PENALTY': instance.PENALTY,
    };
