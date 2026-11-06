// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_auth_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsAuthRequest {
  /// Returns a new [WsAuthRequest] instance.
  WsAuthRequest({required this.type, required this.token});

  /// \"auth\"
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'token', required: true, includeIfNull: false)
  final String token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsAuthRequest && other.type == type && other.token == token;

  @override
  int get hashCode => type.hashCode + token.hashCode;

  factory WsAuthRequest.fromJson(Map<String, dynamic> json) =>
      _$WsAuthRequestFromJson(json);

  Map<String, dynamic> toJson() => _$WsAuthRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
