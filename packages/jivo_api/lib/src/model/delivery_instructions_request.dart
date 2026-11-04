// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/delivery_instruction_chip_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'delivery_instructions_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DeliveryInstructionsRequest {
  /// Returns a new [DeliveryInstructionsRequest] instance.
  DeliveryInstructionsRequest({required this.chips, required this.note});

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
      other is DeliveryInstructionsRequest &&
          other.chips == chips &&
          other.note == note;

  @override
  int get hashCode => chips.hashCode + note.hashCode;

  factory DeliveryInstructionsRequest.fromJson(Map<String, dynamic> json) =>
      _$DeliveryInstructionsRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DeliveryInstructionsRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
