// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_route.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackRouteCWProxy {
  TrackRoute leg(RouteLegEnum leg);

  TrackRoute polyline(String polyline);

  TrackRoute distanceM(int distanceM);

  TrackRoute durationS(int durationS);

  TrackRoute provider(RouteProviderEnum provider);

  TrackRoute trafficAware(bool trafficAware);

  TrackRoute computedAt(DateTime computedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackRoute(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackRoute(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackRoute call({
    RouteLegEnum leg,
    String polyline,
    int distanceM,
    int durationS,
    RouteProviderEnum provider,
    bool trafficAware,
    DateTime computedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackRoute.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackRoute.copyWith.fieldName(...)`
class _$TrackRouteCWProxyImpl implements _$TrackRouteCWProxy {
  const _$TrackRouteCWProxyImpl(this._value);

  final TrackRoute _value;

  @override
  TrackRoute leg(RouteLegEnum leg) => this(leg: leg);

  @override
  TrackRoute polyline(String polyline) => this(polyline: polyline);

  @override
  TrackRoute distanceM(int distanceM) => this(distanceM: distanceM);

  @override
  TrackRoute durationS(int durationS) => this(durationS: durationS);

  @override
  TrackRoute provider(RouteProviderEnum provider) => this(provider: provider);

  @override
  TrackRoute trafficAware(bool trafficAware) =>
      this(trafficAware: trafficAware);

  @override
  TrackRoute computedAt(DateTime computedAt) => this(computedAt: computedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackRoute(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackRoute(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackRoute call({
    Object? leg = const $CopyWithPlaceholder(),
    Object? polyline = const $CopyWithPlaceholder(),
    Object? distanceM = const $CopyWithPlaceholder(),
    Object? durationS = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? trafficAware = const $CopyWithPlaceholder(),
    Object? computedAt = const $CopyWithPlaceholder(),
  }) {
    return TrackRoute(
      leg: leg == const $CopyWithPlaceholder()
          ? _value.leg
          // ignore: cast_nullable_to_non_nullable
          : leg as RouteLegEnum,
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
          : provider as RouteProviderEnum,
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

extension $TrackRouteCopyWith on TrackRoute {
  /// Returns a callable class that can be used as follows: `instanceOfTrackRoute.copyWith(...)` or like so:`instanceOfTrackRoute.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackRouteCWProxy get copyWith => _$TrackRouteCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackRoute _$TrackRouteFromJson(Map<String, dynamic> json) => $checkedCreate(
  'TrackRoute',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'leg',
        'polyline',
        'distance_m',
        'duration_s',
        'provider',
        'traffic_aware',
        'computed_at',
      ],
    );
    final val = TrackRoute(
      leg: $checkedConvert(
        'leg',
        (v) => $enumDecode(
          _$RouteLegEnumEnumMap,
          v,
          unknownValue: RouteLegEnum.unknownDefaultOpenApi,
        ),
      ),
      polyline: $checkedConvert('polyline', (v) => v as String),
      distanceM: $checkedConvert('distance_m', (v) => (v as num).toInt()),
      durationS: $checkedConvert('duration_s', (v) => (v as num).toInt()),
      provider: $checkedConvert(
        'provider',
        (v) => $enumDecode(
          _$RouteProviderEnumEnumMap,
          v,
          unknownValue: RouteProviderEnum.unknownDefaultOpenApi,
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
    'distanceM': 'distance_m',
    'durationS': 'duration_s',
    'trafficAware': 'traffic_aware',
    'computedAt': 'computed_at',
  },
);

Map<String, dynamic> _$TrackRouteToJson(TrackRoute instance) =>
    <String, dynamic>{
      'leg': _$RouteLegEnumEnumMap[instance.leg]!,
      'polyline': instance.polyline,
      'distance_m': instance.distanceM,
      'duration_s': instance.durationS,
      'provider': _$RouteProviderEnumEnumMap[instance.provider]!,
      'traffic_aware': instance.trafficAware,
      'computed_at': instance.computedAt.toIso8601String(),
    };

const _$RouteLegEnumEnumMap = {
  RouteLegEnum.TO_STORE: 'TO_STORE',
  RouteLegEnum.TO_CUSTOMER: 'TO_CUSTOMER',
  RouteLegEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};

const _$RouteProviderEnumEnumMap = {
  RouteProviderEnum.google: 'google',
  RouteProviderEnum.haversine: 'haversine',
  RouteProviderEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
