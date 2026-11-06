// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_inbox_notification_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedInboxNotificationListCWProxy {
  PaginatedInboxNotificationList count(int count);

  PaginatedInboxNotificationList next(String? next);

  PaginatedInboxNotificationList previous(String? previous);

  PaginatedInboxNotificationList results(List<InboxNotification> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedInboxNotificationList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedInboxNotificationList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedInboxNotificationList call({
    int count,
    String? next,
    String? previous,
    List<InboxNotification> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedInboxNotificationList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedInboxNotificationList.copyWith.fieldName(...)`
class _$PaginatedInboxNotificationListCWProxyImpl
    implements _$PaginatedInboxNotificationListCWProxy {
  const _$PaginatedInboxNotificationListCWProxyImpl(this._value);

  final PaginatedInboxNotificationList _value;

  @override
  PaginatedInboxNotificationList count(int count) => this(count: count);

  @override
  PaginatedInboxNotificationList next(String? next) => this(next: next);

  @override
  PaginatedInboxNotificationList previous(String? previous) =>
      this(previous: previous);

  @override
  PaginatedInboxNotificationList results(List<InboxNotification> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedInboxNotificationList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedInboxNotificationList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedInboxNotificationList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedInboxNotificationList(
      count: count == const $CopyWithPlaceholder()
          ? _value.count
          // ignore: cast_nullable_to_non_nullable
          : count as int,
      next: next == const $CopyWithPlaceholder()
          ? _value.next
          // ignore: cast_nullable_to_non_nullable
          : next as String?,
      previous: previous == const $CopyWithPlaceholder()
          ? _value.previous
          // ignore: cast_nullable_to_non_nullable
          : previous as String?,
      results: results == const $CopyWithPlaceholder()
          ? _value.results
          // ignore: cast_nullable_to_non_nullable
          : results as List<InboxNotification>,
    );
  }
}

extension $PaginatedInboxNotificationListCopyWith
    on PaginatedInboxNotificationList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedInboxNotificationList.copyWith(...)` or like so:`instanceOfPaginatedInboxNotificationList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedInboxNotificationListCWProxy get copyWith =>
      _$PaginatedInboxNotificationListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedInboxNotificationList _$PaginatedInboxNotificationListFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedInboxNotificationList', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedInboxNotificationList(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => InboxNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedInboxNotificationListToJson(
  PaginatedInboxNotificationList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
