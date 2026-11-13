// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'price_tier.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PriceTierCWProxy {
  PriceTier minOrderUnits(int minOrderUnits);

  PriceTier price(String price);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PriceTier(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PriceTier(...).copyWith(id: 12, name: "My name")
  /// ````
  PriceTier call({int minOrderUnits, String price});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPriceTier.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPriceTier.copyWith.fieldName(...)`
class _$PriceTierCWProxyImpl implements _$PriceTierCWProxy {
  const _$PriceTierCWProxyImpl(this._value);

  final PriceTier _value;

  @override
  PriceTier minOrderUnits(int minOrderUnits) =>
      this(minOrderUnits: minOrderUnits);

  @override
  PriceTier price(String price) => this(price: price);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PriceTier(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PriceTier(...).copyWith(id: 12, name: "My name")
  /// ````
  PriceTier call({
    Object? minOrderUnits = const $CopyWithPlaceholder(),
    Object? price = const $CopyWithPlaceholder(),
  }) {
    return PriceTier(
      minOrderUnits: minOrderUnits == const $CopyWithPlaceholder()
          ? _value.minOrderUnits
          // ignore: cast_nullable_to_non_nullable
          : minOrderUnits as int,
      price: price == const $CopyWithPlaceholder()
          ? _value.price
          // ignore: cast_nullable_to_non_nullable
          : price as String,
    );
  }
}

extension $PriceTierCopyWith on PriceTier {
  /// Returns a callable class that can be used as follows: `instanceOfPriceTier.copyWith(...)` or like so:`instanceOfPriceTier.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PriceTierCWProxy get copyWith => _$PriceTierCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PriceTier _$PriceTierFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PriceTier', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['min_order_units', 'price']);
      final val = PriceTier(
        minOrderUnits: $checkedConvert(
          'min_order_units',
          (v) => (v as num).toInt(),
        ),
        price: $checkedConvert('price', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'minOrderUnits': 'min_order_units'});

Map<String, dynamic> _$PriceTierToJson(PriceTier instance) => <String, dynamic>{
  'min_order_units': instance.minOrderUnits,
  'price': instance.price,
};
