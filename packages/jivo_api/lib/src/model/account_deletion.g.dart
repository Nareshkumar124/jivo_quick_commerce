// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_deletion.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AccountDeletionCWProxy {
  AccountDeletion deletedAt(DateTime deletedAt);

  AccountDeletion anonymiseAfter(DateTime anonymiseAfter);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AccountDeletion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AccountDeletion(...).copyWith(id: 12, name: "My name")
  /// ````
  AccountDeletion call({DateTime deletedAt, DateTime anonymiseAfter});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAccountDeletion.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAccountDeletion.copyWith.fieldName(...)`
class _$AccountDeletionCWProxyImpl implements _$AccountDeletionCWProxy {
  const _$AccountDeletionCWProxyImpl(this._value);

  final AccountDeletion _value;

  @override
  AccountDeletion deletedAt(DateTime deletedAt) => this(deletedAt: deletedAt);

  @override
  AccountDeletion anonymiseAfter(DateTime anonymiseAfter) =>
      this(anonymiseAfter: anonymiseAfter);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AccountDeletion(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AccountDeletion(...).copyWith(id: 12, name: "My name")
  /// ````
  AccountDeletion call({
    Object? deletedAt = const $CopyWithPlaceholder(),
    Object? anonymiseAfter = const $CopyWithPlaceholder(),
  }) {
    return AccountDeletion(
      deletedAt: deletedAt == const $CopyWithPlaceholder()
          ? _value.deletedAt
          // ignore: cast_nullable_to_non_nullable
          : deletedAt as DateTime,
      anonymiseAfter: anonymiseAfter == const $CopyWithPlaceholder()
          ? _value.anonymiseAfter
          // ignore: cast_nullable_to_non_nullable
          : anonymiseAfter as DateTime,
    );
  }
}

extension $AccountDeletionCopyWith on AccountDeletion {
  /// Returns a callable class that can be used as follows: `instanceOfAccountDeletion.copyWith(...)` or like so:`instanceOfAccountDeletion.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AccountDeletionCWProxy get copyWith => _$AccountDeletionCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountDeletion _$AccountDeletionFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'AccountDeletion',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['deleted_at', 'anonymise_after']);
        final val = AccountDeletion(
          deletedAt: $checkedConvert(
            'deleted_at',
            (v) => DateTime.parse(v as String),
          ),
          anonymiseAfter: $checkedConvert(
            'anonymise_after',
            (v) => DateTime.parse(v as String),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'deletedAt': 'deleted_at',
        'anonymiseAfter': 'anonymise_after',
      },
    );

Map<String, dynamic> _$AccountDeletionToJson(AccountDeletion instance) =>
    <String, dynamic>{
      'deleted_at': instance.deletedAt.toIso8601String(),
      'anonymise_after': instance.anonymiseAfter.toIso8601String(),
    };
