// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_price.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UnitPriceCWProxy {
  UnitPrice amount(String amount);

  UnitPrice per(String per);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UnitPrice(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UnitPrice(...).copyWith(id: 12, name: "My name")
  /// ````
  UnitPrice call({String amount, String per});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUnitPrice.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUnitPrice.copyWith.fieldName(...)`
class _$UnitPriceCWProxyImpl implements _$UnitPriceCWProxy {
  const _$UnitPriceCWProxyImpl(this._value);

  final UnitPrice _value;

  @override
  UnitPrice amount(String amount) => this(amount: amount);

  @override
  UnitPrice per(String per) => this(per: per);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UnitPrice(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UnitPrice(...).copyWith(id: 12, name: "My name")
  /// ````
  UnitPrice call({
    Object? amount = const $CopyWithPlaceholder(),
    Object? per = const $CopyWithPlaceholder(),
  }) {
    return UnitPrice(
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      per: per == const $CopyWithPlaceholder()
          ? _value.per
          // ignore: cast_nullable_to_non_nullable
          : per as String,
    );
  }
}

extension $UnitPriceCopyWith on UnitPrice {
  /// Returns a callable class that can be used as follows: `instanceOfUnitPrice.copyWith(...)` or like so:`instanceOfUnitPrice.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UnitPriceCWProxy get copyWith => _$UnitPriceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnitPrice _$UnitPriceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UnitPrice', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['amount', 'per']);
      final val = UnitPrice(
        amount: $checkedConvert('amount', (v) => v as String),
        per: $checkedConvert('per', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$UnitPriceToJson(UnitPrice instance) => <String, dynamic>{
  'amount': instance.amount,
  'per': instance.per,
};
