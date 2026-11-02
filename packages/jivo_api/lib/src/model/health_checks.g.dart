// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_checks.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HealthChecksCWProxy {
  HealthChecks database(HealthCheckStatusEnum database);

  HealthChecks redis(HealthCheckStatusEnum redis);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthChecks(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthChecks(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthChecks call({
    HealthCheckStatusEnum database,
    HealthCheckStatusEnum redis,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHealthChecks.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHealthChecks.copyWith.fieldName(...)`
class _$HealthChecksCWProxyImpl implements _$HealthChecksCWProxy {
  const _$HealthChecksCWProxyImpl(this._value);

  final HealthChecks _value;

  @override
  HealthChecks database(HealthCheckStatusEnum database) =>
      this(database: database);

  @override
  HealthChecks redis(HealthCheckStatusEnum redis) => this(redis: redis);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthChecks(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthChecks(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthChecks call({
    Object? database = const $CopyWithPlaceholder(),
    Object? redis = const $CopyWithPlaceholder(),
  }) {
    return HealthChecks(
      database: database == const $CopyWithPlaceholder()
          ? _value.database
          // ignore: cast_nullable_to_non_nullable
          : database as HealthCheckStatusEnum,
      redis: redis == const $CopyWithPlaceholder()
          ? _value.redis
          // ignore: cast_nullable_to_non_nullable
          : redis as HealthCheckStatusEnum,
    );
  }
}

extension $HealthChecksCopyWith on HealthChecks {
  /// Returns a callable class that can be used as follows: `instanceOfHealthChecks.copyWith(...)` or like so:`instanceOfHealthChecks.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HealthChecksCWProxy get copyWith => _$HealthChecksCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthChecks _$HealthChecksFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HealthChecks', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['database', 'redis']);
      final val = HealthChecks(
        database: $checkedConvert(
          'database',
          (v) => $enumDecode(
            _$HealthCheckStatusEnumEnumMap,
            v,
            unknownValue: HealthCheckStatusEnum.unknownDefaultOpenApi,
          ),
        ),
        redis: $checkedConvert(
          'redis',
          (v) => $enumDecode(
            _$HealthCheckStatusEnumEnumMap,
            v,
            unknownValue: HealthCheckStatusEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HealthChecksToJson(HealthChecks instance) =>
    <String, dynamic>{
      'database': _$HealthCheckStatusEnumEnumMap[instance.database]!,
      'redis': _$HealthCheckStatusEnumEnumMap[instance.redis]!,
    };

const _$HealthCheckStatusEnumEnumMap = {
  HealthCheckStatusEnum.ok: 'ok',
  HealthCheckStatusEnum.error: 'error',
  HealthCheckStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
