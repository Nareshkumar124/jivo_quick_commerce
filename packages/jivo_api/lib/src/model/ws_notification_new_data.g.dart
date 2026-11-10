// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ws_notification_new_data.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WsNotificationNewDataCWProxy {
  WsNotificationNewData id(int id);

  WsNotificationNewData title(String title);

  WsNotificationNewData body(String body);

  WsNotificationNewData category(String category);

  WsNotificationNewData link(String? link);

  WsNotificationNewData read(bool read);

  WsNotificationNewData createdAt(DateTime createdAt);

  WsNotificationNewData unreadCount(int unreadCount);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsNotificationNewData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsNotificationNewData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsNotificationNewData call({
    int id,
    String title,
    String body,
    String category,
    String? link,
    bool read,
    DateTime createdAt,
    int unreadCount,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWsNotificationNewData.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWsNotificationNewData.copyWith.fieldName(...)`
class _$WsNotificationNewDataCWProxyImpl
    implements _$WsNotificationNewDataCWProxy {
  const _$WsNotificationNewDataCWProxyImpl(this._value);

  final WsNotificationNewData _value;

  @override
  WsNotificationNewData id(int id) => this(id: id);

  @override
  WsNotificationNewData title(String title) => this(title: title);

  @override
  WsNotificationNewData body(String body) => this(body: body);

  @override
  WsNotificationNewData category(String category) => this(category: category);

  @override
  WsNotificationNewData link(String? link) => this(link: link);

  @override
  WsNotificationNewData read(bool read) => this(read: read);

  @override
  WsNotificationNewData createdAt(DateTime createdAt) =>
      this(createdAt: createdAt);

  @override
  WsNotificationNewData unreadCount(int unreadCount) =>
      this(unreadCount: unreadCount);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WsNotificationNewData(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WsNotificationNewData(...).copyWith(id: 12, name: "My name")
  /// ````
  WsNotificationNewData call({
    Object? id = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? link = const $CopyWithPlaceholder(),
    Object? read = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
    Object? unreadCount = const $CopyWithPlaceholder(),
  }) {
    return WsNotificationNewData(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as int,
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String,
      category: category == const $CopyWithPlaceholder()
          ? _value.category
          // ignore: cast_nullable_to_non_nullable
          : category as String,
      link: link == const $CopyWithPlaceholder()
          ? _value.link
          // ignore: cast_nullable_to_non_nullable
          : link as String?,
      read: read == const $CopyWithPlaceholder()
          ? _value.read
          // ignore: cast_nullable_to_non_nullable
          : read as bool,
      createdAt: createdAt == const $CopyWithPlaceholder()
          ? _value.createdAt
          // ignore: cast_nullable_to_non_nullable
          : createdAt as DateTime,
      unreadCount: unreadCount == const $CopyWithPlaceholder()
          ? _value.unreadCount
          // ignore: cast_nullable_to_non_nullable
          : unreadCount as int,
    );
  }
}

extension $WsNotificationNewDataCopyWith on WsNotificationNewData {
  /// Returns a callable class that can be used as follows: `instanceOfWsNotificationNewData.copyWith(...)` or like so:`instanceOfWsNotificationNewData.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WsNotificationNewDataCWProxy get copyWith =>
      _$WsNotificationNewDataCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WsNotificationNewData _$WsNotificationNewDataFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WsNotificationNewData',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      requiredKeys: const [
        'id',
        'title',
        'body',
        'category',
        'link',
        'read',
        'created_at',
        'unread_count',
      ],
    );
    final val = WsNotificationNewData(
      id: $checkedConvert('id', (v) => (v as num).toInt()),
      title: $checkedConvert('title', (v) => v as String),
      body: $checkedConvert('body', (v) => v as String),
      category: $checkedConvert('category', (v) => v as String),
      link: $checkedConvert('link', (v) => v as String?),
      read: $checkedConvert('read', (v) => v as bool),
      createdAt: $checkedConvert(
        'created_at',
        (v) => DateTime.parse(v as String),
      ),
      unreadCount: $checkedConvert('unread_count', (v) => (v as num).toInt()),
    );
    return val;
  },
  fieldKeyMap: const {'createdAt': 'created_at', 'unreadCount': 'unread_count'},
);

Map<String, dynamic> _$WsNotificationNewDataToJson(
  WsNotificationNewData instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'body': instance.body,
  'category': instance.category,
  'link': instance.link,
  'read': instance.read,
  'created_at': instance.createdAt.toIso8601String(),
  'unread_count': instance.unreadCount,
};
