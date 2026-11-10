// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/ws_rider_status_data.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_rider_status_message.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsRiderStatusMessage {
  /// Returns a new [WsRiderStatusMessage] instance.
  WsRiderStatusMessage({
    required this.type,

    required this.data,

    required this.sentAt,
  });

  /// Always \"rider.status\".
  @JsonKey(name: r'type', required: true, includeIfNull: false)
  final String type;

  @JsonKey(name: r'data', required: true, includeIfNull: false)
  final WsRiderStatusData data;

  /// When the server sent it (UTC).
  @JsonKey(name: r'sent_at', required: true, includeIfNull: false)
  final DateTime sentAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsRiderStatusMessage &&
          other.type == type &&
          other.data == data &&
          other.sentAt == sentAt;

  @override
  int get hashCode => type.hashCode + data.hashCode + sentAt.hashCode;

  factory WsRiderStatusMessage.fromJson(Map<String, dynamic> json) =>
      _$WsRiderStatusMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WsRiderStatusMessageToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
