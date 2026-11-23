// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_batch_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LocationBatchRequestCWProxy {
  LocationBatchRequest points(List<LocationPointRequest> points);

  LocationBatchRequest taskId(int? taskId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationBatchRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationBatchRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationBatchRequest call({List<LocationPointRequest> points, int? taskId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLocationBatchRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLocationBatchRequest.copyWith.fieldName(...)`
class _$LocationBatchRequestCWProxyImpl
    implements _$LocationBatchRequestCWProxy {
  const _$LocationBatchRequestCWProxyImpl(this._value);

  final LocationBatchRequest _value;

  @override
  LocationBatchRequest points(List<LocationPointRequest> points) =>
      this(points: points);

  @override
  LocationBatchRequest taskId(int? taskId) => this(taskId: taskId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationBatchRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationBatchRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationBatchRequest call({
    Object? points = const $CopyWithPlaceholder(),
    Object? taskId = const $CopyWithPlaceholder(),
  }) {
    return LocationBatchRequest(
      points: points == const $CopyWithPlaceholder()
          ? _value.points
          // ignore: cast_nullable_to_non_nullable
          : points as List<LocationPointRequest>,
      taskId: taskId == const $CopyWithPlaceholder()
          ? _value.taskId
          // ignore: cast_nullable_to_non_nullable
          : taskId as int?,
    );
  }
}

extension $LocationBatchRequestCopyWith on LocationBatchRequest {
  /// Returns a callable class that can be used as follows: `instanceOfLocationBatchRequest.copyWith(...)` or like so:`instanceOfLocationBatchRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LocationBatchRequestCWProxy get copyWith =>
      _$LocationBatchRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationBatchRequest _$LocationBatchRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LocationBatchRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['points']);
  final val = LocationBatchRequest(
    points: $checkedConvert(
      'points',
      (v) => (v as List<dynamic>)
          .map((e) => LocationPointRequest.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
    taskId: $checkedConvert('task_id', (v) => (v as num?)?.toInt()),
  );
  return val;
}, fieldKeyMap: const {'taskId': 'task_id'});

Map<String, dynamic> _$LocationBatchRequestToJson(
  LocationBatchRequest instance,
) => <String, dynamic>{
  'points': instance.points.map((e) => e.toJson()).toList(),
  'task_id': ?instance.taskId,
};
