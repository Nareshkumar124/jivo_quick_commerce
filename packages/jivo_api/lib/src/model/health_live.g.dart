// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'health_live.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HealthLiveCWProxy {
  HealthLive status(HealthStatusEnum status);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthLive(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthLive(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthLive call({HealthStatusEnum status});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfHealthLive.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfHealthLive.copyWith.fieldName(...)`
class _$HealthLiveCWProxyImpl implements _$HealthLiveCWProxy {
  const _$HealthLiveCWProxyImpl(this._value);

  final HealthLive _value;

  @override
  HealthLive status(HealthStatusEnum status) => this(status: status);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `HealthLive(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// HealthLive(...).copyWith(id: 12, name: "My name")
  /// ````
  HealthLive call({Object? status = const $CopyWithPlaceholder()}) {
    return HealthLive(
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as HealthStatusEnum,
    );
  }
}

extension $HealthLiveCopyWith on HealthLive {
  /// Returns a callable class that can be used as follows: `instanceOfHealthLive.copyWith(...)` or like so:`instanceOfHealthLive.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HealthLiveCWProxy get copyWith => _$HealthLiveCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HealthLive _$HealthLiveFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HealthLive', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['status']);
      final val = HealthLive(
        status: $checkedConvert(
          'status',
          (v) => $enumDecode(
            _$HealthStatusEnumEnumMap,
            v,
            unknownValue: HealthStatusEnum.unknownDefaultOpenApi,
          ),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HealthLiveToJson(HealthLive instance) =>
    <String, dynamic>{'status': _$HealthStatusEnumEnumMap[instance.status]!};

const _$HealthStatusEnumEnumMap = {
  HealthStatusEnum.ok: 'ok',
  HealthStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
