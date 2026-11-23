// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_progress_step.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackProgressStepCWProxy {
  TrackProgressStep key(TrackingStepEnum key);

  TrackProgressStep label(String label);

  TrackProgressStep done(bool done);

  TrackProgressStep at(DateTime? at);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackProgressStep(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackProgressStep(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackProgressStep call({
    TrackingStepEnum key,
    String label,
    bool done,
    DateTime? at,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackProgressStep.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackProgressStep.copyWith.fieldName(...)`
class _$TrackProgressStepCWProxyImpl implements _$TrackProgressStepCWProxy {
  const _$TrackProgressStepCWProxyImpl(this._value);

  final TrackProgressStep _value;

  @override
  TrackProgressStep key(TrackingStepEnum key) => this(key: key);

  @override
  TrackProgressStep label(String label) => this(label: label);

  @override
  TrackProgressStep done(bool done) => this(done: done);

  @override
  TrackProgressStep at(DateTime? at) => this(at: at);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackProgressStep(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackProgressStep(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackProgressStep call({
    Object? key = const $CopyWithPlaceholder(),
    Object? label = const $CopyWithPlaceholder(),
    Object? done = const $CopyWithPlaceholder(),
    Object? at = const $CopyWithPlaceholder(),
  }) {
    return TrackProgressStep(
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as TrackingStepEnum,
      label: label == const $CopyWithPlaceholder()
          ? _value.label
          // ignore: cast_nullable_to_non_nullable
          : label as String,
      done: done == const $CopyWithPlaceholder()
          ? _value.done
          // ignore: cast_nullable_to_non_nullable
          : done as bool,
      at: at == const $CopyWithPlaceholder()
          ? _value.at
          // ignore: cast_nullable_to_non_nullable
          : at as DateTime?,
    );
  }
}

extension $TrackProgressStepCopyWith on TrackProgressStep {
  /// Returns a callable class that can be used as follows: `instanceOfTrackProgressStep.copyWith(...)` or like so:`instanceOfTrackProgressStep.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackProgressStepCWProxy get copyWith =>
      _$TrackProgressStepCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackProgressStep _$TrackProgressStepFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TrackProgressStep', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key', 'label', 'done', 'at']);
      final val = TrackProgressStep(
        key: $checkedConvert(
          'key',
          (v) => $enumDecode(
            _$TrackingStepEnumEnumMap,
            v,
            unknownValue: TrackingStepEnum.unknownDefaultOpenApi,
          ),
        ),
        label: $checkedConvert('label', (v) => v as String),
        done: $checkedConvert('done', (v) => v as bool),
        at: $checkedConvert(
          'at',
          (v) => v == null ? null : DateTime.parse(v as String),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TrackProgressStepToJson(TrackProgressStep instance) =>
    <String, dynamic>{
      'key': _$TrackingStepEnumEnumMap[instance.key]!,
      'label': instance.label,
      'done': instance.done,
      'at': instance.at?.toIso8601String(),
    };

const _$TrackingStepEnumEnumMap = {
  TrackingStepEnum.CONFIRMED: 'CONFIRMED',
  TrackingStepEnum.PREPARING: 'PREPARING',
  TrackingStepEnum.PACKED: 'PACKED',
  TrackingStepEnum.RIDER_ASSIGNED: 'RIDER_ASSIGNED',
  TrackingStepEnum.PICKED_UP: 'PICKED_UP',
  TrackingStepEnum.ON_THE_WAY: 'ON_THE_WAY',
  TrackingStepEnum.ARRIVING: 'ARRIVING',
  TrackingStepEnum.DELIVERED: 'DELIVERED',
  TrackingStepEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
