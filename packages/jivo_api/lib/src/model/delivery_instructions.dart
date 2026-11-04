// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_instruction_chip_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delivery_instructions.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeliveryInstructions {
  /// Returns a new [DeliveryInstructions] instance.
  DeliveryInstructions({required this.chips, required this.note});

  /// Selected chips, each at most once (order kept).
  @JsonKey(
    name: r'chips',
    required: true,
    includeIfNull: false,
    unknownEnumValue: DeliveryInstructionChipEnum.unknownDefaultOpenApi,
  )
  final List<DeliveryInstructionChipEnum> chips;

  /// Free text for the rider (\"\" when none).
  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryInstructions &&
          other.chips == chips &&
          other.note == note;

  @override
  int get hashCode => chips.hashCode + note.hashCode;

  factory DeliveryInstructions.fromJson(Map<String, dynamic> json) =>
      _$DeliveryInstructionsFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryInstructionsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
