// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_navigation.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TaskNavigationCWProxy {
  TaskNavigation leg(RouteLegEnum leg);

  TaskNavigation destination(TrackPoint destination);

  TaskNavigation route(TrackRoute? route);

  TaskNavigation distanceM(int? distanceM);

  TaskNavigation etaMinutes(int? etaMinutes);

  TaskNavigation etaAt(DateTime? etaAt);

  TaskNavigation positionAt(DateTime? positionAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskNavigation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskNavigation(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskNavigation call({
    RouteLegEnum leg,
    TrackPoint destination,
    TrackRoute? route,
    int? distanceM,
    int? etaMinutes,
    DateTime? etaAt,
    DateTime? positionAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTaskNavigation.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTaskNavigation.copyWith.fieldName(...)`
class _$TaskNavigationCWProxyImpl implements _$TaskNavigationCWProxy {
  const _$TaskNavigationCWProxyImpl(this._value);

  final TaskNavigation _value;

  @override
  TaskNavigation leg(RouteLegEnum leg) => this(leg: leg);

  @override
  TaskNavigation destination(TrackPoint destination) =>
      this(destination: destination);

  @override
  TaskNavigation route(TrackRoute? route) => this(route: route);

  @override
  TaskNavigation distanceM(int? distanceM) => this(distanceM: distanceM);

  @override
  TaskNavigation etaMinutes(int? etaMinutes) => this(etaMinutes: etaMinutes);

  @override
  TaskNavigation etaAt(DateTime? etaAt) => this(etaAt: etaAt);

  @override
  TaskNavigation positionAt(DateTime? positionAt) =>
      this(positionAt: positionAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TaskNavigation(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TaskNavigation(...).copyWith(id: 12, name: "My name")
  /// ````
  TaskNavigation call({
    Object? leg = const $CopyWithPlaceholder(),
    Object? destination = const $CopyWithPlaceholder(),
    Object? route = const $CopyWithPlaceholder(),
    Object? distanceM = const $CopyWithPlaceholder(),
    Object? etaMinutes = const $CopyWithPlaceholder(),
    Object? etaAt = const $CopyWithPlaceholder(),
    Object? positionAt = const $CopyWithPlaceholder(),
  }) {
    return TaskNavigation(
      leg: leg == const $CopyWithPlaceholder()
          ? _value.leg
          // ignore: cast_nullable_to_non_nullable
          : leg as RouteLegEnum,
      destination: destination == const $CopyWithPlaceholder()
          ? _value.destination
          // ignore: cast_nullable_to_non_nullable
          : destination as TrackPoint,
      route: route == const $CopyWithPlaceholder()
          ? _value.route
          // ignore: cast_nullable_to_non_nullable
          : route as TrackRoute?,
      distanceM: distanceM == const $CopyWithPlaceholder()
          ? _value.distanceM
          // ignore: cast_nullable_to_non_nullable
          : distanceM as int?,
      etaMinutes: etaMinutes == const $CopyWithPlaceholder()
          ? _value.etaMinutes
          // ignore: cast_nullable_to_non_nullable
          : etaMinutes as int?,
      etaAt: etaAt == const $CopyWithPlaceholder()
          ? _value.etaAt
          // ignore: cast_nullable_to_non_nullable
          : etaAt as DateTime?,
      positionAt: positionAt == const $CopyWithPlaceholder()
          ? _value.positionAt
          // ignore: cast_nullable_to_non_nullable
          : positionAt as DateTime?,
    );
  }
}

extension $TaskNavigationCopyWith on TaskNavigation {
  /// Returns a callable class that can be used as follows: `instanceOfTaskNavigation.copyWith(...)` or like so:`instanceOfTaskNavigation.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TaskNavigationCWProxy get copyWith => _$TaskNavigationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TaskNavigation _$TaskNavigationFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'TaskNavigation',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'leg',
        'destination',
        'route',
        'distance_m',
        'eta_minutes',
        'eta_at',
        'position_at',
      ],
    );
    final val = TaskNavigation(
      leg: $checkedConvert(
        'leg',
        (v) => $enumDecode(
          _$RouteLegEnumEnumMap,
          v,
          unknownValue: RouteLegEnum.unknownDefaultOpenApi,
        ),
      ),
      destination: $checkedConvert(
        'destination',
        (v) => TrackPoint.fromJson(v as Map<String, dynamic>),
      ),
      route: $checkedConvert(
        'route',
        (v) =>
            v == null ? null : TrackRoute.fromJson(v as Map<String, dynamic>),
      ),
      distanceM: $checkedConvert('distance_m', (v) => (v as num?)?.toInt()),
      etaMinutes: $checkedConvert('eta_minutes', (v) => (v as num?)?.toInt()),
      etaAt: $checkedConvert(
        'eta_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
      positionAt: $checkedConvert(
        'position_at',
        (v) => v == null ? null : DateTime.parse(v as String),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'distanceM': 'distance_m',
    'etaMinutes': 'eta_minutes',
    'etaAt': 'eta_at',
    'positionAt': 'position_at',
  },
);

Map<String, dynamic> _$TaskNavigationToJson(TaskNavigation instance) =>
    <String, dynamic>{
      'leg': _$RouteLegEnumEnumMap[instance.leg]!,
      'destination': instance.destination.toJson(),
      'route': instance.route?.toJson(),
      'distance_m': instance.distanceM,
      'eta_minutes': instance.etaMinutes,
      'eta_at': instance.etaAt?.toIso8601String(),
      'position_at': instance.positionAt?.toIso8601String(),
    };

const _$RouteLegEnumEnumMap = {
  RouteLegEnum.TO_STORE: 'TO_STORE',
  RouteLegEnum.TO_CUSTOMER: 'TO_CUSTOMER',
  RouteLegEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
