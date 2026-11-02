// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'paginated_address_list.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$PaginatedAddressListCWProxy {
  PaginatedAddressList count(int count);

  PaginatedAddressList next(String? next);

  PaginatedAddressList previous(String? previous);

  PaginatedAddressList results(List<Address> results);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedAddressList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedAddressList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedAddressList call({
    int count,
    String? next,
    String? previous,
    List<Address> results,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfPaginatedAddressList.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfPaginatedAddressList.copyWith.fieldName(...)`
class _$PaginatedAddressListCWProxyImpl
    implements _$PaginatedAddressListCWProxy {
  const _$PaginatedAddressListCWProxyImpl(this._value);

  final PaginatedAddressList _value;

  @override
  PaginatedAddressList count(int count) => this(count: count);

  @override
  PaginatedAddressList next(String? next) => this(next: next);

  @override
  PaginatedAddressList previous(String? previous) => this(previous: previous);

  @override
  PaginatedAddressList results(List<Address> results) => this(results: results);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `PaginatedAddressList(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// PaginatedAddressList(...).copyWith(id: 12, name: "My name")
  /// ````
  PaginatedAddressList call({
    Object? count = const $CopyWithPlaceholder(),
    Object? next = const $CopyWithPlaceholder(),
    Object? previous = const $CopyWithPlaceholder(),
    Object? results = const $CopyWithPlaceholder(),
  }) {
    return PaginatedAddressList(
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
          : results as List<Address>,
    );
  }
}

extension $PaginatedAddressListCopyWith on PaginatedAddressList {
  /// Returns a callable class that can be used as follows: `instanceOfPaginatedAddressList.copyWith(...)` or like so:`instanceOfPaginatedAddressList.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$PaginatedAddressListCWProxy get copyWith =>
      _$PaginatedAddressListCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaginatedAddressList _$PaginatedAddressListFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('PaginatedAddressList', json, ($checkedConvert) {
  $checkKeys(
    json,
    requiredKeys: const ['count', 'next', 'previous', 'results'],
  );
  final val = PaginatedAddressList(
    count: $checkedConvert('count', (v) => (v as num).toInt()),
    next: $checkedConvert('next', (v) => v as String?),
    previous: $checkedConvert('previous', (v) => v as String?),
    results: $checkedConvert(
      'results',
      (v) => (v as List<dynamic>)
          .map((e) => Address.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );
  return val;
});

Map<String, dynamic> _$PaginatedAddressListToJson(
  PaginatedAddressList instance,
) => <String, dynamic>{
  'count': instance.count,
  'next': instance.next,
  'previous': instance.previous,
  'results': instance.results.map((e) => e.toJson()).toList(),
};
