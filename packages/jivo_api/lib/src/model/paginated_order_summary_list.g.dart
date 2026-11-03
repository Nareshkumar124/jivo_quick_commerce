// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_order_summary_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedOrderSummaryListCWProxy {
  PaginatedOrderSummaryList count(int count);

  PaginatedOrderSummaryList next(String? next);

  PaginatedOrderSummaryList previous(String? previous);

  PaginatedOrderSummaryList results(List<OrderSummary> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedOrderSummaryList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedOrderSummaryList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedOrderSummaryList call({
    int count,
    String? next,
    String? previous,
    List<OrderSummary> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedOrderSummaryList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedOrderSummaryList.copyWith.fieldName(...)`
class _$PaginatedOrderSummaryListCWProxyImpl
    implements _$PaginatedOrderSummaryListCWProxy {
  const _$PaginatedOrderSummaryListCWProxyImpl(this._value);

  final PaginatedOrderSummaryList _value;

  @override
  PaginatedOrderSummaryList count(int count) => this(count: count);

  @override
  PaginatedOrderSummaryList next(String? next) => this(next: next);

  @override
  PaginatedOrderSummaryList previous(String? previous) =>
      this(previous: previous);

  @override
  PaginatedOrderSummaryList results(List<OrderSummary> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedOrderSummaryList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedOrderSummaryList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedOrderSummaryList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedOrderSummaryList(
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
          : results as List<OrderSummary>,
    );
  }
}

extension $PaginatedOrderSummaryListCopyWith on PaginatedOrderSummaryList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedOrderSummaryList.copyWith(...)` or like so:`instanceOfPaginatedOrderSummaryList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedOrderSummaryListCWProxy get copyWith =>
      _$PaginatedOrderSummaryListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedOrderSummaryList _$PaginatedOrderSummaryListFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedOrderSummaryList', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedOrderSummaryList(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedOrderSummaryListToJson(
  PaginatedOrderSummaryList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
