// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/earning_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'earning_line.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EarningLine {
  /// Returns a new [EarningLine] instance.
  EarningLine({required this.type, required this.amount, required this.note});

  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: EarningTypeEnum.unknownDefaultOpenApi,
  )
  final EarningTypeEnum type;

  /// Signed: a PENALTY is negative (\"-20.00\").
  @JsonKey(name: r'amount', required: true, includeIfNull: false)
  final String amount;

  @JsonKey(name: r'note', required: true, includeIfNull: false)
  final String note;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EarningLine &&
          other.type == type &&
          other.amount == amount &&
          other.note == note;

  @override
  int get hashCode => type.hashCode + amount.hashCode + note.hashCode;

  factory EarningLine.fromJson(Map<String, dynamic> json) =>
      _$EarningLineFromJson(json);

  Map<String, dynamic> toJson() => _$EarningLineToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
