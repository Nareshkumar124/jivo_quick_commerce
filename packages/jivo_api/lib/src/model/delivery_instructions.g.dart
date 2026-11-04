// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_instructions.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeliveryInstructionsCWProxy {
  DeliveryInstructions chips(List<DeliveryInstructionChipEnum> chips);

  DeliveryInstructions note(String note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryInstructions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryInstructions(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryInstructions call({
    List<DeliveryInstructionChipEnum> chips,
    String note,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeliveryInstructions.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeliveryInstructions.copyWith.fieldName(...)`
class _$DeliveryInstructionsCWProxyImpl
    implements _$DeliveryInstructionsCWProxy {
  const _$DeliveryInstructionsCWProxyImpl(this._value);

  final DeliveryInstructions _value;

  @override
  DeliveryInstructions chips(List<DeliveryInstructionChipEnum> chips) =>
      this(chips: chips);

  @override
  DeliveryInstructions note(String note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryInstructions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryInstructions(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryInstructions call({
    Object? chips = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return DeliveryInstructions(
      chips: chips == const $CopyWithPlaceholder()
          ? _value.chips
          // ignore: cast_nullable_to_non_nullable
          : chips as List<DeliveryInstructionChipEnum>,
      note: note == const $CopyWithPlaceholder()
          ? _value.note
          // ignore: cast_nullable_to_non_nullable
          : note as String,
    );
  }
}

extension $DeliveryInstructionsCopyWith on DeliveryInstructions {
  /// Returns a callable class that can be used as follows: `instanceOfDeliveryInstructions.copyWith(...)` or like so:`instanceOfDeliveryInstructions.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeliveryInstructionsCWProxy get copyWith =>
      _$DeliveryInstructionsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryInstructions _$DeliveryInstructionsFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeliveryInstructions', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['chips', 'note']);
  final val = DeliveryInstructions(
    chips: $checkedConvert(
      'chips',
      (v) => (v as List<dynamic>)
          .map(
            (e) => $enumDecode(
              _$DeliveryInstructionChipEnumEnumMap,
              e,
              unknownValue: DeliveryInstructionChipEnum.unknownDefaultOpenApi,
            ),
          )
          .toList(),
    ),
    note: $checkedConvert('note', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$DeliveryInstructionsToJson(
  DeliveryInstructions instance,
) => <String, dynamic>{
  'chips': instance.chips
      .map((e) => _$DeliveryInstructionChipEnumEnumMap[e]!)
      .toList(),
  'note': instance.note,
};

const _$DeliveryInstructionChipEnumEnumMap = {
  DeliveryInstructionChipEnum.DONT_RING_BELL: 'DONT_RING_BELL',
  DeliveryInstructionChipEnum.LEAVE_AT_DOOR: 'LEAVE_AT_DOOR',
  DeliveryInstructionChipEnum.AVOID_CALLING: 'AVOID_CALLING',
  DeliveryInstructionChipEnum.unknownDefaultOpenApi: 'unknown_default_open_api',
};
