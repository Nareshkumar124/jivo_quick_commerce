// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_state.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ShiftStateCWProxy {
  ShiftState isOnline(bool isOnline);

  ShiftState shift(RiderShift? shift);

  ShiftState prepaidOnly(bool prepaidOnly);

  ShiftState cash(RiderCash cash);

  ShiftState location(RiderLocationSettings location);

  ShiftState serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ShiftState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ShiftState(...).copyWith(id: 12, name: "My name")
  /// ````
  ShiftState call({
    bool isOnline,
    RiderShift? shift,
    bool prepaidOnly,
    RiderCash cash,
    RiderLocationSettings location,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfShiftState.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfShiftState.copyWith.fieldName(...)`
class _$ShiftStateCWProxyImpl implements _$ShiftStateCWProxy {
  const _$ShiftStateCWProxyImpl(this._value);

  final ShiftState _value;

  @override
  ShiftState isOnline(bool isOnline) => this(isOnline: isOnline);

  @override
  ShiftState shift(RiderShift? shift) => this(shift: shift);

  @override
  ShiftState prepaidOnly(bool prepaidOnly) => this(prepaidOnly: prepaidOnly);

  @override
  ShiftState cash(RiderCash cash) => this(cash: cash);

  @override
  ShiftState location(RiderLocationSettings location) =>
      this(location: location);

  @override
  ShiftState serverTime(DateTime serverTime) => this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ShiftState(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ShiftState(...).copyWith(id: 12, name: "My name")
  /// ````
  ShiftState call({
    Object? isOnline = const $CopyWithPlaceholder(),
    Object? shift = const $CopyWithPlaceholder(),
    Object? prepaidOnly = const $CopyWithPlaceholder(),
    Object? cash = const $CopyWithPlaceholder(),
    Object? location = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return ShiftState(
      isOnline: isOnline == const $CopyWithPlaceholder()
          ? _value.isOnline
          // ignore: cast_nullable_to_non_nullable
          : isOnline as bool,
      shift: shift == const $CopyWithPlaceholder()
          ? _value.shift
          // ignore: cast_nullable_to_non_nullable
          : shift as RiderShift?,
      prepaidOnly: prepaidOnly == const $CopyWithPlaceholder()
          ? _value.prepaidOnly
          // ignore: cast_nullable_to_non_nullable
          : prepaidOnly as bool,
      cash: cash == const $CopyWithPlaceholder()
          ? _value.cash
          // ignore: cast_nullable_to_non_nullable
          : cash as RiderCash,
      location: location == const $CopyWithPlaceholder()
          ? _value.location
          // ignore: cast_nullable_to_non_nullable
          : location as RiderLocationSettings,
      serverTime: serverTime == const $CopyWithPlaceholder()
          ? _value.serverTime
          // ignore: cast_nullable_to_non_nullable
          : serverTime as DateTime,
    );
  }
}

extension $ShiftStateCopyWith on ShiftState {
  /// Returns a callable class that can be used as follows: `instanceOfShiftState.copyWith(...)` or like so:`instanceOfShiftState.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ShiftStateCWProxy get copyWith => _$ShiftStateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShiftState _$ShiftStateFromJson(Map<String, dynamic> json) => $checkedCreate(
  'ShiftState',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'is_online',
        'shift',
        'prepaid_only',
        'cash',
        'location',
        'server_time',
      ],
    );
    final val = ShiftState(
      isOnline: $checkedConvert('is_online', (v) => v as bool),
      shift: $checkedConvert(
        'shift',
        (v) =>
            v == null ? null : RiderShift.fromJson(v as Map<String, dynamic>),
      ),
      prepaidOnly: $checkedConvert('prepaid_only', (v) => v as bool),
      cash: $checkedConvert(
        'cash',
        (v) => RiderCash.fromJson(v as Map<String, dynamic>),
      ),
      location: $checkedConvert(
        'location',
        (v) => RiderLocationSettings.fromJson(v as Map<String, dynamic>),
      ),
      serverTime: $checkedConvert(
        'server_time',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'isOnline': 'is_online',
    'prepaidOnly': 'prepaid_only',
    'serverTime': 'server_time',
  },
);

Map<String, dynamic> _$ShiftStateToJson(ShiftState instance) =>
    <String, dynamic>{
      'is_online': instance.isOnline,
      'shift': instance.shift?.toJson(),
      'prepaid_only': instance.prepaidOnly,
      'cash': instance.cash.toJson(),
      'location': instance.location.toJson(),
      'server_time': instance.serverTime.toIso8601String(),
    };
