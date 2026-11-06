// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_auth_ok_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsAuthOkData {
  /// Returns a new [WsAuthOkData] instance.
  WsAuthOkData({required this.userId, required this.expiresAt});

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final int userId;

  @JsonKey(name: r'expires_at', required: true, includeIfNull: true)
  final DateTime? expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsAuthOkData &&
          other.userId == userId &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode =>
      userId.hashCode + (expiresAt == null ? 0 : expiresAt.hashCode);

  factory WsAuthOkData.fromJson(Map<String, dynamic> json) =>
      _$WsAuthOkDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsAuthOkDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
