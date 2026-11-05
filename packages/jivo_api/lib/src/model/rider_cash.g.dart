// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_cash.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderCashCWProxy {
  RiderCash cashInHand(String cashInHand);

  RiderCash cashLimit(String cashLimit);

  RiderCash limitReached(bool limitReached);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderCash(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderCash(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderCash call({String cashInHand, String cashLimit, bool limitReached});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderCash.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderCash.copyWith.fieldName(...)`
class _$RiderCashCWProxyImpl implements _$RiderCashCWProxy {
  const _$RiderCashCWProxyImpl(this._value);

  final RiderCash _value;

  @override
  RiderCash cashInHand(String cashInHand) => this(cashInHand: cashInHand);

  @override
  RiderCash cashLimit(String cashLimit) => this(cashLimit: cashLimit);

  @override
  RiderCash limitReached(bool limitReached) => this(limitReached: limitReached);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderCash(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderCash(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderCash call({
    Object? cashInHand = const $CopyWithPlaceholder(),
    Object? cashLimit = const $CopyWithPlaceholder(),
    Object? limitReached = const $CopyWithPlaceholder(),
  }) {
    return RiderCash(
      cashInHand: cashInHand == const $CopyWithPlaceholder()
          ? _value.cashInHand
          // ignore: cast_nullable_to_non_nullable
          : cashInHand as String,
      cashLimit: cashLimit == const $CopyWithPlaceholder()
          ? _value.cashLimit
          // ignore: cast_nullable_to_non_nullable
          : cashLimit as String,
      limitReached: limitReached == const $CopyWithPlaceholder()
          ? _value.limitReached
          // ignore: cast_nullable_to_non_nullable
          : limitReached as bool,
    );
  }
}

extension $RiderCashCopyWith on RiderCash {
  /// Returns a callable class that can be used as follows: `instanceOfRiderCash.copyWith(...)` or like so:`instanceOfRiderCash.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderCashCWProxy get copyWith => _$RiderCashCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderCash _$RiderCashFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RiderCash',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['cash_in_hand', 'cash_limit', 'limit_reached'],
    );
    final val = RiderCash(
      cashInHand: $checkedConvert('cash_in_hand', (v) => v as String),
      cashLimit: $checkedConvert('cash_limit', (v) => v as String),
      limitReached: $checkedConvert('limit_reached', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'cashInHand': 'cash_in_hand',
    'cashLimit': 'cash_limit',
    'limitReached': 'limit_reached',
  },
);

Map<String, dynamic> _$RiderCashToJson(RiderCash instance) => <String, dynamic>{
  'cash_in_hand': instance.cashInHand,
  'cash_limit': instance.cashLimit,
  'limit_reached': instance.limitReached,
};
