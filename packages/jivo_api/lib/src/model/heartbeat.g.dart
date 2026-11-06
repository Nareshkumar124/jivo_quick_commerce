// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'heartbeat.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HeartbeatCWProxy {
  Heartbeat isOnline(bool isOnline);

  Heartbeat pendingOfferId(int? pendingOfferId);

  Heartbeat activeTaskId(int? activeTaskId);

  Heartbeat shift(RiderShift? shift);

  Heartbeat location(RiderLocationSettings location);

  Heartbeat serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Heartbeat(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Heartbeat(...).copyWith(id: 12, name: "My name")
  /// ````
  Heartbeat call({
    bool isOnline,
    int? pendingOfferId,
    int? activeTaskId,
    RiderShift? shift,
    RiderLocationSettings location,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHeartbeat.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHeartbeat.copyWith.fieldName(...)`
class _$HeartbeatCWProxyImpl implements _$HeartbeatCWProxy {
  const _$HeartbeatCWProxyImpl(this._value);

  final Heartbeat _value;

  @override
  Heartbeat isOnline(bool isOnline) => this(isOnline: isOnline);

  @override
  Heartbeat pendingOfferId(int? pendingOfferId) =>
      this(pendingOfferId: pendingOfferId);

  @override
  Heartbeat activeTaskId(int? activeTaskId) => this(activeTaskId: activeTaskId);

  @override
  Heartbeat shift(RiderShift? shift) => this(shift: shift);

  @override
  Heartbeat location(RiderLocationSettings location) =>
      this(location: location);

  @override
  Heartbeat serverTime(DateTime serverTime) => this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `Heartbeat(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// Heartbeat(...).copyWith(id: 12, name: "My name")
  /// ````
  Heartbeat call({
    Object? isOnline = const $CopyWithPlaceholder(),
    Object? pendingOfferId = const $CopyWithPlaceholder(),
    Object? activeTaskId = const $CopyWithPlaceholder(),
    Object? shift = const $CopyWithPlaceholder(),
    Object? location = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return Heartbeat(
      isOnline: isOnline == const $CopyWithPlaceholder()
          ? _value.isOnline
          // ignore: cast_nullable_to_non_nullable
          : isOnline as bool,
      pendingOfferId: pendingOfferId == const $CopyWithPlaceholder()
          ? _value.pendingOfferId
          // ignore: cast_nullable_to_non_nullable
          : pendingOfferId as int?,
      activeTaskId: activeTaskId == const $CopyWithPlaceholder()
          ? _value.activeTaskId
          // ignore: cast_nullable_to_non_nullable
          : activeTaskId as int?,
      shift: shift == const $CopyWithPlaceholder()
          ? _value.shift
          // ignore: cast_nullable_to_non_nullable
          : shift as RiderShift?,
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

extension $HeartbeatCopyWith on Heartbeat {
  /// Returns a callable class that can be used as follows: `instanceOfHeartbeat.copyWith(...)` or like so:`instanceOfHeartbeat.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HeartbeatCWProxy get copyWith => _$HeartbeatCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Heartbeat _$HeartbeatFromJson(Map<String, dynamic> json) => $checkedCreate(
  'Heartbeat',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'is_online',
        'pending_offer_id',
        'active_task_id',
        'shift',
        'location',
        'server_time',
      ],
    );
    final val = Heartbeat(
      isOnline: $checkedConvert('is_online', (v) => v as bool),
      pendingOfferId: $checkedConvert(
        'pending_offer_id',
        (v) => (v as num?)?.toInt(),
      ),
      activeTaskId: $checkedConvert(
        'active_task_id',
        (v) => (v as num?)?.toInt(),
      ),
      shift: $checkedConvert(
        'shift',
        (v) =>
            v == null ? null : RiderShift.fromJson(v as Map<String, dynamic>),
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
    'pendingOfferId': 'pending_offer_id',
    'activeTaskId': 'active_task_id',
    'serverTime': 'server_time',
  },
);

Map<String, dynamic> _$HeartbeatToJson(Heartbeat instance) => <String, dynamic>{
  'is_online': instance.isOnline,
  'pending_offer_id': instance.pendingOfferId,
  'active_task_id': instance.activeTaskId,
  'shift': instance.shift?.toJson(),
  'location': instance.location.toJson(),
  'server_time': instance.serverTime.toIso8601String(),
};
