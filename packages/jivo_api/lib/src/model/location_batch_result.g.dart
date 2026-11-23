// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_batch_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LocationBatchResultCWProxy {
  LocationBatchResult accepted(int accepted);

  LocationBatchResult duplicates(int duplicates);

  LocationBatchResult rejected(int rejected);

  LocationBatchResult rejectedReasons(LocationRejectReasons rejectedReasons);

  LocationBatchResult outOfOrder(int outOfOrder);

  LocationBatchResult lowAccuracy(int lowAccuracy);

  LocationBatchResult activeTaskId(int? activeTaskId);

  LocationBatchResult location(RiderLocationSettings location);

  LocationBatchResult serverTime(DateTime serverTime);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationBatchResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationBatchResult(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationBatchResult call({
    int accepted,
    int duplicates,
    int rejected,
    LocationRejectReasons rejectedReasons,
    int outOfOrder,
    int lowAccuracy,
    int? activeTaskId,
    RiderLocationSettings location,
    DateTime serverTime,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLocationBatchResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLocationBatchResult.copyWith.fieldName(...)`
class _$LocationBatchResultCWProxyImpl implements _$LocationBatchResultCWProxy {
  const _$LocationBatchResultCWProxyImpl(this._value);

  final LocationBatchResult _value;

  @override
  LocationBatchResult accepted(int accepted) => this(accepted: accepted);

  @override
  LocationBatchResult duplicates(int duplicates) =>
      this(duplicates: duplicates);

  @override
  LocationBatchResult rejected(int rejected) => this(rejected: rejected);

  @override
  LocationBatchResult rejectedReasons(LocationRejectReasons rejectedReasons) =>
      this(rejectedReasons: rejectedReasons);

  @override
  LocationBatchResult outOfOrder(int outOfOrder) =>
      this(outOfOrder: outOfOrder);

  @override
  LocationBatchResult lowAccuracy(int lowAccuracy) =>
      this(lowAccuracy: lowAccuracy);

  @override
  LocationBatchResult activeTaskId(int? activeTaskId) =>
      this(activeTaskId: activeTaskId);

  @override
  LocationBatchResult location(RiderLocationSettings location) =>
      this(location: location);

  @override
  LocationBatchResult serverTime(DateTime serverTime) =>
      this(serverTime: serverTime);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationBatchResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationBatchResult(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationBatchResult call({
    Object? accepted = const $CopyWithPlaceholder(),
    Object? duplicates = const $CopyWithPlaceholder(),
    Object? rejected = const $CopyWithPlaceholder(),
    Object? rejectedReasons = const $CopyWithPlaceholder(),
    Object? outOfOrder = const $CopyWithPlaceholder(),
    Object? lowAccuracy = const $CopyWithPlaceholder(),
    Object? activeTaskId = const $CopyWithPlaceholder(),
    Object? location = const $CopyWithPlaceholder(),
    Object? serverTime = const $CopyWithPlaceholder(),
  }) {
    return LocationBatchResult(
      accepted: accepted == const $CopyWithPlaceholder()
          ? _value.accepted
          // ignore: cast_nullable_to_non_nullable
          : accepted as int,
      duplicates: duplicates == const $CopyWithPlaceholder()
          ? _value.duplicates
          // ignore: cast_nullable_to_non_nullable
          : duplicates as int,
      rejected: rejected == const $CopyWithPlaceholder()
          ? _value.rejected
          // ignore: cast_nullable_to_non_nullable
          : rejected as int,
      rejectedReasons: rejectedReasons == const $CopyWithPlaceholder()
          ? _value.rejectedReasons
          // ignore: cast_nullable_to_non_nullable
          : rejectedReasons as LocationRejectReasons,
      outOfOrder: outOfOrder == const $CopyWithPlaceholder()
          ? _value.outOfOrder
          // ignore: cast_nullable_to_non_nullable
          : outOfOrder as int,
      lowAccuracy: lowAccuracy == const $CopyWithPlaceholder()
          ? _value.lowAccuracy
          // ignore: cast_nullable_to_non_nullable
          : lowAccuracy as int,
      activeTaskId: activeTaskId == const $CopyWithPlaceholder()
          ? _value.activeTaskId
          // ignore: cast_nullable_to_non_nullable
          : activeTaskId as int?,
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

extension $LocationBatchResultCopyWith on LocationBatchResult {
  /// Returns a callable class that can be used as follows: `instanceOfLocationBatchResult.copyWith(...)` or like so:`instanceOfLocationBatchResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LocationBatchResultCWProxy get copyWith =>
      _$LocationBatchResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationBatchResult _$LocationBatchResultFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'LocationBatchResult',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'accepted',
        'duplicates',
        'rejected',
        'rejected_reasons',
        'out_of_order',
        'low_accuracy',
        'active_task_id',
        'location',
        'server_time',
      ],
    );
    final val = LocationBatchResult(
      accepted: $checkedConvert('accepted', (v) => (v as num).toInt()),
      duplicates: $checkedConvert('duplicates', (v) => (v as num).toInt()),
      rejected: $checkedConvert('rejected', (v) => (v as num).toInt()),
      rejectedReasons: $checkedConvert(
        'rejected_reasons',
        (v) => LocationRejectReasons.fromJson(v as Map<String, dynamic>),
      ),
      outOfOrder: $checkedConvert('out_of_order', (v) => (v as num).toInt()),
      lowAccuracy: $checkedConvert('low_accuracy', (v) => (v as num).toInt()),
      activeTaskId: $checkedConvert(
        'active_task_id',
        (v) => (v as num?)?.toInt(),
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
    'rejectedReasons': 'rejected_reasons',
    'outOfOrder': 'out_of_order',
    'lowAccuracy': 'low_accuracy',
    'activeTaskId': 'active_task_id',
    'serverTime': 'server_time',
  },
);

Map<String, dynamic> _$LocationBatchResultToJson(
  LocationBatchResult instance,
) => <String, dynamic>{
  'accepted': instance.accepted,
  'duplicates': instance.duplicates,
  'rejected': instance.rejected,
  'rejected_reasons': instance.rejectedReasons.toJson(),
  'out_of_order': instance.outOfOrder,
  'low_accuracy': instance.lowAccuracy,
  'active_task_id': instance.activeTaskId,
  'location': instance.location.toJson(),
  'server_time': instance.serverTime.toIso8601String(),
};
