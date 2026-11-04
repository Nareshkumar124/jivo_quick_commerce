// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'earning_line.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EarningLineCWProxy {
  EarningLine type(EarningTypeEnum type);

  EarningLine amount(String amount);

  EarningLine note(String note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningLine(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningLine call({EarningTypeEnum type, String amount, String note});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEarningLine.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEarningLine.copyWith.fieldName(...)`
class _$EarningLineCWProxyImpl implements _$EarningLineCWProxy {
  const _$EarningLineCWProxyImpl(this._value);

  final EarningLine _value;

  @override
  EarningLine type(EarningTypeEnum type) => this(type: type);

  @override
  EarningLine amount(String amount) => this(amount: amount);

  @override
  EarningLine note(String note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EarningLine(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EarningLine(...).copyWith(id: 12, name: "My name")
  /// ````
  EarningLine call({
    Object? type = const $CopyWithPlaceholder(),
    Object? amount = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return EarningLine(
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
    );
  }
}

extension $EarningLineCopyWith on EarningLine {
  /// Returns a callable class that can be used as follows: `instanceOfEarningLine.copyWith(...)` or like so:`instanceOfEarningLine.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EarningLineCWProxy get copyWith => _$EarningLineCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EarningLine _$EarningLineFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EarningLine', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['type', 'amount', 'note']);
      final val = EarningLine(
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
      );
      return val;
    });

Map<String, dynamic> _$EarningLineToJson(EarningLine instance) =>
    <String, dynamic>{
      'type': _$EarningTypeEnumEnumMap[instance.type]!,
      'amount': instance.amount,
      'note': instance.note,
    };

const _$EarningTypeEnumEnumMap = {
  EarningTypeEnum.BASE: 'BASE',
  EarningTypeEnum.DISTANCE: 'DISTANCE',
  EarningTypeEnum.TIP: 'TIP',
  EarningTypeEnum.INCENTIVE: 'INCENTIVE',
  EarningTypeEnum.PENALTY: 'PENALTY',
  EarningTypeEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
