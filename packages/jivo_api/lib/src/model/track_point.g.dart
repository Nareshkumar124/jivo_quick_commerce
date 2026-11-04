// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_point.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackPointCWProxy {
  TrackPoint lat(double lat);

  TrackPoint lng(double lng);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackPoint(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackPoint(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackPoint call({double lat, double lng});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackPoint.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackPoint.copyWith.fieldName(...)`
class _$TrackPointCWProxyImpl implements _$TrackPointCWProxy {
  const _$TrackPointCWProxyImpl(this._value);

  final TrackPoint _value;

  @override
  TrackPoint lat(double lat) => this(lat: lat);

  @override
  TrackPoint lng(double lng) => this(lng: lng);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackPoint(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackPoint(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackPoint call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
  }) {
    return TrackPoint(
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double,
    );
  }
}

extension $TrackPointCopyWith on TrackPoint {
  /// Returns a callable class that can be used as follows: `instanceOfTrackPoint.copyWith(...)` or like so:`instanceOfTrackPoint.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackPointCWProxy get copyWith => _$TrackPointCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackPoint _$TrackPointFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TrackPoint', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lat', 'lng']);
      final val = TrackPoint(
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$TrackPointToJson(TrackPoint instance) =>
    <String, dynamic>{'lat': instance.lat, 'lng': instance.lng};
