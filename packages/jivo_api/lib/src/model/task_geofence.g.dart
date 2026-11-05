// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_geofence.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskGeofenceCWProxy {
  TaskGeofence storeRadiusM(int storeRadiusM);

  TaskGeofence customerRadiusM(int customerRadiusM);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskGeofence(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskGeofence(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskGeofence call({int storeRadiusM, int customerRadiusM});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskGeofence.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskGeofence.copyWith.fieldName(...)`
class _$TaskGeofenceCWProxyImpl implements _$TaskGeofenceCWProxy {
  const _$TaskGeofenceCWProxyImpl(this._value);

  final TaskGeofence _value;

  @override
  TaskGeofence storeRadiusM(int storeRadiusM) =>
      this(storeRadiusM: storeRadiusM);

  @override
  TaskGeofence customerRadiusM(int customerRadiusM) =>
      this(customerRadiusM: customerRadiusM);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskGeofence(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskGeofence(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskGeofence call({
    Object? storeRadiusM = const $CopyWithPlaceholder(),
    Object? customerRadiusM = const $CopyWithPlaceholder(),
  }) {
    return TaskGeofence(
      storeRadiusM: storeRadiusM == const $CopyWithPlaceholder()
          ? _value.storeRadiusM
          // ignore: cast_nullable_to_non_nullable
          : storeRadiusM as int,
      customerRadiusM: customerRadiusM == const $CopyWithPlaceholder()
          ? _value.customerRadiusM
          // ignore: cast_nullable_to_non_nullable
          : customerRadiusM as int,
    );
  }
}

extension $TaskGeofenceCopyWith on TaskGeofence {
  /// Returns a callable class that can be used as follows: `instanceOfTaskGeofence.copyWith(...)` or like so:`instanceOfTaskGeofence.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskGeofenceCWProxy get copyWith => _$TaskGeofenceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskGeofence _$TaskGeofenceFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'TaskGeofence',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const ['store_radius_m', 'customer_radius_m'],
        );
        final val = TaskGeofence(
          storeRadiusM: $checkedConvert(
            'store_radius_m',
            (v) => (v as num).toInt(),
          ),
          customerRadiusM: $checkedConvert(
            'customer_radius_m',
            (v) => (v as num).toInt(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'storeRadiusM': 'store_radius_m',
        'customerRadiusM': 'customer_radius_m',
      },
    );

Map<String, dynamic> _$TaskGeofenceToJson(TaskGeofence instance) =>
    <String, dynamic>{
      'store_radius_m': instance.storeRadiusM,
      'customer_radius_m': instance.customerRadiusM,
    };
