// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_home_store.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderHomeStoreCWProxy {
  RiderHomeStore id(int id);

  RiderHomeStore name(String name);

  RiderHomeStore city(String city);

  RiderHomeStore lat(double lat);

  RiderHomeStore lng(double lng);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderHomeStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderHomeStore(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderHomeStore call({
    int id,
    String name,
    String city,
    double lat,
    double lng,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderHomeStore.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderHomeStore.copyWith.fieldName(...)`
class _$RiderHomeStoreCWProxyImpl implements _$RiderHomeStoreCWProxy {
  const _$RiderHomeStoreCWProxyImpl(this._value);

  final RiderHomeStore _value;

  @override
  RiderHomeStore id(int id) => this(id: id);

  @override
  RiderHomeStore name(String name) => this(name: name);

  @override
  RiderHomeStore city(String city) => this(city: city);

  @override
  RiderHomeStore lat(double lat) => this(lat: lat);

  @override
  RiderHomeStore lng(double lng) => this(lng: lng);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderHomeStore(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderHomeStore(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderHomeStore call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? city = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
  }) {
    return RiderHomeStore(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      city: city == const $CopyWithPlaceholder()
          ? _value.city
          // ignore: cast_nullable_to_non_nullable
          : city as String,
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

extension $RiderHomeStoreCopyWith on RiderHomeStore {
  /// Returns a callable class that can be used as follows: `instanceOfRiderHomeStore.copyWith(...)` or like so:`instanceOfRiderHomeStore.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderHomeStoreCWProxy get copyWith => _$RiderHomeStoreCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderHomeStore _$RiderHomeStoreFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RiderHomeStore', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['id', 'name', 'city', 'lat', 'lng'],
      );
      final val = RiderHomeStore(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        name: $checkedConvert('name', (v) => v as String),
        city: $checkedConvert('city', (v) => v as String),
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$RiderHomeStoreToJson(RiderHomeStore instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'city': instance.city,
      'lat': instance.lat,
      'lng': instance.lng,
    };
