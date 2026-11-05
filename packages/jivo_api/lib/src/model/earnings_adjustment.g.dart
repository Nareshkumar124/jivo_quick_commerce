// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earnings_adjustment.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EarningsAdjustmentCWProxy {
  EarningsAdjustment type(EarningTypeEnum type);

  EarningsAdjustment amount(String amount);

  EarningsAdjustment note(String note);

  EarningsAdjustment recordedAt(DateTime recordedAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningsAdjustment(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningsAdjustment(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningsAdjustment call({
    EarningTypeEnum type,
    String amount,
    String note,
    DateTime recordedAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEarningsAdjustment.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEarningsAdjustment.copyWith.fieldName(...)`
class _$EarningsAdjustmentCWProxyImpl implements _$EarningsAdjustmentCWProxy {
  const _$EarningsAdjustmentCWProxyImpl(this._value);

  final EarningsAdjustment _value;

  @override
  EarningsAdjustment type(EarningTypeEnum type) => this(type: type);

  @override
  EarningsAdjustment amount(String amount) => this(amount: amount);

  @override
  EarningsAdjustment note(String note) => this(note: note);

  @override
  EarningsAdjustment recordedAt(DateTime recordedAt) =>
      this(recordedAt: recordedAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningsAdjustment(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningsAdjustment(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningsAdjustment call({
    Object? type = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
    Object? recordedAt = const $CopyWithPlaceholder(),
  }) {
    return EarningsAdjustment(
      type: type == const $CopyWithPlaceholder()
          ? _value.type
          // ignore: cast_nullable_to_non_nullable
          : type as EarningTypeEnum,
      amount: amount == const $CopyWithPlaceholder()
          ? _value.amount
          // ignore: cast_nullable_to_non_nullable
          : amount as String,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
      recordedAt: recordedAt == const $CopyWithPlaceholder()
          ? _value.recordedAt
          // ignore: cast_nullable_to_non_nullable
          : recordedAt as DateTime,
    );
  }
}

extension $EarningsAdjustmentCopyWith on EarningsAdjustment {
  /// Returns a callable class that can be used as follows: `instanceOfEarningsAdjustment.copyWith(...)` or like so:`instanceOfEarningsAdjustment.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EarningsAdjustmentCWProxy get copyWith =>
      _$EarningsAdjustmentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EarningsAdjustment _$EarningsAdjustmentFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EarningsAdjustment', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['type', 'amount', 'note', 'recorded_at'],
      );
      final val = EarningsAdjustment(
        type: $checkedConvert(
          'type',
          (v) => $enumDecode(
            _$EarningTypeEnumEnumMap,
            v,
            unknownValue: EarningTypeEnum.unknownDefaultOpenApi,
          ),
        ),
        amount: $checkedConvert('amount', (v) => v as String),
        note: $checkedConvert('note', (v) => v as String),
        recordedAt: $checkedConvert(
          'recorded_at',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'recordedAt': 'recorded_at'});

Map<String, dynamic> _$EarningsAdjustmentToJson(EarningsAdjustment instance) =>
    <String, dynamic>{
      'type': _$EarningTypeEnumEnumMap[instance.type]!,
      'amount': instance.amount,
      'note': instance.note,
      'recorded_at': instance.recordedAt.toIso8601String(),
    };

const _$EarningTypeEnumEnumMap = {
  EarningTypeEnum.BASE: 'BASE',
  EarningTypeEnum.DISTANCE: 'DISTANCE',
  EarningTypeEnum.TIP: 'TIP',
  EarningTypeEnum.INCENTIVE: 'INCENTIVE',
  EarningTypeEnum.PENALTY: 'PENALTY',
  EarningTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
