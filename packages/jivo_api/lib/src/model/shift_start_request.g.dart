// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_start_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ShiftStartRequestCWProxy {
  ShiftStartRequest lat(double lat);

  ShiftStartRequest lng(double lng);

  ShiftStartRequest accuracy(double? accuracy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ShiftStartRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ShiftStartRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ShiftStartRequest call({double lat, double lng, double? accuracy});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfShiftStartRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfShiftStartRequest.copyWith.fieldName(...)`
class _$ShiftStartRequestCWProxyImpl implements _$ShiftStartRequestCWProxy {
  const _$ShiftStartRequestCWProxyImpl(this._value);

  final ShiftStartRequest _value;

  @override
  ShiftStartRequest lat(double lat) => this(lat: lat);

  @override
  ShiftStartRequest lng(double lng) => this(lng: lng);

  @override
  ShiftStartRequest accuracy(double? accuracy) => this(accuracy: accuracy);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ShiftStartRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ShiftStartRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ShiftStartRequest call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? accuracy = const $CopyWithPlaceholder(),
  }) {
    return ShiftStartRequest(
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
          : accuracy as double?,
    );
  }
}

extension $ShiftStartRequestCopyWith on ShiftStartRequest {
  /// Returns a callable class that can be used as follows: `instanceOfShiftStartRequest.copyWith(...)` or like so:`instanceOfShiftStartRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ShiftStartRequestCWProxy get copyWith =>
      _$ShiftStartRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShiftStartRequest _$ShiftStartRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ShiftStartRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lat', 'lng']);
      final val = ShiftStartRequest(
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
        accuracy: $checkedConvert('accuracy', (v) => (v as num?)?.toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$ShiftStartRequestToJson(ShiftStartRequest instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'accuracy': ?instance.accuracy,
    };
