// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_today.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderTodayCWProxy {
  RiderToday date(DateTime date);

  RiderToday ordersDelivered(int ordersDelivered);

  RiderToday earnings(String earnings);

  RiderToday cashInHand(String cashInHand);

  RiderToday onlineSeconds(int onlineSeconds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderToday(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderToday(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderToday call({
    DateTime date,
    int ordersDelivered,
    String earnings,
    String cashInHand,
    int onlineSeconds,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderToday.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderToday.copyWith.fieldName(...)`
class _$RiderTodayCWProxyImpl implements _$RiderTodayCWProxy {
  const _$RiderTodayCWProxyImpl(this._value);

  final RiderToday _value;

  @override
  RiderToday date(DateTime date) => this(date: date);

  @override
  RiderToday ordersDelivered(int ordersDelivered) =>
      this(ordersDelivered: ordersDelivered);

  @override
  RiderToday earnings(String earnings) => this(earnings: earnings);

  @override
  RiderToday cashInHand(String cashInHand) => this(cashInHand: cashInHand);

  @override
  RiderToday onlineSeconds(int onlineSeconds) =>
      this(onlineSeconds: onlineSeconds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderToday(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderToday(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderToday call({
    Object? date = const $CopyWithPlaceholder(),
    Object? ordersDelivered = const $CopyWithPlaceholder(),
    Object? earnings = const $CopyWithPlaceholder(),
    Object? cashInHand = const $CopyWithPlaceholder(),
    Object? onlineSeconds = const $CopyWithPlaceholder(),
  }) {
    return RiderToday(
      date: date == const $CopyWithPlaceholder()
          ? _value.date
          // ignore: cast_nullable_to_non_nullable
          : date as DateTime,
      ordersDelivered: ordersDelivered == const $CopyWithPlaceholder()
          ? _value.ordersDelivered
          // ignore: cast_nullable_to_non_nullable
          : ordersDelivered as int,
      earnings: earnings == const $CopyWithPlaceholder()
          ? _value.earnings
          // ignore: cast_nullable_to_non_nullable
          : earnings as String,
      cashInHand: cashInHand == const $CopyWithPlaceholder()
          ? _value.cashInHand
          // ignore: cast_nullable_to_non_nullable
          : cashInHand as String,
      onlineSeconds: onlineSeconds == const $CopyWithPlaceholder()
          ? _value.onlineSeconds
          // ignore: cast_nullable_to_non_nullable
          : onlineSeconds as int,
    );
  }
}

extension $RiderTodayCopyWith on RiderToday {
  /// Returns a callable class that can be used as follows: `instanceOfRiderToday.copyWith(...)` or like so:`instanceOfRiderToday.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderTodayCWProxy get copyWith => _$RiderTodayCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderToday _$RiderTodayFromJson(Map<String, dynamic> json) => $checkedCreate(
  'RiderToday',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'date',
        'orders_delivered',
        'earnings',
        'cash_in_hand',
        'online_seconds',
      ],
    );
    final val = RiderToday(
      date: $checkedConvert('date', (v) => DateTime.parse(v as String)),
      ordersDelivered: $checkedConvert(
        'orders_delivered',
        (v) => (v as num).toInt(),
      ),
      earnings: $checkedConvert('earnings', (v) => v as String),
      cashInHand: $checkedConvert('cash_in_hand', (v) => v as String),
      onlineSeconds: $checkedConvert(
        'online_seconds',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'ordersDelivered': 'orders_delivered',
    'cashInHand': 'cash_in_hand',
    'onlineSeconds': 'online_seconds',
  },
);

Map<String, dynamic> _$RiderTodayToJson(RiderToday instance) =>
    <String, dynamic>{
      'date': jivoDateToJson(instance.date),
      'orders_delivered': instance.ordersDelivered,
      'earnings': instance.earnings,
      'cash_in_hand': instance.cashInHand,
      'online_seconds': instance.onlineSeconds,
    };
