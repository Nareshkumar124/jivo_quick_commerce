// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'location_point_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$LocationPointRequestCWProxy {
  LocationPointRequest lat(double lat);

  LocationPointRequest lng(double lng);

  LocationPointRequest accuracy(double accuracy);

  LocationPointRequest speed(double? speed);

  LocationPointRequest heading(double? heading);

  LocationPointRequest recordedAt(DateTime recordedAt);

  LocationPointRequest isMocked(bool? isMocked);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationPointRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationPointRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationPointRequest call({
    double lat,
    double lng,
    double accuracy,
    double? speed,
    double? heading,
    DateTime recordedAt,
    bool? isMocked,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfLocationPointRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfLocationPointRequest.copyWith.fieldName(...)`
class _$LocationPointRequestCWProxyImpl
    implements _$LocationPointRequestCWProxy {
  const _$LocationPointRequestCWProxyImpl(this._value);

  final LocationPointRequest _value;

  @override
  LocationPointRequest lat(double lat) => this(lat: lat);

  @override
  LocationPointRequest lng(double lng) => this(lng: lng);

  @override
  LocationPointRequest accuracy(double accuracy) => this(accuracy: accuracy);

  @override
  LocationPointRequest speed(double? speed) => this(speed: speed);

  @override
  LocationPointRequest heading(double? heading) => this(heading: heading);

  @override
  LocationPointRequest recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  LocationPointRequest isMocked(bool? isMocked) => this(isMocked: isMocked);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `LocationPointRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// LocationPointRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  LocationPointRequest call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? accuracy = const $CopyWithPlaceholder(),
    Object? speed = const $CopyWithPlaceholder(),
    Object? heading = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
    Object? isMocked = const $CopyWithPlaceholder(),
  }) {
    return LocationPointRequest(
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double,
      accuracy: accuracy == const $CopyWithPlaceholder()
          ? _value.accuracy
          // ignore: cast_nullable_to_non_nullable
          : accuracy as double,
      speed: speed == const $CopyWithPlaceholder()
          ? _value.speed
          // ignore: cast_nullable_to_non_nullable
          : speed as double?,
      heading: heading == const $CopyWithPlaceholder()
          ? _value.heading
          // ignore: cast_nullable_to_non_nullable
          : heading as double?,
      recordedAt: recordedAt == const $CopyWithPlaceholder()
          ? _value.recordedAt
          // ignore: cast_nullable_to_non_nullable
          : recordedAt as DateTime,
      isMocked: isMocked == const $CopyWithPlaceholder()
          ? _value.isMocked
          // ignore: cast_nullable_to_non_nullable
          : isMocked as bool?,
    );
  }
}

extension $LocationPointRequestCopyWith on LocationPointRequest {
  /// Returns a callable class that can be used as follows: `instanceOfLocationPointRequest.copyWith(...)` or like so:`instanceOfLocationPointRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$LocationPointRequestCWProxy get copyWith =>
      _$LocationPointRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocationPointRequest _$LocationPointRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('LocationPointRequest', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['lat', 'lng', 'accuracy', 'recorded_at'],
  );
  final val = LocationPointRequest(
    lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
    lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
    accuracy: $checkedConvert('accuracy', (v) => (v as num).toDouble()),
    speed: $checkedConvert('speed', (v) => (v as num?)?.toDouble()),
    heading: $checkedConvert('heading', (v) => (v as num?)?.toDouble()),
    recordedAt: $checkedConvert(
      'recorded_at',
      (v) => DateTime.parse(v as String),
    ),
    isMocked: $checkedConvert('is_mocked', (v) => v as bool? ?? false),
  );
  return val;
}, fieldKeyMap: const {'recordedAt': 'recorded_at', 'isMocked': 'is_mocked'});

Map<String, dynamic> _$LocationPointRequestToJson(
  LocationPointRequest instance,
) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
  'accuracy': instance.accuracy,
  'speed': ?instance.speed,
  'heading': ?instance.heading,
  'recorded_at': instance.recordedAt.toIso8601String(),
  'is_mocked': ?instance.isMocked,
};
