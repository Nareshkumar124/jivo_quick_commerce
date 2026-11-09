// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'read_all_result.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReadAllResultCWProxy {
  ReadAllResult updated(int updated);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllResult(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllResult call({int updated});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReadAllResult.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReadAllResult.copyWith.fieldName(...)`
class _$ReadAllResultCWProxyImpl implements _$ReadAllResultCWProxy {
  const _$ReadAllResultCWProxyImpl(this._value);

  final ReadAllResult _value;

  @override
  ReadAllResult updated(int updated) => this(updated: updated);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReadAllResult(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReadAllResult(...).copyWith(id: 12, name: "My name")
  /// ````
  ReadAllResult call({Object? updated = const $CopyWithPlaceholder()}) {
    return ReadAllResult(
      updated: updated == const $CopyWithPlaceholder()
          ? _value.updated
          // ignore: cast_nullable_to_non_nullable
          : updated as int,
    );
  }
}

extension $ReadAllResultCopyWith on ReadAllResult {
  /// Returns a callable class that can be used as follows: `instanceOfReadAllResult.copyWith(...)` or like so:`instanceOfReadAllResult.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReadAllResultCWProxy get copyWith => _$ReadAllResultCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReadAllResult _$ReadAllResultFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReadAllResult', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['updated']);
      final val = ReadAllResult(
        updated: $checkedConvert('updated', (v) => (v as num).toInt()),
      );
      return val;
    });

Map<String, dynamic> _$ReadAllResultToJson(ReadAllResult instance) =>
    <String, dynamic>{'updated': instance.updated};
