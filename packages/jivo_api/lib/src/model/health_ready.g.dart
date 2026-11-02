// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_ready.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HealthReadyCWProxy {
  HealthReady status(HealthStatusEnum status);

  HealthReady checks(HealthChecks checks);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthReady(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthReady(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthReady call({HealthStatusEnum status, HealthChecks checks});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHealthReady.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHealthReady.copyWith.fieldName(...)`
class _$HealthReadyCWProxyImpl implements _$HealthReadyCWProxy {
  const _$HealthReadyCWProxyImpl(this._value);

  final HealthReady _value;

  @override
  HealthReady status(HealthStatusEnum status) => this(status: status);

  @override
  HealthReady checks(HealthChecks checks) => this(checks: checks);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthReady(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthReady(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthReady call({
    Object? status = const $CopyWithPlaceholder(),
    Object? checks = const $CopyWithPlaceholder(),
  }) {
    return HealthReady(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as HealthStatusEnum,
      checks: checks == const $CopyWithPlaceholder()
          ? _value.checks
          // ignore: cast_nullable_to_non_nullable
          : checks as HealthChecks,
    );
  }
}

extension $HealthReadyCopyWith on HealthReady {
  /// Returns a callable class that can be used as follows: `instanceOfHealthReady.copyWith(...)` or like so:`instanceOfHealthReady.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HealthReadyCWProxy get copyWith => _$HealthReadyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthReady _$HealthReadyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HealthReady', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status', 'checks']);
      final val = HealthReady(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$HealthStatusEnumEnumMap,
            v,
            unknownValue: HealthStatusEnum.unknownDefaultOpenApi,
          ),
        ),
        checks: $checkedConvert(
          'checks',
          (v) => HealthChecks.fromJson(v as Map<String, dynamic>),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HealthReadyToJson(HealthReady instance) =>
    <String, dynamic>{
      'status': _$HealthStatusEnumEnumMap[instance.status]!,
      'checks': instance.checks.toJson(),
    };

const _$HealthStatusEnumEnumMap = {
  HealthStatusEnum.ok: 'ok',
  HealthStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
