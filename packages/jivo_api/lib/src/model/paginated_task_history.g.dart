// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_task_history.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedTaskHistoryCWProxy {
  PaginatedTaskHistory count(int count);

  PaginatedTaskHistory next(String? next);

  PaginatedTaskHistory previous(String? previous);

  PaginatedTaskHistory results(List<TaskHistoryItem> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedTaskHistory(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedTaskHistory(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedTaskHistory call({
    int count,
    String? next,
    String? previous,
    List<TaskHistoryItem> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedTaskHistory.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedTaskHistory.copyWith.fieldName(...)`
class _$PaginatedTaskHistoryCWProxyImpl
    implements _$PaginatedTaskHistoryCWProxy {
  const _$PaginatedTaskHistoryCWProxyImpl(this._value);

  final PaginatedTaskHistory _value;

  @override
  PaginatedTaskHistory count(int count) => this(count: count);

  @override
  PaginatedTaskHistory next(String? next) => this(next: next);

  @override
  PaginatedTaskHistory previous(String? previous) => this(previous: previous);

  @override
  PaginatedTaskHistory results(List<TaskHistoryItem> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedTaskHistory(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedTaskHistory(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedTaskHistory call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedTaskHistory(
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
          : results as List<TaskHistoryItem>,
    );
  }
}

extension $PaginatedTaskHistoryCopyWith on PaginatedTaskHistory {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedTaskHistory.copyWith(...)` or like so:`instanceOfPaginatedTaskHistory.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedTaskHistoryCWProxy get copyWith =>
      _$PaginatedTaskHistoryCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedTaskHistory _$PaginatedTaskHistoryFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedTaskHistory', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedTaskHistory(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => TaskHistoryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedTaskHistoryToJson(
  PaginatedTaskHistory instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
