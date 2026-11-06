// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_ops_rider_location_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOpsRiderLocationDataCWProxy {
  WsOpsRiderLocationData riderId(int riderId);

  WsOpsRiderLocationData storeId(int storeId);

  WsOpsRiderLocationData orderId(int? orderId);

  WsOpsRiderLocationData lat(double lat);

  WsOpsRiderLocationData lng(double lng);

  WsOpsRiderLocationData heading(double? heading);

  WsOpsRiderLocationData recordedAt(DateTime recordedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsRiderLocationData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsRiderLocationData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsRiderLocationData call({
    int riderId,
    int storeId,
    int? orderId,
    double lat,
    double lng,
    double? heading,
    DateTime recordedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOpsRiderLocationData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOpsRiderLocationData.copyWith.fieldName(...)`
class _$WsOpsRiderLocationDataCWProxyImpl
    implements _$WsOpsRiderLocationDataCWProxy {
  const _$WsOpsRiderLocationDataCWProxyImpl(this._value);

  final WsOpsRiderLocationData _value;

  @override
  WsOpsRiderLocationData riderId(int riderId) => this(riderId: riderId);

  @override
  WsOpsRiderLocationData storeId(int storeId) => this(storeId: storeId);

  @override
  WsOpsRiderLocationData orderId(int? orderId) => this(orderId: orderId);

  @override
  WsOpsRiderLocationData lat(double lat) => this(lat: lat);

  @override
  WsOpsRiderLocationData lng(double lng) => this(lng: lng);

  @override
  WsOpsRiderLocationData heading(double? heading) => this(heading: heading);

  @override
  WsOpsRiderLocationData recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOpsRiderLocationData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOpsRiderLocationData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOpsRiderLocationData call({
    Object? riderId = const $CopyWithPlaceholder(),
    Object? storeId = const $CopyWithPlaceholder(),
    Object? orderId = const $CopyWithPlaceholder(),
    Object? lat = const $CopyWithPlaceholder(),
    Object? lng = const $CopyWithPlaceholder(),
    Object? heading = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
  }) {
    return WsOpsRiderLocationData(
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int,
      storeId: storeId == const $CopyWithPlaceholder()
          ? _value.storeId
          // ignore: cast_nullable_to_non_nullable
          : storeId as int,
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int?,
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

extension $WsOpsRiderLocationDataCopyWith on WsOpsRiderLocationData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOpsRiderLocationData.copyWith(...)` or like so:`instanceOfWsOpsRiderLocationData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOpsRiderLocationDataCWProxy get copyWith =>
      _$WsOpsRiderLocationDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOpsRiderLocationData _$WsOpsRiderLocationDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WsOpsRiderLocationData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'rider_id',
        'store_id',
        'order_id',
        'lat',
        'lng',
        'heading',
        'recorded_at',
      ],
    );
    final val = WsOpsRiderLocationData(
      riderId: $checkedConvert('rider_id', (v) => (v as num).toInt()),
      storeId: $checkedConvert('store_id', (v) => (v as num).toInt()),
      orderId: $checkedConvert('order_id', (v) => (v as num?)?.toInt()),
      lat: $checkedConvert('lat', (v) => (v as num).toDouble()),
      lng: $checkedConvert('lng', (v) => (v as num).toDouble()),
      heading: $checkedConvert('heading', (v) => (v as num?)?.toDouble()),
      recordedAt: $checkedConvert(
        'recorded_at',
        (v) => DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'riderId': 'rider_id',
    'storeId': 'store_id',
    'orderId': 'order_id',
    'recordedAt': 'recorded_at',
  },
);

Map<String, dynamic> _$WsOpsRiderLocationDataToJson(
  WsOpsRiderLocationData instance,
) => <String, dynamic>{
  'rider_id': instance.riderId,
  'store_id': instance.storeId,
  'order_id': instance.orderId,
  'lat': instance.lat,
  'lng': instance.lng,
  'heading': instance.heading,
  'recorded_at': instance.recordedAt.toIso8601String(),
};
