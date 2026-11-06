// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/inbox_notification_category_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'inbox_notification.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class InboxNotification {
  /// Returns a new [InboxNotification] instance.
  InboxNotification({
    required this.id,

    required this.title,

    required this.body,

    required this.category,

    required this.link,

    required this.read,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(
    name: r'category',
    required: true,
    includeIfNull: false,
    unknownEnumValue: InboxNotificationCategoryEnum.unknownDefaultOpenApi,
  )
  final InboxNotificationCategoryEnum category;

  /// Where a tap goes: a `jivo://` deep link (`jivo://orders/1203`, `jivo://product/<slug>`, ...), or null.
  @JsonKey(name: r'link', required: true, includeIfNull: true)
  final String? link;

  /// True once marked read.
  @JsonKey(name: r'read', required: true, includeIfNull: false)
  final bool read;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InboxNotification &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          other.category == category &&
          other.link == link &&
          other.read == read &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      id.hashCode +
      title.hashCode +
      body.hashCode +
      category.hashCode +
      (link == null ? 0 : link.hashCode) +
      read.hashCode +
      createdAt.hashCode;

  factory InboxNotification.fromJson(Map<String, dynamic> json) =>
      _$InboxNotificationFromJson(json);

  Map<String, dynamic> toJson() => _$InboxNotificationToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
