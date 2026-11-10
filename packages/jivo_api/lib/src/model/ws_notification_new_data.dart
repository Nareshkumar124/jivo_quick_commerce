// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'ws_notification_new_data.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WsNotificationNewData {
  /// Returns a new [WsNotificationNewData] instance.
  WsNotificationNewData({
    required this.id,

    required this.title,

    required this.body,

    required this.category,

    required this.link,

    required this.read,

    required this.createdAt,

    required this.unreadCount,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'category', required: true, includeIfNull: false)
  final String category;

  @JsonKey(name: r'link', required: true, includeIfNull: true)
  final String? link;

  @JsonKey(name: r'read', required: true, includeIfNull: false)
  final bool read;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  /// Unread inbox entries for this app now.
  @JsonKey(name: r'unread_count', required: true, includeIfNull: false)
  final int unreadCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WsNotificationNewData &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          other.category == category &&
          other.link == link &&
          other.read == read &&
          other.createdAt == createdAt &&
          other.unreadCount == unreadCount;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      body.hashCode +
      category.hashCode +
      (link == null ? 0 : link.hashCode) +
      read.hashCode +
      createdAt.hashCode +
      unreadCount.hashCode;

  factory WsNotificationNewData.fromJson(Map<String, dynamic> json) =>
      _$WsNotificationNewDataFromJson(json);

  Map<String, dynamic> toJson() => _$WsNotificationNewDataToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
