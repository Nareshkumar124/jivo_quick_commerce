// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unread_count.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$UnreadCountCWProxy {
  UnreadCount unread(int unread);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UnreadCount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UnreadCount(...).copyWith(id: 12, name: "My name")
  /// ````
  UnreadCount call({int unread});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfUnreadCount.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfUnreadCount.copyWith.fieldName(...)`
class _$UnreadCountCWProxyImpl implements _$UnreadCountCWProxy {
  const _$UnreadCountCWProxyImpl(this._value);

  final UnreadCount _value;

  @override
  UnreadCount unread(int unread) => this(unread: unread);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `UnreadCount(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// UnreadCount(...).copyWith(id: 12, name: "My name")
  /// ````
  UnreadCount call({Object? unread = const $CopyWithPlaceholder()}) {
    return UnreadCount(
      unread: unread == const $CopyWithPlaceholder()
          ? _value.unread
          // ignore: cast_nullable_to_non_nullable
          : unread as int,
    );
  }
}

extension $UnreadCountCopyWith on UnreadCount {
  /// Returns a callable class that can be used as follows: `instanceOfUnreadCount.copyWith(...)` or like so:`instanceOfUnreadCount.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$UnreadCountCWProxy get copyWith => _$UnreadCountCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UnreadCount _$UnreadCountFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UnreadCount', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['unread']);
      final val = UnreadCount(
        unread: $checkedConvert('unread', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$UnreadCountToJson(UnreadCount instance) =>
    <String, dynamic>{'unread': instance.unread};
