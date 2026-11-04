// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delivery_instructions_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DeliveryInstructionsRequestCWProxy {
  DeliveryInstructionsRequest chips(List<DeliveryInstructionChipEnum> chips);

  DeliveryInstructionsRequest note(String note);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryInstructionsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryInstructionsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryInstructionsRequest call({
    List<DeliveryInstructionChipEnum> chips,
    String note,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDeliveryInstructionsRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDeliveryInstructionsRequest.copyWith.fieldName(...)`
class _$DeliveryInstructionsRequestCWProxyImpl
    implements _$DeliveryInstructionsRequestCWProxy {
  const _$DeliveryInstructionsRequestCWProxyImpl(this._value);

  final DeliveryInstructionsRequest _value;

  @override
  DeliveryInstructionsRequest chips(List<DeliveryInstructionChipEnum> chips) =>
      this(chips: chips);

  @override
  DeliveryInstructionsRequest note(String note) => this(note: note);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DeliveryInstructionsRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DeliveryInstructionsRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  DeliveryInstructionsRequest call({
    Object? chips = const $CopyWithPlaceholder(),
    Object? note = const $CopyWithPlaceholder(),
  }) {
    return DeliveryInstructionsRequest(
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

extension $DeliveryInstructionsRequestCopyWith on DeliveryInstructionsRequest {
  /// Returns a callable class that can be used as follows: `instanceOfDeliveryInstructionsRequest.copyWith(...)` or like so:`instanceOfDeliveryInstructionsRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DeliveryInstructionsRequestCWProxy get copyWith =>
      _$DeliveryInstructionsRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeliveryInstructionsRequest _$DeliveryInstructionsRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DeliveryInstructionsRequest', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['chips', 'note']);
  final val = DeliveryInstructionsRequest(
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

Map<String, dynamic> _$DeliveryInstructionsRequestToJson(
  DeliveryInstructionsRequest instance,
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
