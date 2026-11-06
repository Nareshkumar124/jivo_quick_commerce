// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_pong_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsPongMessage {
  /// Returns a new [WsPongMessage] instance.
  WsPongMessage({required this.type, required this.sentAt});

  /// Always \"pong\".
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  /// When the server sent it (UTC).
  @JsonKey(name: r'sent_at', required: true, includeIfNull: false)
  final DateTime sentAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsPongMessage && other.type == type && other.sentAt == sentAt;

  @override
  int get hashCode => type.hashCode + sentAt.hashCode;

  factory WsPongMessage.fromJson(Map<String, dynamic> json) =>
      _$WsPongMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WsPongMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
