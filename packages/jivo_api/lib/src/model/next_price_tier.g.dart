// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'next_price_tier.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$NextPriceTierCWProxy {
  NextPriceTier minOrderUnits(int minOrderUnits);

  NextPriceTier unitsToNextTier(int unitsToNextTier);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NextPriceTier(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NextPriceTier(...).copyWith(id: 12, name: "My name")
  /// ````
  NextPriceTier call({int minOrderUnits, int unitsToNextTier});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfNextPriceTier.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfNextPriceTier.copyWith.fieldName(...)`
class _$NextPriceTierCWProxyImpl implements _$NextPriceTierCWProxy {
  const _$NextPriceTierCWProxyImpl(this._value);

  final NextPriceTier _value;

  @override
  NextPriceTier minOrderUnits(int minOrderUnits) =>
      this(minOrderUnits: minOrderUnits);

  @override
  NextPriceTier unitsToNextTier(int unitsToNextTier) =>
      this(unitsToNextTier: unitsToNextTier);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `NextPriceTier(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// NextPriceTier(...).copyWith(id: 12, name: "My name")
  /// ````
  NextPriceTier call({
    Object? minOrderUnits = const $CopyWithPlaceholder(),
    Object? unitsToNextTier = const $CopyWithPlaceholder(),
  }) {
    return NextPriceTier(
      minOrderUnits: minOrderUnits == const $CopyWithPlaceholder()
          ? _value.minOrderUnits
          // ignore: cast_nullable_to_non_nullable
          : minOrderUnits as int,
      unitsToNextTier: unitsToNextTier == const $CopyWithPlaceholder()
          ? _value.unitsToNextTier
          // ignore: cast_nullable_to_non_nullable
          : unitsToNextTier as int,
    );
  }
}

extension $NextPriceTierCopyWith on NextPriceTier {
  /// Returns a callable class that can be used as follows: `instanceOfNextPriceTier.copyWith(...)` or like so:`instanceOfNextPriceTier.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$NextPriceTierCWProxy get copyWith => _$NextPriceTierCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NextPriceTier _$NextPriceTierFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'NextPriceTier',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['min_order_units', 'units_to_next_tier'],
        );
        final val = NextPriceTier(
          minOrderUnits: $checkedConvert(
            'min_order_units',
            (v) => (v as num).toInt(),
          ),
          unitsToNextTier: $checkedConvert(
            'units_to_next_tier',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'minOrderUnits': 'min_order_units',
        'unitsToNextTier': 'units_to_next_tier',
      },
    );

Map<String, dynamic> _$NextPriceTierToJson(NextPriceTier instance) =>
    <String, dynamic>{
      'min_order_units': instance.minOrderUnits,
      'units_to_next_tier': instance.unitsToNextTier,
    };
