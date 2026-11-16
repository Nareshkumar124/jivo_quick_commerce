// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'referred_by.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReferredByCWProxy {
  ReferredBy codeMasked(String codeMasked);

  ReferredBy status(ReferralStatusEnum status);

  ReferredBy appliedAt(DateTime appliedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReferredBy(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReferredBy(...).copyWith(id: 12, name: "My name")
  /// ````
  ReferredBy call({
    String codeMasked,
    ReferralStatusEnum status,
    DateTime appliedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReferredBy.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReferredBy.copyWith.fieldName(...)`
class _$ReferredByCWProxyImpl implements _$ReferredByCWProxy {
  const _$ReferredByCWProxyImpl(this._value);

  final ReferredBy _value;

  @override
  ReferredBy codeMasked(String codeMasked) => this(codeMasked: codeMasked);

  @override
  ReferredBy status(ReferralStatusEnum status) => this(status: status);

  @override
  ReferredBy appliedAt(DateTime appliedAt) => this(appliedAt: appliedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReferredBy(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReferredBy(...).copyWith(id: 12, name: "My name")
  /// ````
  ReferredBy call({
    Object? codeMasked = const $CopyWithPlaceholder(),
    Object? status = const $CopyWithPlaceholder(),
    Object? appliedAt = const $CopyWithPlaceholder(),
  }) {
    return ReferredBy(
      codeMasked: codeMasked == const $CopyWithPlaceholder()
          ? _value.codeMasked
          // ignore: cast_nullable_to_non_nullable
          : codeMasked as String,
      status: status == const $CopyWithPlaceholder()
          ? _value.status
          // ignore: cast_nullable_to_non_nullable
          : status as ReferralStatusEnum,
      appliedAt: appliedAt == const $CopyWithPlaceholder()
          ? _value.appliedAt
          // ignore: cast_nullable_to_non_nullable
          : appliedAt as DateTime,
    );
  }
}

extension $ReferredByCopyWith on ReferredBy {
  /// Returns a callable class that can be used as follows: `instanceOfReferredBy.copyWith(...)` or like so:`instanceOfReferredBy.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReferredByCWProxy get copyWith => _$ReferredByCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReferredBy _$ReferredByFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ReferredBy', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['code_masked', 'status', 'applied_at']);
  final val = ReferredBy(
    codeMasked: $checkedConvert('code_masked', (v) => v as String),
    status: $checkedConvert(
      'status',
      (v) => $enumDecode(
        _$ReferralStatusEnumEnumMap,
        v,
        unknownValue: ReferralStatusEnum.unknownDefaultOpenApi,
      ),
    ),
    appliedAt: $checkedConvert(
      'applied_at',
      (v) => DateTime.parse(v as String),
    ),
  );
  return val;
}, fieldKeyMap: const {'codeMasked': 'code_masked', 'appliedAt': 'applied_at'});

Map<String, dynamic> _$ReferredByToJson(ReferredBy instance) =>
    <String, dynamic>{
      'code_masked': instance.codeMasked,
      'status': _$ReferralStatusEnumEnumMap[instance.status]!,
      'applied_at': instance.appliedAt.toIso8601String(),
    };

const _$ReferralStatusEnumEnumMap = {
  ReferralStatusEnum.PENDING: 'PENDING',
  ReferralStatusEnum.REWARDED: 'REWARDED',
  ReferralStatusEnum.VOID: 'VOID',
  ReferralStatusEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
