// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rider_location_settings.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RiderLocationSettingsCWProxy {
  RiderLocationSettings activeIntervalSeconds(int activeIntervalSeconds);

  RiderLocationSettings idleIntervalSeconds(int idleIntervalSeconds);

  RiderLocationSettings activeSampleSeconds(int activeSampleSeconds);

  RiderLocationSettings idleSampleSeconds(int idleSampleSeconds);

  RiderLocationSettings maxBatch(int maxBatch);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RiderLocationSettings(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RiderLocationSettings(...).copyWith(id: 12, name: "My name")
  /// ````
  RiderLocationSettings call({
    int activeIntervalSeconds,
    int idleIntervalSeconds,
    int activeSampleSeconds,
    int idleSampleSeconds,
    int maxBatch,
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
  RiderLocationSettings activeSampleSeconds(int activeSampleSeconds) =>
      this(activeSampleSeconds: activeSampleSeconds);

  @override
  RiderLocationSettings idleSampleSeconds(int idleSampleSeconds) =>
      this(idleSampleSeconds: idleSampleSeconds);

  @override
  RiderLocationSettings maxBatch(int maxBatch) => this(maxBatch: maxBatch);

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
    Object? activeSampleSeconds = const $CopyWithPlaceholder(),
    Object? idleSampleSeconds = const $CopyWithPlaceholder(),
    Object? maxBatch = const $CopyWithPlaceholder(),
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
      activeSampleSeconds: activeSampleSeconds == const $CopyWithPlaceholder()
          ? _value.activeSampleSeconds
          // ignore: cast_nullable_to_non_nullable
          : activeSampleSeconds as int,
      idleSampleSeconds: idleSampleSeconds == const $CopyWithPlaceholder()
          ? _value.idleSampleSeconds
          // ignore: cast_nullable_to_non_nullable
          : idleSampleSeconds as int,
      maxBatch: maxBatch == const $CopyWithPlaceholder()
          ? _value.maxBatch
          // ignore: cast_nullable_to_non_nullable
          : maxBatch as int,
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
      requiredKeys: const [
        'active_interval_seconds',
        'idle_interval_seconds',
        'active_sample_seconds',
        'idle_sample_seconds',
        'max_batch',
      ],
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
      activeSampleSeconds: $checkedConvert(
        'active_sample_seconds',
        (v) => (v as num).toInt(),
      ),
      idleSampleSeconds: $checkedConvert(
        'idle_sample_seconds',
        (v) => (v as num).toInt(),
      ),
      maxBatch: $checkedConvert('max_batch', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {
    'activeIntervalSeconds': 'active_interval_seconds',
    'idleIntervalSeconds': 'idle_interval_seconds',
    'activeSampleSeconds': 'active_sample_seconds',
    'idleSampleSeconds': 'idle_sample_seconds',
    'maxBatch': 'max_batch',
  },
);

Map<String, dynamic> _$RiderLocationSettingsToJson(
  RiderLocationSettings instance,
) => <String, dynamic>{
  'active_interval_seconds': instance.activeIntervalSeconds,
  'idle_interval_seconds': instance.idleIntervalSeconds,
  'active_sample_seconds': instance.activeSampleSeconds,
  'idle_sample_seconds': instance.idleSampleSeconds,
  'max_batch': instance.maxBatch,
};
