// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_ticket_summary_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedTicketSummaryListCWProxy {
  PaginatedTicketSummaryList count(int count);

  PaginatedTicketSummaryList next(String? next);

  PaginatedTicketSummaryList previous(String? previous);

  PaginatedTicketSummaryList results(List<TicketSummary> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedTicketSummaryList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedTicketSummaryList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedTicketSummaryList call({
    int count,
    String? next,
    String? previous,
    List<TicketSummary> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedTicketSummaryList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedTicketSummaryList.copyWith.fieldName(...)`
class _$PaginatedTicketSummaryListCWProxyImpl
    implements _$PaginatedTicketSummaryListCWProxy {
  const _$PaginatedTicketSummaryListCWProxyImpl(this._value);

  final PaginatedTicketSummaryList _value;

  @override
  PaginatedTicketSummaryList count(int count) => this(count: count);

  @override
  PaginatedTicketSummaryList next(String? next) => this(next: next);

  @override
  PaginatedTicketSummaryList previous(String? previous) =>
      this(previous: previous);

  @override
  PaginatedTicketSummaryList results(List<TicketSummary> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedTicketSummaryList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedTicketSummaryList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedTicketSummaryList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedTicketSummaryList(
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
          : results as List<TicketSummary>,
    );
  }
}

extension $PaginatedTicketSummaryListCopyWith on PaginatedTicketSummaryList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedTicketSummaryList.copyWith(...)` or like so:`instanceOfPaginatedTicketSummaryList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedTicketSummaryListCWProxy get copyWith =>
      _$PaginatedTicketSummaryListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedTicketSummaryList _$PaginatedTicketSummaryListFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedTicketSummaryList', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedTicketSummaryList(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => TicketSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedTicketSummaryListToJson(
  PaginatedTicketSummaryList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
