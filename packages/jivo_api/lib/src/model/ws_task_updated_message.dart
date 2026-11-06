// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ws_task_updated_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_task_updated_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsTaskUpdatedMessage {
  /// Returns a new [WsTaskUpdatedMessage] instance.
  WsTaskUpdatedMessage({
    required this.type,

    required this.data,

    required this.sentAt,
  });

  /// Always \"task.updated\".
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WsTaskUpdatedData data;

  /// When the server sent it (UTC).
  @JsonKey(name: r'sent_at', required: true, includeIfNull: false)
  final DateTime sentAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsTaskUpdatedMessage &&
          other.type == type &&
          other.data == data &&
          other.sentAt == sentAt;

  @override
  int get hashCode => type.hashCode + data.hashCode + sentAt.hashCode;

  factory WsTaskUpdatedMessage.fromJson(Map<String, dynamic> json) =>
      _$WsTaskUpdatedMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WsTaskUpdatedMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
