// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_payout_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedPayoutListCWProxy {
  PaginatedPayoutList count(int count);

  PaginatedPayoutList next(String? next);

  PaginatedPayoutList previous(String? previous);

  PaginatedPayoutList results(List<Payout> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedPayoutList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedPayoutList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedPayoutList call({
    int count,
    String? next,
    String? previous,
    List<Payout> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedPayoutList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedPayoutList.copyWith.fieldName(...)`
class _$PaginatedPayoutListCWProxyImpl implements _$PaginatedPayoutListCWProxy {
  const _$PaginatedPayoutListCWProxyImpl(this._value);

  final PaginatedPayoutList _value;

  @override
  PaginatedPayoutList count(int count) => this(count: count);

  @override
  PaginatedPayoutList next(String? next) => this(next: next);

  @override
  PaginatedPayoutList previous(String? previous) => this(previous: previous);

  @override
  PaginatedPayoutList results(List<Payout> results) => this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedPayoutList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedPayoutList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedPayoutList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedPayoutList(
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
          : results as List<Payout>,
    );
  }
}

extension $PaginatedPayoutListCopyWith on PaginatedPayoutList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedPayoutList.copyWith(...)` or like so:`instanceOfPaginatedPayoutList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedPayoutListCWProxy get copyWith =>
      _$PaginatedPayoutListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedPayoutList _$PaginatedPayoutListFromJson(Map<String, dynamic> json) =>
    $checkedCreate('PaginatedPayoutList', json, ($checkedConvert) {
      $checkKeys(
        json,
        requiredKeys: const ['count', 'next', 'previous', 'results'],
      );
      final val = PaginatedPayoutList(
        count: $checkedConvert('count', (v) => (v as num).toInt()),
        next: $checkedConvert('next', (v) => v as String?),
        previous: $checkedConvert('previous', (v) => v as String?),
        results: $checkedConvert(
          'results',
          (v) => (v as List<dynamic>)
              .map((e) => Payout.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$PaginatedPayoutListToJson(
  PaginatedPayoutList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
