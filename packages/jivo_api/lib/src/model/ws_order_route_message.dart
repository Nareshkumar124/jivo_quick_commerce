// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ws_order_route_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_order_route_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsOrderRouteMessage {
  /// Returns a new [WsOrderRouteMessage] instance.
  WsOrderRouteMessage({
    required this.type,

    required this.data,

    required this.sentAt,
  });

  /// Always \"order.route\".
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WsOrderRouteData data;

  /// When the server sent it (UTC).
  @JsonKey(name: r'sent_at', required: true, includeIfNull: false)
  final DateTime sentAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsOrderRouteMessage &&
          other.type == type &&
          other.data == data &&
          other.sentAt == sentAt;

  @override
  int get hashCode => type.hashCode + data.hashCode + sentAt.hashCode;

  factory WsOrderRouteMessage.fromJson(Map<String, dynamic> json) =>
      _$WsOrderRouteMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WsOrderRouteMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
