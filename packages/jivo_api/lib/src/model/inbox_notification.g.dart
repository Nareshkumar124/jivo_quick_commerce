// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_notification.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$InboxNotificationCWProxy {
  InboxNotification id(int id);

  InboxNotification title(String title);

  InboxNotification body(String body);

  InboxNotification category(InboxNotificationCategoryEnum category);

  InboxNotification link(String? link);

  InboxNotification read(bool read);

  InboxNotification createdAt(DateTime createdAt);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InboxNotification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InboxNotification(...).copyWith(id: 12, name: "My name")
  /// ````
  InboxNotification call({
    int id,
    String title,
    String body,
    InboxNotificationCategoryEnum category,
    String? link,
    bool read,
    DateTime createdAt,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfInboxNotification.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfInboxNotification.copyWith.fieldName(...)`
class _$InboxNotificationCWProxyImpl implements _$InboxNotificationCWProxy {
  const _$InboxNotificationCWProxyImpl(this._value);

  final InboxNotification _value;

  @override
  InboxNotification id(int id) => this(id: id);

  @override
  InboxNotification title(String title) => this(title: title);

  @override
  InboxNotification body(String body) => this(body: body);

  @override
  InboxNotification category(InboxNotificationCategoryEnum category) =>
      this(category: category);

  @override
  InboxNotification link(String? link) => this(link: link);

  @override
  InboxNotification read(bool read) => this(read: read);

  @override
  InboxNotification createdAt(DateTime createdAt) => this(createdAt: createdAt);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `InboxNotification(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// InboxNotification(...).copyWith(id: 12, name: "My name")
  /// ````
  InboxNotification call({
    Object? id = const $CopyWithPlaceholder(),
    Object? title = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? category = const $CopyWithPlaceholder(),
    Object? link = const $CopyWithPlaceholder(),
    Object? read = const $CopyWithPlaceholder(),
    Object? createdAt = const $CopyWithPlaceholder(),
  }) {
    return InboxNotification(
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
          : category as InboxNotificationCategoryEnum,
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
    );
  }
}

extension $InboxNotificationCopyWith on InboxNotification {
  /// Returns a callable class that can be used as follows: `instanceOfInboxNotification.copyWith(...)` or like so:`instanceOfInboxNotification.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$InboxNotificationCWProxy get copyWith =>
      _$InboxNotificationCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InboxNotification _$InboxNotificationFromJson(Map<String, dynamic> json) =>
    $checkedCreate('InboxNotification', json, ($checkedConvert) {
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
        ],
      );
      final val = InboxNotification(
        id: $checkedConvert('id', (v) => (v as num).toInt()),
        title: $checkedConvert('title', (v) => v as String),
        body: $checkedConvert('body', (v) => v as String),
        category: $checkedConvert(
          'category',
          (v) => $enumDecode(
            _$InboxNotificationCategoryEnumEnumMap,
            v,
            unknownValue: InboxNotificationCategoryEnum.unknownDefaultOpenApi,
          ),
        ),
        link: $checkedConvert('link', (v) => v as String?),
        read: $checkedConvert('read', (v) => v as bool),
        createdAt: $checkedConvert(
          'created_at',
          (v) => DateTime.parse(v as String),
        ),
      );
      return val;
    }, fieldKeyMap: const {'createdAt': 'created_at'});

Map<String, dynamic> _$InboxNotificationToJson(InboxNotification instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'body': instance.body,
      'category': _$InboxNotificationCategoryEnumEnumMap[instance.category]!,
      'link': instance.link,
      'read': instance.read,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$InboxNotificationCategoryEnumEnumMap = {
  InboxNotificationCategoryEnum.order: 'order',
  InboxNotificationCategoryEnum.promo: 'promo',
  InboxNotificationCategoryEnum.system: 'system',
  InboxNotificationCategoryEnum.support: 'support',
  InboxNotificationCategoryEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
