// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'position_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PositionRequestCWProxy {
  PositionRequest lat(double lat);

  PositionRequest lng(double lng);

  PositionRequest accuracy(double? accuracy);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PositionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PositionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PositionRequest call({double lat, double lng, double? accuracy});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPositionRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPositionRequest.copyWith.fieldName(...)`
class _$PositionRequestCWProxyImpl implements _$PositionRequestCWProxy {
  const _$PositionRequestCWProxyImpl(this._value);

  final PositionRequest _value;

  @override
  PositionRequest lat(double lat) => this(lat: lat);

  @override
  PositionRequest lng(double lng) => this(lng: lng);

  @override
  PositionRequest accuracy(double? accuracy) => this(accuracy: accuracy);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PositionRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PositionRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  PositionRequest call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? accuracy = const $CopyWithPlaceholder(),
  }) {
    return PositionRequest(
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

extension $PositionRequestCopyWith on PositionRequest {
  /// Returns a callable class that can be used as follows: `instanceOfPositionRequest.copyWith(...)` or like so:`instanceOfPositionRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PositionRequestCWProxy get copyWith => _$PositionRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PositionRequest _$PositionRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PositionRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lat', 'lng']);
      final val = PositionRequest(
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
        accuracy: $checkedConvert('accuracy', (v) => (v as num?)?.toDouble()),
      );
      return val;
    });

Map<String, dynamic> _$PositionRequestToJson(PositionRequest instance) =>
    <String, dynamic>{
      'lat': instance.lat,
      'lng': instance.lng,
      'accuracy': ?instance.accuracy,
    };
