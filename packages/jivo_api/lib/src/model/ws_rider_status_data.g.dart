// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_rider_status_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsRiderStatusDataCWProxy {
  WsRiderStatusData riderId(int riderId);

  WsRiderStatusData storeId(int storeId);

  WsRiderStatusData isOnline(bool isOnline);

  WsRiderStatusData onTask(bool onTask);

  WsRiderStatusData updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderStatusData call({
    int riderId,
    int storeId,
    bool isOnline,
    bool onTask,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsRiderStatusData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsRiderStatusData.copyWith.fieldName(...)`
class _$WsRiderStatusDataCWProxyImpl implements _$WsRiderStatusDataCWProxy {
  const _$WsRiderStatusDataCWProxyImpl(this._value);

  final WsRiderStatusData _value;

  @override
  WsRiderStatusData riderId(int riderId) => this(riderId: riderId);

  @override
  WsRiderStatusData storeId(int storeId) => this(storeId: storeId);

  @override
  WsRiderStatusData isOnline(bool isOnline) => this(isOnline: isOnline);

  @override
  WsRiderStatusData onTask(bool onTask) => this(onTask: onTask);

  @override
  WsRiderStatusData updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderStatusData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderStatusData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderStatusData call({
    Object? riderId = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? isOnline = const $CopyWithPlaceholder(),
    Object? onTask = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WsRiderStatusData(
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int,
      storeId: storeId == const $CopyWithPlaceholder()
          ? _value.storeId
          // ignore: cast_nullable_to_non_nullable
          : storeId as int,
      isOnline: isOnline == const $CopyWithPlaceholder()
          ? _value.isOnline
          // ignore: cast_nullable_to_non_nullable
          : isOnline as bool,
      onTask: onTask == const $CopyWithPlaceholder()
          ? _value.onTask
          // ignore: cast_nullable_to_non_nullable
          : onTask as bool,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $WsRiderStatusDataCopyWith on WsRiderStatusData {
  /// Returns a callable class that can be used as follows: `instanceOfWsRiderStatusData.copyWith(...)` or like so:`instanceOfWsRiderStatusData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsRiderStatusDataCWProxy get copyWith =>
      _$WsRiderStatusDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsRiderStatusData _$WsRiderStatusDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsRiderStatusData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'rider_id',
            'store_id',
            'is_online',
            'on_task',
            'updated_at',
          ],
        );
        final val = WsRiderStatusData(
          riderId: $checkedConvert('rider_id', (v) => (v as num).toInt()),
          storeId: $checkedConvert('store_id', (v) => (v as num).toInt()),
          isOnline: $checkedConvert('is_online', (v) => v as bool),
          onTask: $checkedConvert('on_task', (v) => v as bool),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'riderId': 'rider_id',
        'storeId': 'store_id',
        'isOnline': 'is_online',
        'onTask': 'on_task',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$WsRiderStatusDataToJson(WsRiderStatusData instance) =>
    <String, dynamic>{
      'rider_id': instance.riderId,
      'store_id': instance.storeId,
      'is_online': instance.isOnline,
      'on_task': instance.onTask,
      'updated_at': instance.updatedAt.toIso8601String(),
    };
