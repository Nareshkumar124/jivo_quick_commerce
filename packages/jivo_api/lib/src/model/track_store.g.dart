// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_store.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackStoreCWProxy {
  TrackStore id(int id);

  TrackStore name(String name);

  TrackStore lat(double lat);

  TrackStore lng(double lng);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackStore(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackStore call({int id, String name, double lat, double lng});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackStore.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackStore.copyWith.fieldName(...)`
class _$TrackStoreCWProxyImpl implements _$TrackStoreCWProxy {
  const _$TrackStoreCWProxyImpl(this._value);

  final TrackStore _value;

  @override
  TrackStore id(int id) => this(id: id);

  @override
  TrackStore name(String name) => this(name: name);

  @override
  TrackStore lat(double lat) => this(lat: lat);

  @override
  TrackStore lng(double lng) => this(lng: lng);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackStore(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackStore call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
  }) {
    return TrackStore(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
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

extension $TrackStoreCopyWith on TrackStore {
  /// Returns a callable class that can be used as follows: `instanceOfTrackStore.copyWith(...)` or like so:`instanceOfTrackStore.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackStoreCWProxy get copyWith => _$TrackStoreCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackStore _$TrackStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TrackStore', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['id', 'name', 'lat', 'lng']);
      final val = TrackStore(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$TrackStoreToJson(TrackStore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'lat': instance.lat,
      'lng': instance.lng,
    };
