// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_rider_location_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsRiderLocationDataCWProxy {
  WsRiderLocationData orderId(int orderId);

  WsRiderLocationData lat(double lat);

  WsRiderLocationData lng(double lng);

  WsRiderLocationData heading(double? heading);

  WsRiderLocationData recordedAt(DateTime recordedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderLocationData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderLocationData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderLocationData call({
    int orderId,
    double lat,
    double lng,
    double? heading,
    DateTime recordedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsRiderLocationData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsRiderLocationData.copyWith.fieldName(...)`
class _$WsRiderLocationDataCWProxyImpl implements _$WsRiderLocationDataCWProxy {
  const _$WsRiderLocationDataCWProxyImpl(this._value);

  final WsRiderLocationData _value;

  @override
  WsRiderLocationData orderId(int orderId) => this(orderId: orderId);

  @override
  WsRiderLocationData lat(double lat) => this(lat: lat);

  @override
  WsRiderLocationData lng(double lng) => this(lng: lng);

  @override
  WsRiderLocationData heading(double? heading) => this(heading: heading);

  @override
  WsRiderLocationData recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsRiderLocationData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsRiderLocationData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsRiderLocationData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? heading = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
  }) {
    return WsRiderLocationData(
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      lat: lat == const $CopyWithPlaceholder()
          ? _value.lat
          // ignore: cast_nullable_to_non_nullable
          : lat as double,
      lng: lng == const $CopyWithPlaceholder()
          ? _value.lng
          // ignore: cast_nullable_to_non_nullable
          : lng as double,
      heading: heading == const $CopyWithPlaceholder()
          ? _value.heading
          // ignore: cast_nullable_to_non_nullable
          : heading as double?,
      recordedAt: recordedAt == const $CopyWithPlaceholder()
          ? _value.recordedAt
          // ignore: cast_nullable_to_non_nullable
          : recordedAt as DateTime,
    );
  }
}

extension $WsRiderLocationDataCopyWith on WsRiderLocationData {
  /// Returns a callable class that can be used as follows: `instanceOfWsRiderLocationData.copyWith(...)` or like so:`instanceOfWsRiderLocationData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsRiderLocationDataCWProxy get copyWith =>
      _$WsRiderLocationDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsRiderLocationData _$WsRiderLocationDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WsRiderLocationData', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const [
          'order_id',
          'lat',
          'lng',
          'heading',
          'recorded_at',
        ],
      );
      final val = WsRiderLocationData(
        orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
        lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
        lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
        heading: $checkedConvert('heading', (v) => (v as num?)?.toDouble()),
        recordedAt: $checkedConvert(
          'recorded_at',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'orderId': 'order_id', 'recordedAt': 'recorded_at'});

Map<String, dynamic> _$WsRiderLocationDataToJson(
  WsRiderLocationData instance,
) => <String, dynamic>{
  'order_id': instance.orderId,
  'lat': instance.lat,
  'lng': instance.lng,
  'heading': instance.heading,
  'recorded_at': instance.recordedAt.toIso8601String(),
};
