// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ws_order_created_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_created_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderCreatedMessage {
  /// Returns a new [WsOrderCreatedMessage] instance.
  WsOrderCreatedMessage({
    required this.type,

    required this.data,

    required this.sentAt,
  });

  /// Always \"order.created\".
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WsOrderCreatedData data;

  /// When the server sent it (UTC).
  @JsonKey(name: r'sent_at', required: true, includeIfNull: false)
  final DateTime sentAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderCreatedMessage &&
          other.type == type &&
          other.data == data &&
          other.sentAt == sentAt;

  @override
  int get hashCode => type.hashCode + data.hashCode + sentAt.hashCode;

  factory WsOrderCreatedMessage.fromJson(Map<String, dynamic> json) =>
      _$WsOrderCreatedMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderCreatedMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
