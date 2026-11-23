// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_progress.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TrackProgressCWProxy {
  TrackProgress current(TrackingStepEnum? current);

  TrackProgress outcome(TrackingOutcomeEnum? outcome);

  TrackProgress steps(List<TrackProgressStep> steps);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackProgress(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackProgress(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackProgress call({
    TrackingStepEnum? current,
    TrackingOutcomeEnum? outcome,
    List<TrackProgressStep> steps,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTrackProgress.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTrackProgress.copyWith.fieldName(...)`
class _$TrackProgressCWProxyImpl implements _$TrackProgressCWProxy {
  const _$TrackProgressCWProxyImpl(this._value);

  final TrackProgress _value;

  @override
  TrackProgress current(TrackingStepEnum? current) => this(current: current);

  @override
  TrackProgress outcome(TrackingOutcomeEnum? outcome) => this(outcome: outcome);

  @override
  TrackProgress steps(List<TrackProgressStep> steps) => this(steps: steps);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TrackProgress(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TrackProgress(...).copyWith(id: 12, name: "My name")
  /// ````
  TrackProgress call({
    Object? current = const $CopyWithPlaceholder(),
    Object? outcome = const $CopyWithPlaceholder(),
    Object? steps = const $CopyWithPlaceholder(),
  }) {
    return TrackProgress(
      current: current == const $CopyWithPlaceholder()
          ? _value.current
          // ignore: cast_nullable_to_non_nullable
          : current as TrackingStepEnum?,
      outcome: outcome == const $CopyWithPlaceholder()
          ? _value.outcome
          // ignore: cast_nullable_to_non_nullable
          : outcome as TrackingOutcomeEnum?,
      steps: steps == const $CopyWithPlaceholder()
          ? _value.steps
          // ignore: cast_nullable_to_non_nullable
          : steps as List<TrackProgressStep>,
    );
  }
}

extension $TrackProgressCopyWith on TrackProgress {
  /// Returns a callable class that can be used as follows: `instanceOfTrackProgress.copyWith(...)` or like so:`instanceOfTrackProgress.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TrackProgressCWProxy get copyWith => _$TrackProgressCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TrackProgress _$TrackProgressFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TrackProgress', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['current', 'outcome', 'steps']);
      final val = TrackProgress(
        current: $checkedConvert(
          'current',
          (v) => $enumDecodeNullable(
            _$TrackingStepEnumEnumMap,
            v,
            unknownValue: TrackingStepEnum.unknownDefaultOpenApi,
          ),
        ),
        outcome: $checkedConvert(
          'outcome',
          (v) => $enumDecodeNullable(
            _$TrackingOutcomeEnumEnumMap,
            v,
            unknownValue: TrackingOutcomeEnum.unknownDefaultOpenApi,
          ),
        ),
        steps: $checkedConvert(
          'steps',
          (v) => (v as List<dynamic>)
              .map((e) => TrackProgressStep.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$TrackProgressToJson(TrackProgress instance) =>
    <String, dynamic>{
      'current': _$TrackingStepEnumEnumMap[instance.current],
      'outcome': _$TrackingOutcomeEnumEnumMap[instance.outcome],
      'steps': instance.steps.map((e) => e.toJson()).toList(),
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

const _$TrackingOutcomeEnumEnumMap = {
  TrackingOutcomeEnum.DELIVERED: 'DELIVERED',
  TrackingOutcomeEnum.CANCELLED: 'CANCELLED',
  TrackingOutcomeEnum.DELIVERY_FAILED: 'DELIVERY_FAILED',
  TrackingOutcomeEnum.RETURNED: 'RETURNED',
  TrackingOutcomeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
