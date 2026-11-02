// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_product_card_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedProductCardListCWProxy {
  PaginatedProductCardList count(int count);

  PaginatedProductCardList next(String? next);

  PaginatedProductCardList previous(String? previous);

  PaginatedProductCardList results(List<ProductCard> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedProductCardList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedProductCardList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedProductCardList call({
    int count,
    String? next,
    String? previous,
    List<ProductCard> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedProductCardList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedProductCardList.copyWith.fieldName(...)`
class _$PaginatedProductCardListCWProxyImpl
    implements _$PaginatedProductCardListCWProxy {
  const _$PaginatedProductCardListCWProxyImpl(this._value);

  final PaginatedProductCardList _value;

  @override
  PaginatedProductCardList count(int count) => this(count: count);

  @override
  PaginatedProductCardList next(String? next) => this(next: next);

  @override
  PaginatedProductCardList previous(String? previous) =>
      this(previous: previous);

  @override
  PaginatedProductCardList results(List<ProductCard> results) =>
      this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedProductCardList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedProductCardList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedProductCardList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedProductCardList(
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
          : results as List<ProductCard>,
    );
  }
}

extension $PaginatedProductCardListCopyWith on PaginatedProductCardList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedProductCardList.copyWith(...)` or like so:`instanceOfPaginatedProductCardList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedProductCardListCWProxy get copyWith =>
      _$PaginatedProductCardListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedProductCardList _$PaginatedProductCardListFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedProductCardList', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedProductCardList(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => ProductCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedProductCardListToJson(
  PaginatedProductCardList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
