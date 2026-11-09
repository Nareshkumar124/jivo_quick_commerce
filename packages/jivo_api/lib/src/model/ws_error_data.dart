// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_error_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsErrorData {
  /// Returns a new [WsErrorData] instance.
  WsErrorData({required this.code, required this.message});

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsErrorData && other.code == code && other.message == message;

  @override
  int get hashCode => code.hashCode + message.hashCode;

  factory WsErrorData.fromJson(Map<String, dynamic> json) =>
      _$WsErrorDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsErrorDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
