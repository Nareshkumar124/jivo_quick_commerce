// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/error_body.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'error_envelope.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ErrorEnvelope {
  /// Returns a new [ErrorEnvelope] instance.
  ErrorEnvelope({required this.error});

  @JsonKey(name: r'error', required: true, includeIfNull: false)
  final ErrorBody error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ErrorEnvelope && other.error == error;

  @override
  int get hashCode => error.hashCode;

  factory ErrorEnvelope.fromJson(Map<String, dynamic> json) =>
      _$ErrorEnvelopeFromJson(json);

  Map<String, dynamic> toJson() => _$ErrorEnvelopeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
