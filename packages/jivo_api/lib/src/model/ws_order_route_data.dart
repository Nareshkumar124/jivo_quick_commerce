// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_route_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderRouteData {
  /// Returns a new [WsOrderRouteData] instance.
  WsOrderRouteData({
    required this.orderId,

    required this.leg,

    required this.polyline,

    required this.distanceM,

    required this.durationS,

    required this.provider,

    required this.trafficAware,

    required this.computedAt,
  });

  @JsonKey(name: r'order_id', required: true, includeIfNull: false)
  final int orderId;

  @JsonKey(
    name: r'leg',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsOrderRouteDataLegEnum.unknownDefaultOpenApi,
  )
  final WsOrderRouteDataLegEnum leg;

  /// Google encoded polyline (precision 5).
  @JsonKey(name: r'polyline', required: true, includeIfNull: false)
  final String polyline;

  @JsonKey(name: r'distance_m', required: true, includeIfNull: false)
  final int distanceM;

  @JsonKey(name: r'duration_s', required: true, includeIfNull: false)
  final int durationS;

  @JsonKey(
    name: r'provider',
    required: true,
    includeIfNull: false,
    unknownEnumValue: WsOrderRouteDataProviderEnum.unknownDefaultOpenApi,
  )
  final WsOrderRouteDataProviderEnum provider;

  @JsonKey(name: r'traffic_aware', required: true, includeIfNull: false)
  final bool trafficAware;

  @JsonKey(name: r'computed_at', required: true, includeIfNull: false)
  final DateTime computedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderRouteData &&
          other.orderId == orderId &&
          other.leg == leg &&
          other.polyline == polyline &&
          other.distanceM == distanceM &&
          other.durationS == durationS &&
          other.provider == provider &&
          other.trafficAware == trafficAware &&
          other.computedAt == computedAt;

  @override
  int get hashCode =>
      orderId.hashCode +
      leg.hashCode +
      polyline.hashCode +
      distanceM.hashCode +
      durationS.hashCode +
      provider.hashCode +
      trafficAware.hashCode +
      computedAt.hashCode;

  factory WsOrderRouteData.fromJson(Map<String, dynamic> json) =>
      _$WsOrderRouteDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderRouteDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum WsOrderRouteDataLegEnum {
  @JsonValue(r'TO_STORE')
  TO_STORE(r'TO_STORE'),
  @JsonValue(r'TO_CUSTOMER')
  TO_CUSTOMER(r'TO_CUSTOMER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsOrderRouteDataLegEnum(this.value);

  final String value;

  @override
  String toString() => value;
}

enum WsOrderRouteDataProviderEnum {
  @JsonValue(r'google')
  google(r'google'),
  @JsonValue(r'haversine')
  haversine(r'haversine'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WsOrderRouteDataProviderEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
