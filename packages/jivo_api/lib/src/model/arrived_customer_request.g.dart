// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arrived_customer_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ArrivedCustomerRequestCWProxy {
  ArrivedCustomerRequest lat(double lat);

  ArrivedCustomerRequest lng(double lng);

  ArrivedCustomerRequest accuracy(double? accuracy);

  ArrivedCustomerRequest overrideReason(String? overrideReason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ArrivedCustomerRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ArrivedCustomerRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ArrivedCustomerRequest call({
    double lat,
    double lng,
    double? accuracy,
    String? overrideReason,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfArrivedCustomerRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfArrivedCustomerRequest.copyWith.fieldName(...)`
class _$ArrivedCustomerRequestCWProxyImpl
    implements _$ArrivedCustomerRequestCWProxy {
  const _$ArrivedCustomerRequestCWProxyImpl(this._value);

  final ArrivedCustomerRequest _value;

  @override
  ArrivedCustomerRequest lat(double lat) => this(lat: lat);

  @override
  ArrivedCustomerRequest lng(double lng) => this(lng: lng);

  @override
  ArrivedCustomerRequest accuracy(double? accuracy) => this(accuracy: accuracy);

  @override
  ArrivedCustomerRequest overrideReason(String? overrideReason) =>
      this(overrideReason: overrideReason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ArrivedCustomerRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ArrivedCustomerRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ArrivedCustomerRequest call({
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? accuracy = const $CopyWithPlaceholder(),
    Object? overrideReason = const $CopyWithPlaceholder(),
  }) {
    return ArrivedCustomerRequest(
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
      overrideReason: overrideReason == const $CopyWithPlaceholder()
          ? _value.overrideReason
          // ignore: cast_nullable_to_non_nullable
          : overrideReason as String?,
    );
  }
}

extension $ArrivedCustomerRequestCopyWith on ArrivedCustomerRequest {
  /// Returns a callable class that can be used as follows: `instanceOfArrivedCustomerRequest.copyWith(...)` or like so:`instanceOfArrivedCustomerRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ArrivedCustomerRequestCWProxy get copyWith =>
      _$ArrivedCustomerRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ArrivedCustomerRequest _$ArrivedCustomerRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ArrivedCustomerRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['lat', 'lng']);
  final val = ArrivedCustomerRequest(
    lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
    lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
    accuracy: $checkedConvert('accuracy', (v) => (v as num?)?.toDouble()),
    overrideReason: $checkedConvert('override_reason', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'overrideReason': 'override_reason'});

Map<String, dynamic> _$ArrivedCustomerRequestToJson(
  ArrivedCustomerRequest instance,
) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
  'accuracy': ?instance.accuracy,
  'override_reason': ?instance.overrideReason,
};
