// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_cash_updated_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsCashUpdatedDataCWProxy {
  WsCashUpdatedData riderId(int riderId);

  WsCashUpdatedData cashInHand(String cashInHand);

  WsCashUpdatedData cashLimit(String cashLimit);

  WsCashUpdatedData limitReached(bool limitReached);

  WsCashUpdatedData depositRequired(bool depositRequired);

  WsCashUpdatedData reason(WsCashUpdatedDataReasonEnum reason);

  WsCashUpdatedData updatedAt(DateTime updatedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsCashUpdatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsCashUpdatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsCashUpdatedData call({
    int riderId,
    String cashInHand,
    String cashLimit,
    bool limitReached,
    bool depositRequired,
    WsCashUpdatedDataReasonEnum reason,
    DateTime updatedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsCashUpdatedData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsCashUpdatedData.copyWith.fieldName(...)`
class _$WsCashUpdatedDataCWProxyImpl implements _$WsCashUpdatedDataCWProxy {
  const _$WsCashUpdatedDataCWProxyImpl(this._value);

  final WsCashUpdatedData _value;

  @override
  WsCashUpdatedData riderId(int riderId) => this(riderId: riderId);

  @override
  WsCashUpdatedData cashInHand(String cashInHand) =>
      this(cashInHand: cashInHand);

  @override
  WsCashUpdatedData cashLimit(String cashLimit) => this(cashLimit: cashLimit);

  @override
  WsCashUpdatedData limitReached(bool limitReached) =>
      this(limitReached: limitReached);

  @override
  WsCashUpdatedData depositRequired(bool depositRequired) =>
      this(depositRequired: depositRequired);

  @override
  WsCashUpdatedData reason(WsCashUpdatedDataReasonEnum reason) =>
      this(reason: reason);

  @override
  WsCashUpdatedData updatedAt(DateTime updatedAt) => this(updatedAt: updatedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsCashUpdatedData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsCashUpdatedData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsCashUpdatedData call({
    Object? riderId = const $CopyWithPlaceholder(),
    Object? cashInHand = const $CopyWithPlaceholder(),
    Object? cashLimit = const $CopyWithPlaceholder(),
    Object? limitReached = const $CopyWithPlaceholder(),
    Object? depositRequired = const $CopyWithPlaceholder(),
    Object? reason = const $CopyWithPlaceholder(),
    Object? updatedAt = const $CopyWithPlaceholder(),
  }) {
    return WsCashUpdatedData(
      riderId: riderId == const $CopyWithPlaceholder()
          ? _value.riderId
          // ignore: cast_nullable_to_non_nullable
          : riderId as int,
      cashInHand: cashInHand == const $CopyWithPlaceholder()
          ? _value.cashInHand
          // ignore: cast_nullable_to_non_nullable
          : cashInHand as String,
      cashLimit: cashLimit == const $CopyWithPlaceholder()
          ? _value.cashLimit
          // ignore: cast_nullable_to_non_nullable
          : cashLimit as String,
      limitReached: limitReached == const $CopyWithPlaceholder()
          ? _value.limitReached
          // ignore: cast_nullable_to_non_nullable
          : limitReached as bool,
      depositRequired: depositRequired == const $CopyWithPlaceholder()
          ? _value.depositRequired
          // ignore: cast_nullable_to_non_nullable
          : depositRequired as bool,
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as WsCashUpdatedDataReasonEnum,
      updatedAt: updatedAt == const $CopyWithPlaceholder()
          ? _value.updatedAt
          // ignore: cast_nullable_to_non_nullable
          : updatedAt as DateTime,
    );
  }
}

extension $WsCashUpdatedDataCopyWith on WsCashUpdatedData {
  /// Returns a callable class that can be used as follows: `instanceOfWsCashUpdatedData.copyWith(...)` or like so:`instanceOfWsCashUpdatedData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsCashUpdatedDataCWProxy get copyWith =>
      _$WsCashUpdatedDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsCashUpdatedData _$WsCashUpdatedDataFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'WsCashUpdatedData',
      json,
      ($checkedConvert) {
        $checkKeys(
          json,
          requiredKeys: const [
            'rider_id',
            'cash_in_hand',
            'cash_limit',
            'limit_reached',
            'deposit_required',
            'reason',
            'updated_at',
          ],
        );
        final val = WsCashUpdatedData(
          riderId: $checkedConvert('rider_id', (v) => (v as num).toInt()),
          cashInHand: $checkedConvert('cash_in_hand', (v) => v as String),
          cashLimit: $checkedConvert('cash_limit', (v) => v as String),
          limitReached: $checkedConvert('limit_reached', (v) => v as bool),
          depositRequired: $checkedConvert(
            'deposit_required',
            (v) => v as bool,
          ),
          reason: $checkedConvert(
            'reason',
            (v) => $enumDecode(
              _$WsCashUpdatedDataReasonEnumEnumMap,
              v,
              unknownValue: WsCashUpdatedDataReasonEnum.unknownDefaultOpenApi,
            ),
          ),
          updatedAt: $checkedConvert(
            'updated_at',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'riderId': 'rider_id',
        'cashInHand': 'cash_in_hand',
        'cashLimit': 'cash_limit',
        'limitReached': 'limit_reached',
        'depositRequired': 'deposit_required',
        'updatedAt': 'updated_at',
      },
    );

Map<String, dynamic> _$WsCashUpdatedDataToJson(WsCashUpdatedData instance) =>
    <String, dynamic>{
      'rider_id': instance.riderId,
      'cash_in_hand': instance.cashInHand,
      'cash_limit': instance.cashLimit,
      'limit_reached': instance.limitReached,
      'deposit_required': instance.depositRequired,
      'reason': _$WsCashUpdatedDataReasonEnumEnumMap[instance.reason]!,
      'updated_at': instance.updatedAt.toIso8601String(),
    };

const _$WsCashUpdatedDataReasonEnumEnumMap = {
  WsCashUpdatedDataReasonEnum.COD_COLLECTED: 'COD_COLLECTED',
  WsCashUpdatedDataReasonEnum.DEPOSIT: 'DEPOSIT',
  WsCashUpdatedDataReasonEnum.ADJUSTMENT: 'ADJUSTMENT',
  WsCashUpdatedDataReasonEnum.DEPOSIT_REQUIRED: 'DEPOSIT_REQUIRED',
  WsCashUpdatedDataReasonEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
