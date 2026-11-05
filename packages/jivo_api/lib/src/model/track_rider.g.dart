// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_rider.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackRiderCWProxy {
  TrackRider name(String name);

  TrackRider phone(String? phone);

  TrackRider photo(String? photo);

  TrackRider lat(double? lat);

  TrackRider lng(double? lng);

  TrackRider updatedAt(DateTime? updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackRider(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackRider(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackRider call({
    String name,
    String? phone,
    String? photo,
    double? lat,
    double? lng,
    DateTime? updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackRider.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackRider.copyWith.fieldName(...)`
class _$TrackRiderCWProxyImpl implements _$TrackRiderCWProxy {
  const _$TrackRiderCWProxyImpl(this._value);

  final TrackRider _value;

  @override
  TrackRider name(String name) => this(name: name);

  @override
  TrackRider phone(String? phone) => this(phone: phone);

  @override
  TrackRider photo(String? photo) => this(photo: photo);

  @override
  TrackRider lat(double? lat) => this(lat: lat);

  @override
  TrackRider lng(double? lng) => this(lng: lng);

  @override
  TrackRider updatedAt(DateTime? updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackRider(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackRider(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackRider call({
    Object? name = const $CopyWithPlaceholder(),
    Object? phone = const $CopyWithPlaceholder(),
    Object? photo = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return TrackRider(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      phone: phone == const $CopyWithPlaceholder()
          ? _value.phone
          // ignore: cast_nullable_to_non_nullable
          : phone as String?,
      photo: photo == const $CopyWithPlaceholder()
          ? _value.photo
          // ignore: cast_nullable_to_non_nullable
          : photo as String?,
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double?,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double?,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime?,
    );
  }
}

extension $TrackRiderCopyWith on TrackRider {
  /// Returns a callable class that can be used as follows: `instanceOfTrackRider.copyWith(...)` or like so:`instanceOfTrackRider.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackRiderCWProxy get copyWith => _$TrackRiderCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackRider _$TrackRiderFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TrackRider', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'name',
          'phone',
          'photo',
          'lat',
          'lng',
          'updated_at',
        ],
      );
      final val = TrackRider(
        name: $checkedConvert('name', (v) => v as String),
        phone: $checkedConvert('phone', (v) => v as String?),
        photo: $checkedConvert('photo', (v) => v as String?),
        lat: $checkedConvert('lat', (v) => (v as num?)?.toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num?)?.toDouble()),
        updatedAt: $checkedConvert(
          'updated_at',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'updatedAt': 'updated_at'});

Map<String, dynamic> _$TrackRiderToJson(TrackRider instance) =>
    <String, dynamic>{
      'name': instance.name,
      'phone': instance.phone,
      'photo': instance.photo,
      'lat': instance.lat,
      'lng': instance.lng,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
