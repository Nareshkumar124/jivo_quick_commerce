// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/route_provider_enum.dart';
import 'package:jivo_api/src/model/route_leg_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_route.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackRoute {
  /// Returns a new [TrackRoute] instance.
  TrackRoute({
    required this.leg,

    required this.polyline,

    required this.distanceM,

    required this.durationS,

    required this.provider,

    required this.trafficAware,

    required this.computedAt,
  });

  /// TO_STORE before pickup, TO_CUSTOMER after.  * `TO_STORE` - Rider to the store * `TO_CUSTOMER` - Rider to the customer
  @JsonKey(
    name: r'leg',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RouteLegEnum.unknownDefaultOpenApi,
  )
  final RouteLegEnum leg;

  /// Google encoded polyline (precision 5) from where the route was computed to the leg's end. Draw it from the rider marker; a 2-point line with provider haversine.
  @JsonKey(name: r'polyline', required: true, includeIfNull: false)
  final String polyline;

  /// Road metres left on this leg.
  @JsonKey(name: r'distance_m', required: true, includeIfNull: false)
  final int distanceM;

  /// Seconds left on this leg.
  @JsonKey(name: r'duration_s', required: true, includeIfNull: false)
  final int durationS;

  @JsonKey(
    name: r'provider',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RouteProviderEnum.unknownDefaultOpenApi,
  )
  final RouteProviderEnum provider;

  @JsonKey(name: r'traffic_aware', required: true, includeIfNull: false)
  final bool trafficAware;

  /// When the route was computed.
  @JsonKey(name: r'computed_at', required: true, includeIfNull: false)
  final DateTime computedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackRoute &&
          other.leg == leg &&
          other.polyline == polyline &&
          other.distanceM == distanceM &&
          other.durationS == durationS &&
          other.provider == provider &&
          other.trafficAware == trafficAware &&
          other.computedAt == computedAt;

  @override
  int get hashCode =>
      leg.hashCode +
      polyline.hashCode +
      distanceM.hashCode +
      durationS.hashCode +
      provider.hashCode +
      trafficAware.hashCode +
      computedAt.hashCode;

  factory TrackRoute.fromJson(Map<String, dynamic> json) =>
      _$TrackRouteFromJson(json);

  Map<String, dynamic> toJson() => _$TrackRouteToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
