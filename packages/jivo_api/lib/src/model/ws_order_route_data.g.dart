// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_order_route_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsOrderRouteDataCWProxy {
  WsOrderRouteData orderId(int orderId);

  WsOrderRouteData leg(WsOrderRouteDataLegEnum leg);

  WsOrderRouteData polyline(String polyline);

  WsOrderRouteData distanceM(int distanceM);

  WsOrderRouteData durationS(int durationS);

  WsOrderRouteData provider(WsOrderRouteDataProviderEnum provider);

  WsOrderRouteData trafficAware(bool trafficAware);

  WsOrderRouteData computedAt(DateTime computedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderRouteData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderRouteData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderRouteData call({
    int orderId,
    WsOrderRouteDataLegEnum leg,
    String polyline,
    int distanceM,
    int durationS,
    WsOrderRouteDataProviderEnum provider,
    bool trafficAware,
    DateTime computedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsOrderRouteData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsOrderRouteData.copyWith.fieldName(...)`
class _$WsOrderRouteDataCWProxyImpl implements _$WsOrderRouteDataCWProxy {
  const _$WsOrderRouteDataCWProxyImpl(this._value);

  final WsOrderRouteData _value;

  @override
  WsOrderRouteData orderId(int orderId) => this(orderId: orderId);

  @override
  WsOrderRouteData leg(WsOrderRouteDataLegEnum leg) => this(leg: leg);

  @override
  WsOrderRouteData polyline(String polyline) => this(polyline: polyline);

  @override
  WsOrderRouteData distanceM(int distanceM) => this(distanceM: distanceM);

  @override
  WsOrderRouteData durationS(int durationS) => this(durationS: durationS);

  @override
  WsOrderRouteData provider(WsOrderRouteDataProviderEnum provider) =>
      this(provider: provider);

  @override
  WsOrderRouteData trafficAware(bool trafficAware) =>
      this(trafficAware: trafficAware);

  @override
  WsOrderRouteData computedAt(DateTime computedAt) =>
      this(computedAt: computedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsOrderRouteData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsOrderRouteData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsOrderRouteData call({
    Object? orderId = const $CopyWithPlaceholder(),
    Object? leg = const $CopyWithPlaceholder(),
    Object? polyline = const $CopyWithPlaceholder(),
    Object? distanceM = const $CopyWithPlaceholder(),
    Object? durationS = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? trafficAware = const $CopyWithPlaceholder(),
    Object? computedAt = const $CopyWithPlaceholder(),
  }) {
    return WsOrderRouteData(
      orderId: orderId == const $CopyWithPlaceholder()
          ? _value.orderId
          // ignore: cast_nullable_to_non_nullable
          : orderId as int,
      leg: leg == const $CopyWithPlaceholder()
          ? _value.leg
          // ignore: cast_nullable_to_non_nullable
          : leg as WsOrderRouteDataLegEnum,
      polyline: polyline == const $CopyWithPlaceholder()
          ? _value.polyline
          // ignore: cast_nullable_to_non_nullable
          : polyline as String,
      distanceM: distanceM == const $CopyWithPlaceholder()
          ? _value.distanceM
          // ignore: cast_nullable_to_non_nullable
          : distanceM as int,
      durationS: durationS == const $CopyWithPlaceholder()
          ? _value.durationS
          // ignore: cast_nullable_to_non_nullable
          : durationS as int,
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as WsOrderRouteDataProviderEnum,
      trafficAware: trafficAware == const $CopyWithPlaceholder()
          ? _value.trafficAware
          // ignore: cast_nullable_to_non_nullable
          : trafficAware as bool,
      computedAt: computedAt == const $CopyWithPlaceholder()
          ? _value.computedAt
          // ignore: cast_nullable_to_non_nullable
          : computedAt as DateTime,
    );
  }
}

extension $WsOrderRouteDataCopyWith on WsOrderRouteData {
  /// Returns a callable class that can be used as follows: `instanceOfWsOrderRouteData.copyWith(...)` or like so:`instanceOfWsOrderRouteData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsOrderRouteDataCWProxy get copyWith => _$WsOrderRouteDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsOrderRouteData _$WsOrderRouteDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsOrderRouteData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'order_id',
            'leg',
            'polyline',
            'distance_m',
            'duration_s',
            'provider',
            'traffic_aware',
            'computed_at',
          ],
        );
        final val = WsOrderRouteData(
          orderId: $checkedConvert('order_id', (v) => (v as num).toInt()),
          leg: $checkedConvert(
            'leg',
            (v) => $enumDecode(
              _$WsOrderRouteDataLegEnumEnumMap,
              v,
              unknownValue: WsOrderRouteDataLegEnum.unknownDefaultOpenApi,
            ),
          ),
          polyline: $checkedConvert('polyline', (v) => v as String),
          distanceM: $checkedConvert('distance_m', (v) => (v as num).toInt()),
          durationS: $checkedConvert('duration_s', (v) => (v as num).toInt()),
          provider: $checkedConvert(
            'provider',
            (v) => $enumDecode(
              _$WsOrderRouteDataProviderEnumEnumMap,
              v,
              unknownValue: WsOrderRouteDataProviderEnum.unknownDefaultOpenApi,
            ),
          ),
          trafficAware: $checkedConvert('traffic_aware', (v) => v as bool),
          computedAt: $checkedConvert(
            'computed_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'orderId': 'order_id',
        'distanceM': 'distance_m',
        'durationS': 'duration_s',
        'trafficAware': 'traffic_aware',
        'computedAt': 'computed_at',
      },
    );

Map<String, dynamic> _$WsOrderRouteDataToJson(WsOrderRouteData instance) =>
    <String, dynamic>{
      'order_id': instance.orderId,
      'leg': _$WsOrderRouteDataLegEnumEnumMap[instance.leg]!,
      'polyline': instance.polyline,
      'distance_m': instance.distanceM,
      'duration_s': instance.durationS,
      'provider': _$WsOrderRouteDataProviderEnumEnumMap[instance.provider]!,
      'traffic_aware': instance.trafficAware,
      'computed_at': instance.computedAt.toIso8601String(),
    };

const _$WsOrderRouteDataLegEnumEnumMap = {
  WsOrderRouteDataLegEnum.TO_STORE: 'TO_STORE',
  WsOrderRouteDataLegEnum.TO_CUSTOMER: 'TO_CUSTOMER',
  WsOrderRouteDataLegEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$WsOrderRouteDataProviderEnumEnumMap = {
  WsOrderRouteDataProviderEnum.google: 'google',
  WsOrderRouteDataProviderEnum.haversine: 'haversine',
  WsOrderRouteDataProviderEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
