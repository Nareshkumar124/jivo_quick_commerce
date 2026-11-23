// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/track_point.dart';
import 'package:jivo_api/src/model/track_route.dart';
import 'package:jivo_api/src/model/route_leg_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_navigation.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskNavigation {
  /// Returns a new [TaskNavigation] instance.
  TaskNavigation({
    required this.leg,

    required this.destination,

    required this.route,

    required this.distanceM,

    required this.etaMinutes,

    required this.etaAt,

    required this.positionAt,
  });

  @JsonKey(
    name: r'leg',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RouteLegEnum.unknownDefaultOpenApi,
  )
  final RouteLegEnum leg;

  /// The store, or the drop pin after pickup.
  @JsonKey(name: r'destination', required: true, includeIfNull: false)
  final TrackPoint destination;

  /// Null until the server has a position from this rider.
  @JsonKey(name: r'route', required: true, includeIfNull: true)
  final TrackRoute? route;

  /// Road metres to the destination; null without a position.
  @JsonKey(name: r'distance_m', required: true, includeIfNull: true)
  final int? distanceM;

  /// Minutes to the destination (traffic when available).
  @JsonKey(name: r'eta_minutes', required: true, includeIfNull: true)
  final int? etaMinutes;

  @JsonKey(name: r'eta_at', required: true, includeIfNull: true)
  final DateTime? etaAt;

  /// When the position the route starts from was recorded.
  @JsonKey(name: r'position_at', required: true, includeIfNull: true)
  final DateTime? positionAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskNavigation &&
          other.leg == leg &&
          other.destination == destination &&
          other.route == route &&
          other.distanceM == distanceM &&
          other.etaMinutes == etaMinutes &&
          other.etaAt == etaAt &&
          other.positionAt == positionAt;

  @override
  int get hashCode =>
      leg.hashCode +
      destination.hashCode +
      (route == null ? 0 : route.hashCode) +
      (distanceM == null ? 0 : distanceM.hashCode) +
      (etaMinutes == null ? 0 : etaMinutes.hashCode) +
      (etaAt == null ? 0 : etaAt.hashCode) +
      (positionAt == null ? 0 : positionAt.hashCode);

  factory TaskNavigation.fromJson(Map<String, dynamic> json) =>
      _$TaskNavigationFromJson(json);

  Map<String, dynamic> toJson() => _$TaskNavigationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
