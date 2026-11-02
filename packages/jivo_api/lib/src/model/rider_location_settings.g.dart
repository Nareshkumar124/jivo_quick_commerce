// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_location_settings.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderLocationSettingsCWProxy {
  RiderLocationSettings activeIntervalSeconds(int activeIntervalSeconds);

  RiderLocationSettings idleIntervalSeconds(int idleIntervalSeconds);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderLocationSettings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderLocationSettings(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderLocationSettings call({
    int activeIntervalSeconds,
    int idleIntervalSeconds,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRiderLocationSettings.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRiderLocationSettings.copyWith.fieldName(...)`
class _$RiderLocationSettingsCWProxyImpl
    implements _$RiderLocationSettingsCWProxy {
  const _$RiderLocationSettingsCWProxyImpl(this._value);

  final RiderLocationSettings _value;

  @override
  RiderLocationSettings activeIntervalSeconds(int activeIntervalSeconds) =>
      this(activeIntervalSeconds: activeIntervalSeconds);

  @override
  RiderLocationSettings idleIntervalSeconds(int idleIntervalSeconds) =>
      this(idleIntervalSeconds: idleIntervalSeconds);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderLocationSettings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderLocationSettings(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderLocationSettings call({
    Object? activeIntervalSeconds = const $CopyWithPlaceholder(),
    Object? idleIntervalSeconds = const $CopyWithPlaceholder(),
  }) {
    return RiderLocationSettings(
      activeIntervalSeconds:
          activeIntervalSeconds == const $CopyWithPlaceholder()
          ? _value.activeIntervalSeconds
          // ignore: cast_nullable_to_non_nullable
          : activeIntervalSeconds as int,
      idleIntervalSeconds: idleIntervalSeconds == const $CopyWithPlaceholder()
          ? _value.idleIntervalSeconds
          // ignore: cast_nullable_to_non_nullable
          : idleIntervalSeconds as int,
    );
  }
}

extension $RiderLocationSettingsCopyWith on RiderLocationSettings {
  /// Returns a callable class that can be used as follows: `instanceOfRiderLocationSettings.copyWith(...)` or like so:`instanceOfRiderLocationSettings.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RiderLocationSettingsCWProxy get copyWith =>
      _$RiderLocationSettingsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RiderLocationSettings _$RiderLocationSettingsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'RiderLocationSettings',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const ['active_interval_seconds', 'idle_interval_seconds'],
    );
    final val = RiderLocationSettings(
      activeIntervalSeconds: $checkedConvert(
        'active_interval_seconds',
        (v) => (v as num).toInt(),
      ),
      idleIntervalSeconds: $checkedConvert(
        'idle_interval_seconds',
        (v) => (v as num).toInt(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'activeIntervalSeconds': 'active_interval_seconds',
    'idleIntervalSeconds': 'idle_interval_seconds',
  },
);

Map<String, dynamic> _$RiderLocationSettingsToJson(
  RiderLocationSettings instance,
) => <String, dynamic>{
  'active_interval_seconds': instance.activeIntervalSeconds,
  'idle_interval_seconds': instance.idleIntervalSeconds,
};
